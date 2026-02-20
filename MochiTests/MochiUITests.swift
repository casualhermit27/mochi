//
//  MochiUITests.swift
//  MochiUITests
//

import XCTest

final class MochiUITests: XCTestCase {
    
    let app = XCUIApplication()

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        app.launch()
    }

    func testComprehensiveUserFlow() throws {
        // 1. Handle Onboarding if it appears
        let continueButton = app.buttons["onboarding_continue_button"]
        if continueButton.exists {
            // First Page
            continueButton.tap()
            
            // Second Page
            XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
            continueButton.tap()
            
            // Third Page (Spending Mockup)
            let iSpentButton = app.buttons["I Spent"]
            if iSpentButton.exists {
                iSpentButton.tap()
            }
            
            // Fourth Page (Paywall) - Using identifier or text
            let startTrial = app.buttons["Start 3-Day Free Trial"]
            let skipToMochi = app.buttons["onboarding_skip_button"]
            
            if startTrial.exists {
                // For testing purposes, we might want to skip or simulate a purchase
                // For now, let's skip to get to the main app if possible
                if skipToMochi.exists {
                    skipToMochi.tap()
                } else {
                    startTrial.tap()
                }
            } else if skipToMochi.exists {
                skipToMochi.tap()
            }
        }
        
        // 2. Logging a Transaction
        // Tap '1', '2', '.' '5', '0'
        let key1 = app.staticTexts["1"]
        let key2 = app.staticTexts["2"]
        let keyDot = app.staticTexts["."]
        let key5 = app.staticTexts["5"]
        let key0 = app.staticTexts["0"]
        
        if key1.exists {
            key1.tap()
            key2.tap()
            keyDot.tap()
            key5.tap()
            key0.tap()
        }
        
        // Verify Display Value
        let displayValue = app.staticTexts["display_value"]
        XCTAssertTrue(displayValue.exists)
        // Some flexibility on exact string due to formatting (12.50 or 12.5)
        XCTAssertTrue(displayValue.label.contains("12.5"))
        
        // Tap 'I Spent'
        let spentButton = app.buttons["spent_button"]
        XCTAssertTrue(spentButton.exists)
        spentButton.tap()
        
        // 3. Settings Navigation
        let settingsButton = app.buttons["settings_button"]
        XCTAssertTrue(settingsButton.exists)
        settingsButton.tap()
        
        // Membership Section
        let membershipCard = app.buttons["membership_card"]
        XCTAssertTrue(membershipCard.exists)
        
        // Appearance Section
        let appearanceRow = app.buttons["appearance_row"]
        XCTAssertTrue(appearanceRow.exists)
        appearanceRow.tap()
        
        // Verify Toggle
        let matchThemeToggle = app.switches["widget_match_theme_toggle"]
        XCTAssertTrue(matchThemeToggle.exists)
        
        // Go Back
        let backButton = app.buttons["back_button"]
        XCTAssertTrue(backButton.exists)
        backButton.tap()
        
        // Logging Section
        let loggingRow = app.buttons["logging_row"]
        XCTAssertTrue(loggingRow.exists)
        loggingRow.tap()
        XCTAssertTrue(backButton.waitForExistence(timeout: 1))
        backButton.tap()
        
        // About Section
        let aboutRow = app.buttons["about_row"]
        XCTAssertTrue(aboutRow.exists)
        aboutRow.tap()
        
        let restoreButton = app.buttons["Restore Purchase"]
        XCTAssertTrue(restoreButton.exists)
        
        // Close Settings
        let closeSettings = app.buttons["close_settings_button"]
        if closeSettings.exists {
            closeSettings.tap()
        } else if backButton.exists {
            backButton.tap()
            closeSettings.tap()
        }
        
        // 4. History Navigation
        let historyButton = app.buttons["history_button"]
        if historyButton.exists {
            historyButton.tap()
            // Verify history title or some element
            XCTAssertTrue(app.staticTexts["HISTORY"].exists || app.staticTexts["History"].exists)
        }
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
