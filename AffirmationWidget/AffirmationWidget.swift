// AffirmationWidget.swift
// Widget extension to display daily affirmations on the Home Screen.

import WidgetKit
import SwiftUI
import AffirmationShared

/// Main widget structure for the Affirmation App.
@main
struct AffirmationWidget: Widget {
    let kind: String = "AffirmationWidget"
    
    /// Defines the widget configuration and display properties.
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: AffirmationProvider()
        ) { entry in
            AffirmationWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Affirmation")
        .description("Displays a selected or default affirmation.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Model representing a single widget entry (affirmation with timestamp).
struct AffirmationEntry: TimelineEntry {
    let date: Date
    let affirmation: String
}

/// Provides timeline entries for the widget, including placeholder, snapshot, and timeline.
struct AffirmationProvider: TimelineProvider {
    /// Placeholder view used while loading or during widget configuration preview.
    func placeholder(in context: Context) -> AffirmationEntry {
        AffirmationEntry(date: Date(), affirmation: "You are enough.")
    }

    /// Provides a snapshot entry for quick widget previews.
    func getSnapshot(in context: Context, completion: @escaping (AffirmationEntry) -> Void) {
        let selected = UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?
            .string(forKey: "selected_widget_affirmation") ?? "You are worthy."
        completion(AffirmationEntry(date: Date(), affirmation: selected))
    }

    /// Provides the actual timeline of entries for the widget (simple one-time entry).
    func getTimeline(in context: Context, completion: @escaping (Timeline<AffirmationEntry>) -> Void) {
        let selected = UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?
            .string(forKey: "selected_widget_affirmation") ?? "You are resilient."
        let entry = AffirmationEntry(date: Date(), affirmation: selected)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

/// Displays the widget's visual layout.
struct AffirmationWidgetEntryView: View {
    var entry: AffirmationProvider.Entry

    var body: some View {
        /// Background gradient and affirmation text layout.
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.green.opacity(0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(16)
            
            Text(entry.affirmation)
                .multilineTextAlignment(.center)
                .padding()
                .font(.headline)
        }
        .padding()
    }
}
