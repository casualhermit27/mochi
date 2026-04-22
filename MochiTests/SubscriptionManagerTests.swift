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
    
    func testFreeUserDoesNotHaveFullAccess() {
        // Given: A free user
        subscription.isPro = false
        subscription.isOnTrial = false
        subscription.trialDaysRemaining = 0
        
        // Then: Full access should be restricted
        XCTAssertFalse(subscription.isFullAccess, "Free users should not have full access.")
        XCTAssertEqual(subscription.statusLabel, "Free", "Status label should show Free for free users.")
    }
    
    func testRevenueCatTrialHasFullAccess() {
        // Given: RevenueCat reports an active trial entitlement
        subscription.isPro = true
        subscription.isOnTrial = true
        subscription.trialDaysRemaining = 3
        
        // Then: The trial should unlock full access
        XCTAssertTrue(subscription.isFullAccess, "Active RevenueCat trials should have full access.")
        XCTAssertEqual(subscription.statusLabel, "Trial · 3d left", "Status label should reflect trial remaining.")
    }
    
    func testProAlwaysHasAccess() {
        // Given: A subscribed user
        subscription.isPro = true
        subscription.isOnTrial = false
        subscription.activeProductId = nil
        
        // Then: They should have permanent access
        XCTAssertTrue(subscription.isFullAccess, "Pro users must always have access.")
        XCTAssertEqual(subscription.statusLabel, "Mochi+ Active", "Status label should reflect active subscription.")
    }
}
