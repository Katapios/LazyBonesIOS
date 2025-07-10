//
//  LazyBonesWidgetLiveActivity.swift
//  LazyBonesWidget
//
//  Created by Денис Рюмин on 10.07.2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LazyBonesWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LazyBonesWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LazyBonesWidgetAttributes.self) { context in
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

extension LazyBonesWidgetAttributes {
    fileprivate static var preview: LazyBonesWidgetAttributes {
        LazyBonesWidgetAttributes(name: "World")
    }
}

extension LazyBonesWidgetAttributes.ContentState {
    fileprivate static var smiley: LazyBonesWidgetAttributes.ContentState {
        LazyBonesWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LazyBonesWidgetAttributes.ContentState {
         LazyBonesWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LazyBonesWidgetAttributes.preview) {
   LazyBonesWidgetLiveActivity()
} contentStates: {
    LazyBonesWidgetAttributes.ContentState.smiley
    LazyBonesWidgetAttributes.ContentState.starEyes
}
