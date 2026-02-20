//
//  SettingsManagerTests.swift
//  MochiTests
//

import XCTest
@testable import Mochi

final class SettingsManagerTests: XCTestCase {
    
    var settings: SettingsManager!
    
    override func setUp() {
        super.setUp()
        settings = SettingsManager.shared
    }
    
    func testDaysSinceFirstUseCalculation() {
        // Given: A first launch date exactly 2 days ago
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        settings.firstLaunchDate = twoDaysAgo.timeIntervalSince1970
        
        // Then: The calculation should return 2 days
        XCTAssertEqual(settings.daysSinceFirstUse, 2, "daysSinceFirstUse should accurately calculate the difference in days.")
    }
    
    func testNewUserDaysSinceFirstUse() {
        // Given: A brand new user where firstLaunchDate is not yet set (0)
        settings.firstLaunchDate = 0
        
        // Then: It should return 0
        XCTAssertEqual(settings.daysSinceFirstUse, 0, "A new user should have 0 days since first use.")
    }
    
    func testThemePersistence() {
        // Given: A specific theme selection
        let testTheme = "amoled"
        settings.themeMode = testTheme
        
        // Then: The value should be persisted (verified via internal state)
        XCTAssertEqual(settings.themeMode, testTheme, "Theme mode should be persisted and retrieved correctly.")
    }
}
