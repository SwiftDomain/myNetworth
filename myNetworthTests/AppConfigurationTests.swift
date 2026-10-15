//
//  AppConfigurationTests.swift
//  myNetworthTests
//
//  Settings in the app's Info.plist that App Store uploads and iCloud sync rely on.
//

import Foundation
import Testing
@testable import myNetworth

@MainActor
@Suite("App configuration")
struct AppConfigurationTests {

    @Test("Declares only exempt encryption, so App Store Connect doesn't ask on every upload")
    func encryptionDeclaration() {
        let usesNonExemptEncryption = Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool
        #expect(usesNonExemptEncryption == false)
    }

    @Test("Can be woken in the background when iCloud has changes")
    func remoteNotificationBackgroundMode() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        #expect(modes.contains("remote-notification"))
    }
}
