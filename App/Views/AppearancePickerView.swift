import SwiftUI
import AffirmationShared

struct AppearancePickerView: View {
    @ObservedObject var appearance: AppearanceSettings

    var body: some View {
        List {
            Section(header: Text("Preview")) {
                previewCard
                    .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
            }

            Section(header: Text("Color Theme")) {
                ForEach(AffirmationColorTheme.allCases) { theme in
                    Button {
                        appearance.updateTheme(theme)
                    } label: {
                        ThemeOptionRow(theme: theme, isSelected: theme == appearance.theme)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section(header: Text("Typography")) {
                ForEach(AffirmationFontPreference.allCases) { font in
                    Button {
                        appearance.updateFont(font)
                    } label: {
                        FontOptionRow(font: font, isSelected: font == appearance.font)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Text("Selections here set the default appearance for both the app’s share cards and every Home Screen widget. Sage serif remains the default if you ever reset.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Appearance")
    }

    private var previewCard: some View {
        let colors = appearance.theme.widgetColors
        return VStack(alignment: .leading, spacing: 10) {
            Text("Sample")
                .font(.caption.smallCaps())
                .foregroundColor(colors.subtitle)
            Text("You are exactly where you need to be.")
                .font(appearance.font.swiftUIFont)
                .foregroundColor(colors.text)
                .lineLimit(3)
                .minimumScaleFactor(0.9)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(appearance.theme.gradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(colors.subtitle.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct ThemeOptionRow: View {
    let theme: AffirmationColorTheme
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.gradient)
                .frame(width: 48, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            Text(theme.displayName)
                .font(.body.weight(.medium))

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.accentColor)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

private struct FontOptionRow: View {
    let font: AffirmationFontPreference
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(font.displayName)
                .font(.body.weight(.medium))
            Spacer()
            Text(sampleText)
                .font(sampleFont)
                .foregroundColor(.secondary)
                .lineLimit(1)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .padding(.leading, 4)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var sampleFont: Font {
        switch font {
        case .serif: return .system(.headline, design: .serif)
        case .rounded: return .system(.headline, design: .rounded)
        case .modern: return .system(.headline, design: .default)
        }
    }

    private var sampleText: String {
        switch font {
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        case .modern: return "Modern"
        }
    }
}
