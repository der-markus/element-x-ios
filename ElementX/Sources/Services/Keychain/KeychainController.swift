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
import KeychainAccess
import MatrixRustSDK

enum KeychainControllerService: String {
    case sessions
    case tests

    var restorationTokenID: String {
        InfoPlistReader.main.baseBundleIdentifier + "." + rawValue
    }
    
    var mainID: String {
        InfoPlistReader.main.baseBundleIdentifier + ".keychain.\(rawValue)"
    }
}

class KeychainController: KeychainControllerProtocol {
    /// The keychain responsible for storing account restoration tokens (keyed by userID).
    private let restorationTokenKeychain: Keychain
    /// The keychain responsible for storing all other secrets in the app (keyed by `Key`s).
    private let mainKeychain: Keychain
    
    private enum Key: String {
        case pinCode
    }

    init(service: KeychainControllerService, accessGroup: String) {
        restorationTokenKeychain = Keychain(service: service.restorationTokenID, accessGroup: accessGroup)
        mainKeychain = Keychain(service: service.mainID, accessGroup: accessGroup)
    }
    
    // MARK: - Restoration Tokens

    func setRestorationToken(_ restorationToken: RestorationToken, forUsername username: String) {
        do {
            let tokenData = try JSONEncoder().encode(restorationToken)
            try restorationTokenKeychain.set(tokenData, key: username)
        } catch {
            MXLog.error("Failed storing user restore token with error: \(error)")
        }
    }

    func restorationTokenForUsername(_ username: String) -> RestorationToken? {
        do {
            guard let tokenData = try restorationTokenKeychain.getData(username) else {
                return nil
            }

            return try JSONDecoder().decode(RestorationToken.self, from: tokenData)
        } catch {
            MXLog.error("Failed retrieving user restore token")
            return nil
        }
    }

    func restorationTokens() -> [KeychainCredentials] {
        restorationTokenKeychain.allKeys().compactMap { username in
            guard let restorationToken = restorationTokenForUsername(username) else {
                return nil
            }

            return KeychainCredentials(userID: username, restorationToken: restorationToken)
        }
    }

    func removeRestorationTokenForUsername(_ username: String) {
        MXLog.warning("Removing restoration token for user: \(username).")
        
        do {
            try restorationTokenKeychain.remove(username)
        } catch {
            MXLog.error("Failed removing restore token with error: \(error)")
        }
    }

    func removeAllRestorationTokens() {
        MXLog.warning("Removing all user restoration tokens.")
        
        do {
            try restorationTokenKeychain.removeAll()
        } catch {
            MXLog.error("Failed removing all tokens")
        }
    }
    
    // MARK: - ClientSessionDelegate
    
    func retrieveSessionFromKeychain(userId: String) throws -> Session {
        MXLog.info("Retrieving an updated Session from the keychain.")
        guard let session = restorationTokenForUsername(userId)?.session else {
            throw ClientError.Generic(msg: "Failed to find RestorationToken in the Keychain.")
        }
        return session
    }
    
    func saveSessionInKeychain(session: Session) {
        MXLog.info("Saving session changes in the keychain.")
        let restorationToken = RestorationToken(session: session)
        setRestorationToken(restorationToken, forUsername: session.userId)
    }
    
    // MARK: - App Secrets
    
    func resetSecrets() {
        MXLog.warning("Resetting main keychain.")
        
        do {
            try mainKeychain.removeAll()
        } catch {
            MXLog.error("Failed resetting the main keychain.")
        }
    }
    
    func containsPINCode() throws -> Bool {
        try mainKeychain.contains(Key.pinCode.rawValue)
    }
    
    func setPINCode(_ pinCode: String) throws {
        try mainKeychain.set(pinCode, key: Key.pinCode.rawValue)
    }
    
    func pinCode() -> String? {
        do {
            return try mainKeychain.getString(Key.pinCode.rawValue)
        } catch {
            MXLog.error("Failed retrieving the PIN code.")
            return nil
        }
    }
    
    func removePINCode() {
        do {
            try mainKeychain.remove(Key.pinCode.rawValue)
        } catch {
            MXLog.error("Failed removing the PIN code.")
        }
    }
}
