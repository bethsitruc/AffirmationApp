import WidgetKit
import SwiftUI
import AffirmationShared

@main
struct AffirmationWidget: Widget {
    let kind: String = "AffirmationWidget"
    
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

struct AffirmationEntry: TimelineEntry {
    let date: Date
    let affirmation: String
}

struct AffirmationProvider: TimelineProvider {
    func placeholder(in context: Context) -> AffirmationEntry {
        AffirmationEntry(date: Date(), affirmation: "You are enough.")
    }

    func getSnapshot(in context: Context, completion: @escaping (AffirmationEntry) -> Void) {
        let selected = UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?
            .string(forKey: "selected_widget_affirmation") ?? "You are worthy."
        completion(AffirmationEntry(date: Date(), affirmation: selected))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AffirmationEntry>) -> Void) {
        let selected = UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?
            .string(forKey: "selected_widget_affirmation") ?? "You are resilient."
        let entry = AffirmationEntry(date: Date(), affirmation: selected)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct AffirmationWidgetEntryView: View {
    var entry: AffirmationProvider.Entry

    var body: some View {
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
