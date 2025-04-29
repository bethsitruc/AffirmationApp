//
//  AffirmationWidgetLiveActivity.swift
//  AffirmationWidget
//
//  Created by Bethany Curtis on 4/4/25.
//

// MARK: - Live Activity Widget for Affirmation App
// This widget uses ActivityKit to provide live content on the Lock Screen and Dynamic Island

import ActivityKit
import WidgetKit
import SwiftUI

// Defines the attributes used in the live activity widget.
// Includes both static and dynamic properties.
struct AffirmationWidgetAttributes: ActivityAttributes {
    // Represents dynamic properties that can change during the activity lifecycle.
    public struct ContentState: Codable, Hashable {
        // Emoji used to visually represent the current affirmation or state.
        var emoji: String
    }

    // Static name value representing the live activity instance.
    var name: String
}

// Main widget structure conforming to the Widget protocol.
// Configures how the live activity and Dynamic Island UI should appear.
struct AffirmationWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AffirmationWidgetAttributes.self) { context in
            // UI shown on the Lock Screen or in banners while the activity is live.
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            // Sets the background tint color for the activity view.
            .activityBackgroundTint(Color.cyan)
            // Sets the color for system action icons and text.
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            // Defines the expanded UI of the Dynamic Island.
            DynamicIsland {
                // Region-specific UI in the expanded state of the Dynamic Island.
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                // Region-specific UI in the expanded state of the Dynamic Island.
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                // Region-specific UI in the expanded state of the Dynamic Island.
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            // UI for different compact and minimal presentations in the Dynamic Island.
            } compactLeading: {
                Text("L")
            // UI for different compact and minimal presentations in the Dynamic Island.
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            // UI for different compact and minimal presentations in the Dynamic Island.
            } minimal: {
                Text(context.state.emoji)
            }
            // Optional URL to open when tapping the widget.
            .widgetURL(URL(string: "http://www.apple.com"))
            // Sets the tint color used for keylines in the widget.
            .keylineTint(Color.red)
        }
    }
}

// MARK: - Preview Support
// Preview data to render the widget in Xcode canvas.
extension AffirmationWidgetAttributes {
    fileprivate static var preview: AffirmationWidgetAttributes {
        AffirmationWidgetAttributes(name: "World")
    }
}

// Provides sample ContentState values for widget previews.
extension AffirmationWidgetAttributes.ContentState {
    fileprivate static var smiley: AffirmationWidgetAttributes.ContentState {
        AffirmationWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AffirmationWidgetAttributes.ContentState {
         AffirmationWidgetAttributes.ContentState(emoji: "🤩")
     }
}

// SwiftUI Preview for this live activity widget with sample states.
#Preview("Notification", as: .content, using: AffirmationWidgetAttributes.preview) {
   AffirmationWidgetLiveActivity()
} contentStates: {
    AffirmationWidgetAttributes.ContentState.smiley
    AffirmationWidgetAttributes.ContentState.starEyes
}
