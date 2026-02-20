//
//  MochiWidgetControl.swift
//  MochiWidget
//

import AppIntents
import SwiftUI
import WidgetKit

struct MochiWidgetControl: ControlWidget {
    static let kind: String = "com.mochi.log-spending-control"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LaunchMochiIntent()) {
                Label("Mochi", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Mochi")
        .description("Quickly open Mochi to log your spending.")
    }
}

struct LaunchMochiIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Mochi"
    static let openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
