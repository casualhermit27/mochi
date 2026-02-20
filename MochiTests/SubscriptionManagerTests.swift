//
//  SubscriptionManagerTests.swift
//  MochiTests
//

import XCTest
@testable import Mochi

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    
    var subscription: SubscriptionManager!
    var settings: SettingsManager!
    
    override func setUp() {
        super.setUp()
        subscription = SubscriptionManager.shared
        settings = SettingsManager.shared
    }
    
    func testFullAccessDuringTrial() {
        // Given: A new user (Day 0)
        settings.firstLaunchDate = Date().timeIntervalSince1970
        subscription.isPro = false
        
        // Then: They should have full access via soft trial
        XCTAssertTrue(subscription.isFullAccess, "Should have full access during the 3-day window.")
        XCTAssertTrue(subscription.isSoftTrial, "Should be identified as being in soft trial.")
        XCTAssertEqual(subscription.statusLabel, "Trial Active · 3d left", "Status label should reflect trial remaining.")
    }
    
    func testAccessExpiredAfter3Days() {
        // Given: A user who launched 4 days ago
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        settings.firstLaunchDate = fourDaysAgo.timeIntervalSince1970
        subscription.isPro = false
        
        // Then: Access should be restricted
        XCTAssertFalse(subscription.isFullAccess, "Access should expire after the 3-day window.")
        XCTAssertFalse(subscription.isSoftTrial, "Soft trial should no longer be active.")
        XCTAssertEqual(subscription.statusLabel, "Free", "Status label should show Free for expired users.")
    }
    
    func testProAlwaysHasAccess() {
        // Given: A subscribed user even with an old launch date
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        settings.firstLaunchDate = tenDaysAgo.timeIntervalSince1970
        subscription.isPro = true
        
        // Then: They should have permanent access
        XCTAssertTrue(subscription.isFullAccess, "Pro users must always have access.")
        XCTAssertFalse(subscription.isSoftTrial, "Pro users are not in 'soft trial'.")
        XCTAssertEqual(subscription.statusLabel, "Mochi+ Active", "Status label should reflect active subscription.")
    }
}
