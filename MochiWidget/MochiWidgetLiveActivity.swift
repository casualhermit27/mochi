//
//  MochiWidgetLiveActivity.swift
//  MochiWidget
//
//  Created by Harsha on 17/01/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MochiWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MochiWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MochiWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension MochiWidgetAttributes {
    fileprivate static var preview: MochiWidgetAttributes {
        MochiWidgetAttributes(name: "World")
    }
}

extension MochiWidgetAttributes.ContentState {
    fileprivate static var smiley: MochiWidgetAttributes.ContentState {
        MochiWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: MochiWidgetAttributes.ContentState {
         MochiWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: MochiWidgetAttributes.preview) {
   MochiWidgetLiveActivity()
} contentStates: {
    MochiWidgetAttributes.ContentState.smiley
    MochiWidgetAttributes.ContentState.starEyes
}
