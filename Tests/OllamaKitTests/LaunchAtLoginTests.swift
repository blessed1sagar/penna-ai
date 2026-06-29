//
//  LaunchAtLoginTests.swift
//  OllamaKitTests
//
//  Issue #30 — launch-at-login backed by SMAppService.
//

import Testing
import ServiceManagement
@testable import OllamaKit

@MainActor
@Suite struct LaunchAtLoginTests {
    // We can't exercise register()/unregister() here: SMAppService.mainApp needs a
    // real, signed .app bundle, which the test runner is not — calling it would
    // either no-op or throw, and would mutate the developer's actual Login Items.
    // What we CAN pin down without side effects is the contract the Settings toggle
    // relies on: `isEnabled` is defined as "status == .enabled", so it agrees with a
    // direct read of the underlying SMAppService status. This catches an accidental
    // inversion (e.g. reading != or the wrong status case) in the seam the UI binds.
    @Test func isEnabledMatchesUnderlyingStatus() {
        let expected = SMAppService.mainApp.status == .enabled
        #expect(LaunchAtLogin.isEnabled == expected)
    }
}
