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

import Compound
import SwiftUI

/// The screen shown to unlock the App Lock settings or to create a new PIN and enable the feature.
struct AppLockSetupPINScreen: View {
    @ObservedObject var context: AppLockSetupPINScreenViewModel.Context
    
    @FocusState private var textFieldFocus
    
    var body: some View {
        ScrollView {
            VStack(spacing: 48) {
                header
                
                PINTextField(pinCode: $context.pinCode,
                             isSecure: context.viewState.mode == .unlock)
                    .focused($textFieldFocus)
                    .onChange(of: context.pinCode) { newValue in
                        guard newValue.count == 4 else { return }
                        context.send(viewAction: .submitPINCode)
                    }
            }
            .padding(.horizontal, 16)
            .padding(.top, UIConstants.iconTopPaddingToNavigationBar)
            .frame(maxWidth: .infinity)
        }
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        .toolbar { toolbar }
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .interactiveDismissDisabled(context.viewState.isMandatory)
        .alert(item: $context.alertInfo)
        .onAppear { textFieldFocus = true }
    }
    
    var header: some View {
        VStack(spacing: 8) {
            HeroImage(image: Image(systemSymbol: .lock))
                .symbolVariant(.fill)
                .padding(.bottom, 8)
            
            Text(context.viewState.title)
                .font(.compound.headingMDBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textPrimary)
            
            if let subtitle = context.viewState.subtitle {
                Text(subtitle)
                    .font(.compound.bodyMD)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.compound.textSecondary)
            }
        }
    }
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        if !context.viewState.isMandatory {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.actionCancel) {
                    context.send(viewAction: .cancel)
                }
            }
        }
    }
}

// MARK: - Previews

struct AppLockSetupPINScreen_Previews: PreviewProvider, TestablePreview {
    static let service = AppLockService(keychainController: KeychainControllerMock(),
                                        appSettings: ServiceLocator.shared.settings)
    static let createViewModel = AppLockSetupPINScreenViewModel(initialMode: .create,
                                                                isMandatory: false,
                                                                appLockService: service)
    static let confirmViewModel = AppLockSetupPINScreenViewModel(initialMode: .confirm,
                                                                 isMandatory: false,
                                                                 appLockService: service)
    static let unlockViewModel = AppLockSetupPINScreenViewModel(initialMode: .unlock,
                                                                isMandatory: false,
                                                                appLockService: service)
    
    static var previews: some View {
        NavigationStack {
            AppLockSetupPINScreen(context: createViewModel.context)
        }
        .previewDisplayName("Create")
        
        NavigationStack {
            AppLockSetupPINScreen(context: confirmViewModel.context)
        }
        .previewDisplayName("Confirm")
        
        NavigationStack {
            AppLockSetupPINScreen(context: unlockViewModel.context)
        }
        .previewDisplayName("Unlock")
    }
}
