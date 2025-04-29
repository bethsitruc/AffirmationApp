//
//  AffirmationWidgetControl.swift
//  AffirmationWidget
//
//  Created by Bethany Curtis on 4/4/25.
//

// Defines a widget control for AffirmationWidget allowing timer-like interactions.

import AppIntents
import SwiftUI
import WidgetKit

// A widget control allowing users to start/stop a timer through the widget interface.
struct AffirmationWidgetControl: ControlWidget {
    // Defines the widget control's appearance and behavior.
    var body: some ControlWidgetConfiguration {
        // Sets up a static control widget with a toggle to start a timer.
        StaticControlConfiguration(
            kind: "bethsitruc.AffirmationApp.AffirmationWidget",
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Start Timer",
                isOn: value,
                action: StartTimerIntent()
            ) { isRunning in
                Label(isRunning ? "On" : "Off", systemImage: "timer")
            }
        }
        // Metadata for the widget shown in widget selection UI.
        .displayName("Timer")
        .description("A an example control that runs a timer.")
    }
}

// Provides the current state value for the control (whether the timer is running).
extension AffirmationWidgetControl {
    struct Provider: ControlValueProvider {
        // Preview value shown in widget previews.
        var previewValue: Bool {
            false
        }

        // Asynchronously provides the actual current value of the timer.
        func currentValue() async throws -> Bool {
            let isRunning = true // Check if the timer is running
            return isRunning
        }
    }
}

// Defines an intent to start or stop the timer when the widget is toggled.
struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    // Represents whether the timer should be running.
    @Parameter(title: "Timer is running")
    var value: Bool

    // Handles the action when the user toggles the timer on/off.
    func perform() async throws -> some IntentResult {
        // Start / stop the timer based on `value`.
        return .result()
    }
}
