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

@testable import ElementX
import XCTest

class KeychainControllerTests: XCTestCase {
    var keychain: KeychainController!
    
    override func setUp() {
        keychain = KeychainController(service: .tests,
                                      accessGroup: InfoPlistReader.main.keychainAccessGroupIdentifier)
        keychain.removeAllRestorationTokens()
        keychain.resetSecrets()
    }
    
    func testAddRestorationToken() {
        // Given an empty keychain.
        XCTAssertTrue(keychain.restorationTokens().isEmpty, "The keychain should be empty to begin with.")
        
        // When adding an restoration token.
        let username = "@test:example.com"
        let restorationToken = RestorationToken(session: .init(accessToken: "accessToken",
                                                               refreshToken: "refreshToken",
                                                               userId: "userId",
                                                               deviceId: "deviceId",
                                                               homeserverUrl: "homeserverUrl",
                                                               oidcData: "oidcData",
                                                               slidingSyncProxy: "https://my.sync.proxy"))
        keychain.setRestorationToken(restorationToken, forUsername: username)
        
        // Then the restoration token should be stored in the keychain.
        XCTAssertEqual(keychain.restorationTokenForUsername(username), restorationToken, "The retrieved restoration token should match the value that was stored.")
    }
    
    func testRemovingRestorationToken() {
        // Given a keychain with a stored restoration token.
        let username = "@test:example.com"
        let restorationToken = RestorationToken(session: .init(accessToken: "accessToken",
                                                               refreshToken: "refreshToken",
                                                               userId: "userId",
                                                               deviceId: "deviceId",
                                                               homeserverUrl: "homeserverUrl",
                                                               oidcData: "oidcData",
                                                               slidingSyncProxy: "https://my.sync.proxy"))
        keychain.setRestorationToken(restorationToken, forUsername: username)
        XCTAssertEqual(keychain.restorationTokens().count, 1, "The keychain should have 1 restoration token.")
        XCTAssertEqual(keychain.restorationTokenForUsername(username), restorationToken, "The initial restoration token should match the value that was stored.")
        
        // When deleting the restoration token.
        keychain.removeRestorationTokenForUsername(username)
        
        // Then the keychain should be empty.
        XCTAssertTrue(keychain.restorationTokens().isEmpty, "The keychain should be empty after deleting the token.")
        XCTAssertNil(keychain.restorationTokenForUsername(username), "There restoration token should not be returned after removal.")
    }
    
    func testRemovingAllRestorationTokens() {
        // Given a keychain with 5 stored restoration tokens.
        for index in 0..<5 {
            let restorationToken = RestorationToken(session: .init(accessToken: "accessToken",
                                                                   refreshToken: "refreshToken",
                                                                   userId: "userId",
                                                                   deviceId: "deviceId",
                                                                   homeserverUrl: "homeserverUrl",
                                                                   oidcData: "oidcData",
                                                                   slidingSyncProxy: "https://my.sync.proxy"))
            keychain.setRestorationToken(restorationToken, forUsername: "@test\(index):example.com")
        }
        XCTAssertEqual(keychain.restorationTokens().count, 5, "The keychain should have 5 restoration tokens.")
        
        // When deleting all of the restoration tokens.
        keychain.removeAllRestorationTokens()
        
        // Then the keychain should be empty.
        XCTAssertTrue(keychain.restorationTokens().isEmpty, "The keychain should be empty after deleting the token.")
    }
    
    func testRemovingSingleRestorationTokens() {
        // Given a keychain with 5 stored restoration tokens.
        for index in 0..<5 {
            let restorationToken = RestorationToken(session: .init(accessToken: "accessToken",
                                                                   refreshToken: "refreshToken",
                                                                   userId: "userId",
                                                                   deviceId: "deviceId",
                                                                   homeserverUrl: "homeserverUrl",
                                                                   oidcData: "oidcData",
                                                                   slidingSyncProxy: "https://my.sync.proxy"))
            keychain.setRestorationToken(restorationToken, forUsername: "@test\(index):example.com")
        }
        XCTAssertEqual(keychain.restorationTokens().count, 5, "The keychain should have 5 restoration tokens.")
        
        // When deleting one of the restoration tokens.
        keychain.removeRestorationTokenForUsername("@test2:example.com")
        
        // Then the other 4 items should remain untouched.
        XCTAssertEqual(keychain.restorationTokens().count, 4, "The keychain have 4 remaining restoration tokens.")
        XCTAssertNotNil(keychain.restorationTokenForUsername("@test0:example.com"), "The restoration token should not have been deleted.")
        XCTAssertNotNil(keychain.restorationTokenForUsername("@test1:example.com"), "The restoration token should not have been deleted.")
        XCTAssertNil(keychain.restorationTokenForUsername("@test2:example.com"), "The restoration token should have been deleted.")
        XCTAssertNotNil(keychain.restorationTokenForUsername("@test3:example.com"), "The restoration token should not have been deleted.")
        XCTAssertNotNil(keychain.restorationTokenForUsername("@test4:example.com"), "The restoration token should not have been deleted.")
    }
    
    func testAddPINCode() throws {
        // Given a keychain without a PIN code set.
        try XCTAssertFalse(keychain.containsPINCode(), "A new keychain shouldn't contain a PIN code.")
        XCTAssertNil(keychain.pinCode(), "A new keychain shouldn't return a PIN code.")
        
        // When setting a PIN code.
        try keychain.setPINCode("0000")
        
        // The the PIN code should be stored.
        try XCTAssertTrue(keychain.containsPINCode(), "The keychain should contain the PIN code.")
        XCTAssertEqual(keychain.pinCode(), "0000", "The stored PIN code should match what was set.")
    }
    
    func testUpdatePINCode() throws {
        // Given a keychain with a PIN code already set.
        try keychain.setPINCode("0000")
        try XCTAssertTrue(keychain.containsPINCode(), "The keychain should contain the PIN code.")
        XCTAssertEqual(keychain.pinCode(), "0000", "The stored PIN code should match what was set.")
        
        // When setting a different PIN code.
        try keychain.setPINCode("1234")
        
        // The the PIN code should be updated.
        try XCTAssertTrue(keychain.containsPINCode(), "The keychain should still contain the PIN code.")
        XCTAssertEqual(keychain.pinCode(), "1234", "The stored PIN code should match the new value.")
    }
    
    func testRemovePINCode() throws {
        // Given a keychain with a PIN code already set.
        try keychain.setPINCode("0000")
        try XCTAssertTrue(keychain.containsPINCode(), "The keychain should contain the PIN code.")
        XCTAssertEqual(keychain.pinCode(), "0000", "The stored PIN code should match what was set.")
        
        // When removing the PIN code.
        keychain.removePINCode()
        
        // The the PIN code should no longer be stored.
        try XCTAssertFalse(keychain.containsPINCode(), "The keychain should no longer contain the PIN code.")
        XCTAssertNil(keychain.pinCode(), "There shouldn't be a stored PIN code after removing it.")
    }
}
