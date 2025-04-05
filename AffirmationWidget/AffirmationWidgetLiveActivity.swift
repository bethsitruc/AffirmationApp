//
//  AffirmationWidgetLiveActivity.swift
//  AffirmationWidget
//
//  Created by Bethany Curtis on 4/4/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct AffirmationWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct AffirmationWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AffirmationWidgetAttributes.self) { context in
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

extension AffirmationWidgetAttributes {
    fileprivate static var preview: AffirmationWidgetAttributes {
        AffirmationWidgetAttributes(name: "World")
    }
}

extension AffirmationWidgetAttributes.ContentState {
    fileprivate static var smiley: AffirmationWidgetAttributes.ContentState {
        AffirmationWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AffirmationWidgetAttributes.ContentState {
         AffirmationWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: AffirmationWidgetAttributes.preview) {
   AffirmationWidgetLiveActivity()
} contentStates: {
    AffirmationWidgetAttributes.ContentState.smiley
    AffirmationWidgetAttributes.ContentState.starEyes
}
