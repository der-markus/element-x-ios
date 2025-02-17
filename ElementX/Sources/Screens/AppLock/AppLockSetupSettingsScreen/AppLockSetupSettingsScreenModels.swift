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

import Foundation
import LocalAuthentication

enum AppLockSetupSettingsScreenViewModelAction {
    /// The user would like to enter new PIN code.
    case changePINCode
    /// The user has disabled the App Lock feature.
    case appLockDisabled
}

struct AppLockSetupSettingsScreenViewState: BindableState {
    /// Whether App Lock is mandatory and can be disabled by the user.
    let isMandatory: Bool
    let biometryType: LABiometryType
    var bindings: AppLockSetupSettingsScreenViewStateBindings
    
    var supportsBiometry: Bool { biometryType != .none }
    var enableBiometryTitle: String { L10n.screenAppLockSetupBiometricUnlockAllowTitle(biometryType.localizedString) }
}

struct AppLockSetupSettingsScreenViewStateBindings {
    var enableBiometrics: Bool
    var alertInfo: AlertInfo<AppLockSetupSettingsScreenAlertType>?
}

enum AppLockSetupSettingsScreenAlertType {
    /// The alert shown to confirm the user would like to remove their PIN.
    case confirmRemovePINCode
}

enum AppLockSetupSettingsScreenViewAction {
    /// The user would like to enter a new PIN code.
    case changePINCode
    /// The user would like to disable the App Lock feature.
    case disable
    /// The user has toggled the biometrics setting.
    case enableBiometricsChanged
}
