//
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import SwiftUI
import WebKit

struct CallScreen: View {
    @ObservedObject var context: CallScreenViewModel.Context
    
    var body: some View {
        WebView(url: context.viewState.initialURL, viewModelContext: context)
            .navigationTitle("Call")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    let viewModelContext: CallScreenViewModel.Context
    
    func makeUIView(context: Context) -> WKWebView {
        viewModelContext.javaScriptEvaluator = context.coordinator.evaluateJavaScript(_:)
        return context.coordinator.webView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModelContext: viewModelContext)
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    @MainActor
    class Coordinator: NSObject, WKScriptMessageHandler, WKScriptMessageHandlerWithReply, WKUIDelegate, WKNavigationDelegate {
        private let viewModelContext: CallScreenViewModel.Context
        private var webViewURLObservation: NSKeyValueObservation?
        
        private(set) var webView: WKWebView!
        
        init(viewModelContext: CallScreenViewModel.Context) {
            self.viewModelContext = viewModelContext
            
            super.init()
            
            let configuration = WKWebViewConfiguration()
            
            let userContentController = WKUserContentController()
            userContentController.add(self, name: viewModelContext.viewState.messageHandler)
            userContentController.addScriptMessageHandler(self, contentWorld: .page, name: viewModelContext.viewState.messageWithReplyHandler)
            
            configuration.userContentController = userContentController
            configuration.allowsInlineMediaPlayback = true
            configuration.allowsPictureInPictureMediaPlayback = true
            
            if let script = viewModelContext.viewState.script {
                let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
                configuration.userContentController.addUserScript(userScript)
            }
            
            webView = WKWebView(frame: .zero, configuration: configuration)
            webView.uiDelegate = self
            webView.navigationDelegate = self
            
            // Allows Jitsi to run inside a WebView
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Safari/605.1.15"
        }
        
        func evaluateJavaScript(_ script: String) async throws -> Any {
            try await webView.evaluateJavaScript(script)
        }
        
        // MARK: - WKScriptMessageHandler
        
        nonisolated func userContentController(_ userContentController: WKUserContentController,
                                               didReceive message: WKScriptMessage) {
            Task { @MainActor in
                viewModelContext.send(viewAction: .receivedEvent(message.body))
            }
        }
        
        // MARK: - WKScriptMessageHandlerWithReply
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
            ("Well, hello, Bob!", nil)
        }
        
        // MARK: - WKUIDelegate
        
        func webView(_ webView: WKWebView, decideMediaCapturePermissionsFor origin: WKSecurityOrigin, initiatedBy frame: WKFrameInfo, type: WKMediaCaptureType) async -> WKPermissionDecision {
            .grant
        }
        
        // MARK: - WKNavigationDelegate
        
        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                viewModelContext.send(viewAction: .urlChanged(webView.url))
            }
        }
    }
}

// MARK: - Previews

struct CallScreen_Previews: PreviewProvider {
    static let viewModel = CallScreenViewModel()
    static var previews: some View {
        NavigationStack {
            CallScreen(context: viewModel.context)
        }
    }
}
