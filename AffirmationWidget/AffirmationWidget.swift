import AffirmationShared
import WidgetKit
import SwiftUI

struct AffirmationEntry: TimelineEntry {
    let date: Date
    let affirmation: String
}

struct AffirmationProvider: TimelineProvider {
    func placeholder(in context: Context) -> AffirmationEntry {
        AffirmationEntry(date: Date(), affirmation: "You are amazing!")
    }

    func getSnapshot(in context: Context, completion: @escaping (AffirmationEntry) -> Void) {
        let entry = AffirmationEntry(date: Date(), affirmation: loadFavorite() ?? "You are enough.")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AffirmationEntry>) -> Void) {
        let entry = AffirmationEntry(date: Date(), affirmation: loadFavorite() ?? "You are enough.")
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadFavorite() -> String? {
        if let data = UserDefaults(suiteName: "group.bethsitruc.affirmationapp")?.data(forKey: "affirmations_key"),
           let affirmations = try? JSONDecoder().decode([Affirmation].self, from: data),
           let favorite = affirmations.first(where: { $0.isFavorite }) {
            return favorite.text
        }
        return nil
    }
}

struct AffirmationWidgetEntryView: View {
    var entry: AffirmationProvider.Entry

    var body: some View {
        Text(entry.affirmation)
            .padding()
            .font(.headline)
    }
}

struct AffirmationWidget: Widget {
    let kind: String = "AffirmationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AffirmationProvider()) { entry in
            AffirmationWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Affirmation")
        .description("Displays a favorite affirmation on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
