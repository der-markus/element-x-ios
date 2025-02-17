//
// Copyright 2023 New Vector Ltd
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

import UIKit

extension ApplicationMock {
    static var `default`: ApplicationProtocol {
        ApplicationMock(withState: .active,
                        backgroundTimeRemaining: 10,
                        allowTasks: true)
    }

    static var mockBroken: ApplicationProtocol {
        ApplicationMock(withState: .inactive,
                        backgroundTimeRemaining: 0,
                        allowTasks: false)
    }

    static var mockAboutToSuspend: ApplicationProtocol {
        ApplicationMock(withState: .background,
                        backgroundTimeRemaining: 2,
                        allowTasks: false)
    }
    
    private static var bgTaskIdentifier = 0

    convenience init(withState applicationState: UIApplication.State,
                     backgroundTimeRemaining: TimeInterval,
                     allowTasks: Bool) {
        self.init()
        
        underlyingApplicationState = applicationState
        underlyingBackgroundTimeRemaining = backgroundTimeRemaining
        
        beginBackgroundTaskExpirationHandlerClosure = { [weak self] handler in
            guard let self else {
                return .invalid
            }
            
            guard allowTasks else {
                return .invalid
            }
            
            return beginBackgroundTask(withName: nil, expirationHandler: handler)
        }
        
        beginBackgroundTaskWithNameExpirationHandlerClosure = { _, handler in
            guard allowTasks else {
                return .invalid
            }
            Self.bgTaskIdentifier += 1

            let identifier = UIBackgroundTaskIdentifier(rawValue: Self.bgTaskIdentifier)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                handler?()
            }
            return identifier
        }
    }
}
