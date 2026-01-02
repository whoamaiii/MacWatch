import Foundation
import SwiftUI

/// Manages notes and tags for focus sessions
@MainActor
public final class SessionNotesManager: ObservableObject {
    public static let shared = SessionNotesManager()

    /// Predefined tags for quick selection
    public static let defaultTags: [String] = [
        "Deep Work",
        "Meetings",
        "Coding",
        "Writing",
        "Research",
        "Design",
        "Planning",
        "Learning",
        "Review",
        "Admin"
    ]

    @Published public var customTags: [String] = []

    private let notesKey = "sessionNotes"
    private let tagsKey = "sessionTags"
    private let customTagsKey = "customSessionTags"

    private init() {
        loadCustomTags()
    }

    // MARK: - Notes

    /// Get note for a session
    public func getNote(for sessionId: Int64) -> String? {
        let notes = getAllNotes()
        return notes[String(sessionId)]
    }

    /// Set note for a session
    public func setNote(_ note: String?, for sessionId: Int64) {
        var notes = getAllNotes()
        if let note = note, !note.isEmpty {
            notes[String(sessionId)] = note
        } else {
            notes.removeValue(forKey: String(sessionId))
        }
        saveNotes(notes)
    }

    private func getAllNotes() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: notesKey),
              let notes = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return notes
    }

    private func saveNotes(_ notes: [String: String]) {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }

    // MARK: - Tags

    /// Get tags for a session
    public func getTags(for sessionId: Int64) -> [String] {
        let allTags = getAllSessionTags()
        return allTags[String(sessionId)] ?? []
    }

    /// Set tags for a session
    public func setTags(_ tags: [String], for sessionId: Int64) {
        var allTags = getAllSessionTags()
        if tags.isEmpty {
            allTags.removeValue(forKey: String(sessionId))
        } else {
            allTags[String(sessionId)] = tags
        }
        saveSessionTags(allTags)
    }

    /// Add a tag to a session
    public func addTag(_ tag: String, to sessionId: Int64) {
        var tags = getTags(for: sessionId)
        if !tags.contains(tag) {
            tags.append(tag)
            setTags(tags, for: sessionId)
        }
    }

    /// Remove a tag from a session
    public func removeTag(_ tag: String, from sessionId: Int64) {
        var tags = getTags(for: sessionId)
        tags.removeAll { $0 == tag }
        setTags(tags, for: sessionId)
    }

    private func getAllSessionTags() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: tagsKey),
              let tags = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return tags
    }

    private func saveSessionTags(_ tags: [String: [String]]) {
        if let data = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(data, forKey: tagsKey)
        }
    }

    // MARK: - Custom Tags

    /// Add a custom tag (max 50 characters, max 100 custom tags)
    public func addCustomTag(_ tag: String) {
        let trimmedTag = String(tag.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
        guard !trimmedTag.isEmpty,
              !customTags.contains(trimmedTag),
              !Self.defaultTags.contains(trimmedTag),
              customTags.count < 100 else {
            return
        }
        customTags.append(trimmedTag)
        saveCustomTags()
    }

    /// Remove a custom tag
    public func removeCustomTag(_ tag: String) {
        customTags.removeAll { $0 == tag }
        saveCustomTags()
    }

    /// Get all available tags (default + custom)
    public var allTags: [String] {
        Self.defaultTags + customTags
    }

    private func loadCustomTags() {
        if let tags = UserDefaults.standard.stringArray(forKey: customTagsKey) {
            customTags = tags
        }
    }

    private func saveCustomTags() {
        UserDefaults.standard.set(customTags, forKey: customTagsKey)
    }
}

// MARK: - Session Note View

struct SessionNoteEditor: View {
    let sessionId: Int64
    @Binding var isPresented: Bool

    @State private var note: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var newTagText: String = ""

    @ObservedObject private var notesManager = SessionNotesManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            // Header
            HStack {
                Text("Session Notes")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Tags section
            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                Text("Tags")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                // Tag chips
                FlowLayout(spacing: 8) {
                    ForEach(notesManager.allTags, id: \.self) { tag in
                        TagChip(
                            title: tag,
                            isSelected: selectedTags.contains(tag)
                        ) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    }

                    // Add custom tag button
                    HStack(spacing: 4) {
                        TextField("New tag", text: $newTagText)
                            .textFieldStyle(.plain)
                            .frame(width: 80)

                        Button {
                            if !newTagText.isEmpty {
                                notesManager.addCustomTag(newTagText)
                                selectedTags.insert(newTagText)
                                newTagText = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(ClarityColors.accentPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(newTagText.isEmpty)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ClarityColors.backgroundSecondary)
                    .cornerRadius(ClarityRadius.sm)
                }
            }

            // Note text area
            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                Text("Notes")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                TextEditor(text: $note)
                    .font(ClarityTypography.body)
                    .frame(height: 100)
                    .padding(ClaritySpacing.sm)
                    .background(ClarityColors.backgroundSecondary)
                    .cornerRadius(ClarityRadius.md)
            }

            // Save button
            HStack {
                Spacer()

                Button("Save") {
                    notesManager.setNote(note.isEmpty ? nil : note, for: sessionId)
                    notesManager.setTags(Array(selectedTags), for: sessionId)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(ClarityColors.accentPrimary)
            }
        }
        .padding(ClaritySpacing.lg)
        .frame(width: 400)
        .background(.ultraThinMaterial)
        .cornerRadius(ClarityRadius.lg)
        .onAppear {
            note = notesManager.getNote(for: sessionId) ?? ""
            selectedTags = Set(notesManager.getTags(for: sessionId))
        }
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : ClarityColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? ClarityColors.accentPrimary : ClarityColors.backgroundSecondary)
                .cornerRadius(ClarityRadius.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}
