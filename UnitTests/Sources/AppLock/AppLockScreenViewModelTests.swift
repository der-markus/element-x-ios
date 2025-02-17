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

import XCTest

@testable import ElementX

@MainActor
class AppLockScreenViewModelTests: XCTestCase {
    var appSettings: AppSettings!
    var appLockService: AppLockService!
    var keychainController: KeychainControllerMock!
    var viewModel: AppLockScreenViewModelProtocol!
    
    var context: AppLockScreenViewModelType.Context { viewModel.context }
    
    override func setUp() {
        AppSettings.reset()
        appSettings = AppSettings()
        keychainController = KeychainControllerMock()
        appLockService = AppLockService(keychainController: keychainController, appSettings: appSettings)
        viewModel = AppLockScreenViewModel(appLockService: appLockService)
    }
    
    override func tearDown() {
        AppSettings.reset()
    }
    
    func testUnlock() async throws {
        // Given a valid PIN code.
        let pinCode = "2023"
        keychainController.pinCodeReturnValue = pinCode
        
        // When entering it on the lock screen.
        let deferred = deferFulfillment(viewModel.actions) { $0 == .appUnlocked }
        viewModel.context.pinCode = pinCode
        context.send(viewAction: .submitPINCode)
        let result = try await deferred.fulfill()
        
        // The app should become unlocked.
        XCTAssertEqual(result, .appUnlocked)
    }
    
    func testForgotPIN() {
        // Given a fresh launch of the app.
        XCTAssertNil(context.alertInfo, "No alert should be shown initially.")
        
        // When the user has forgotten their PIN.
        context.send(viewAction: .forgotPIN)
        
        // Then an alert should be shown before logging out.
        XCTAssertEqual(context.alertInfo?.id, .confirmResetPIN, "An alert should be shown before logging out.")
    }
    
    func testUnlockFailure() async throws {
        // Given an invalid PIN code.
        let pinCode = "2024"
        keychainController.pinCodeReturnValue = "2023"
        XCTAssertEqual(context.viewState.numberOfPINAttempts, 0, "The shouldn't be any attempts yet.")
        XCTAssertFalse(context.viewState.isSubtitleWarning, "No warning should be shown yet.")
        XCTAssertNil(context.alertInfo, "No alert should be shown yet.")
        
        // When entering it on the lock screen.
        viewModel.context.pinCode = pinCode
        context.send(viewAction: .submitPINCode)
        
        // Then a failed attempt should be shown.
        XCTAssertEqual(context.viewState.numberOfPINAttempts, 1, "A failed attempt should have been recorded.")
        XCTAssertTrue(context.viewState.isSubtitleWarning, "A warning should now be shown.")
        XCTAssertNil(context.alertInfo, "No alert should be shown yet.")
        
        // When entering twice more
        context.send(viewAction: .submitPINCode)
        context.send(viewAction: .submitPINCode)
        
        // Then an alert should be shown
        XCTAssertEqual(context.viewState.numberOfPINAttempts, 3, "All the attempts should have been recorded.")
        XCTAssertTrue(context.viewState.isSubtitleWarning, "The warning should still be shown.")
        XCTAssertEqual(context.alertInfo?.id, .forcedLogout, "An alert should now be shown.")
    }
    
    func testForceQuitRequiresLogout() {
        // Given an app with a PIN set where the user attempted to unlock 3 times.
        keychainController.pinCodeReturnValue = "2023"
        appSettings.appLockNumberOfPINAttempts = 2
        XCTAssertNil(context.alertInfo)
        viewModel.context.pinCode = "0000"
        context.send(viewAction: .submitPINCode)
        XCTAssertEqual(appSettings.appLockNumberOfPINAttempts, 3, "The app should have 3 failed attempts before the force quit.")
        XCTAssertEqual(context.alertInfo?.id, .forcedLogout, "The app should be showing the alert before the force quit.")
        
        // When force quitting the app and relaunching.
        viewModel = nil
        let freshViewModel = AppLockScreenViewModel(appLockService: appLockService)
        
        // Then the alert should remain in place
        XCTAssertEqual(freshViewModel.context.alertInfo?.id, .forcedLogout, "The new view model from the fresh launch should also show the alert")
    }
}
