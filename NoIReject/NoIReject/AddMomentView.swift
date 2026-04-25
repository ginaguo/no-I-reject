//
//  AddMomentView.swift
//  NoIReject
//

import SwiftUI

struct AddMomentView: View {
    @EnvironmentObject private var store: MomentStore
    @Environment(\.dismiss) private var dismiss

    @State private var momentType: MomentType = .excited
    @State private var intensity: Int = 5
    @State private var selectedTags: Set<String> = []
    @State private var note: String = ""
    @AppStorage("customTags") private var storedCustomTags: String = ""
    @AppStorage("hiddenTags") private var storedHiddenTags: String = ""
    @State private var newTagText: String = ""
    @State private var isEditingTags: Bool = false
    @State private var tagsMarkedForDelete: Set<String> = []
    @State private var showDeleteConfirm: Bool = false

    private var localCustomTags: [String] {
        storedCustomTags.isEmpty ? [] : storedCustomTags.components(separatedBy: ",")
    }
    private var hiddenTags: Set<String> {
        storedHiddenTags.isEmpty ? [] : Set(storedHiddenTags.components(separatedBy: ","))
    }
    /// Custom tags = locally added + any tags found in past moments (DB-backed),
    /// minus predefined and minus user-hidden tags.
    private var customTags: [String] {
        let predefined = Set(predefinedTags)
        let hidden = hiddenTags
        let fromMoments = store.moments.flatMap { $0.tags }
        var seen = Set<String>()
        var result: [String] = []
        for tag in localCustomTags + fromMoments {
            let trimmed = tag.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  !predefined.contains(trimmed),
                  !hidden.contains(trimmed),
                  !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }
    private var allTags: [String] { predefinedTags + customTags }

    private func addCustomTag() {
        let tag = newTagText.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !allTags.contains(tag) else { newTagText = ""; return }
        // Un-hide if previously hidden
        if hiddenTags.contains(tag) {
            storedHiddenTags = hiddenTags.subtracting([tag]).joined(separator: ",")
        }
        if !localCustomTags.contains(tag) {
            storedCustomTags = storedCustomTags.isEmpty ? tag : storedCustomTags + "," + tag
        }
        selectedTags.insert(tag)
        newTagText = ""
    }

    private func removeCustomTag(_ tag: String) {
        // Remove from locally added list
        if localCustomTags.contains(tag) {
            storedCustomTags = localCustomTags.filter { $0 != tag }.joined(separator: ",")
        }
        // Hide so it won't reappear from past moments either
        var hidden = hiddenTags
        hidden.insert(tag)
        storedHiddenTags = hidden.joined(separator: ",")
        selectedTags.remove(tag)
    }

    private func commitBulkDelete() {
        for tag in tagsMarkedForDelete { removeCustomTag(tag) }
        tagsMarkedForDelete.removeAll()
        isEditingTags = false
    }

    private var previewScore: Int {
        momentType == .excited ? intensity : -intensity
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What kind of moment?") {
                    Picker("Type", selection: $momentType) {
                        Text("😤 Uncomfortable").tag(MomentType.uncomfortable)
                        Text("🚀 Excited").tag(MomentType.excited)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Score") {
                    ScoreScrollPicker(intensity: $intensity, momentType: momentType)
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            let isCustom = !predefinedTags.contains(tag)
                            let isSelected = selectedTags.contains(tag)
                            let isMarked = tagsMarkedForDelete.contains(tag)
                            TagChip(
                                tag: tag,
                                isCustom: isCustom,
                                isSelected: isSelected,
                                isMarked: isMarked,
                                isEditing: isEditingTags
                            ) {
                                if isEditingTags {
                                    guard isCustom else { return }
                                    if isMarked { tagsMarkedForDelete.remove(tag) }
                                    else { tagsMarkedForDelete.insert(tag) }
                                } else {
                                    if isSelected { selectedTags.remove(tag) }
                                    else { selectedTags.insert(tag) }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if isEditingTags {
                        HStack {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label(
                                    tagsMarkedForDelete.isEmpty
                                        ? "Remove"
                                        : "Remove (\(tagsMarkedForDelete.count))",
                                    systemImage: "trash"
                                )
                            }
                            .disabled(tagsMarkedForDelete.isEmpty)
                            Spacer()
                            Button("Done") {
                                isEditingTags = false
                                tagsMarkedForDelete.removeAll()
                            }
                        }
                    } else {
                        HStack {
                            TextField("Add custom tag...", text: $newTagText)
                                .textInputAutocapitalization(.words)
                                .onSubmit { addCustomTag() }
                            Button("Add") { addCustomTag() }
                                .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                } header: {
                    HStack {
                        Text("Tags (optional)")
                        Spacer()
                        if !customTags.isEmpty {
                            Button(isEditingTags ? "Done" : "Edit") {
                                isEditingTags.toggle()
                                if !isEditingTags { tagsMarkedForDelete.removeAll() }
                            }
                            .font(.caption)
                            .textCase(nil)
                        }
                    }
                }

                Section("Note (optional)") {
                    TextField("What happened?", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    HStack {
                        Text("Score for this moment")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(previewScore > 0 ? "+\(previewScore)" : "\(previewScore)")
                            .font(.title2.bold())
                            .foregroundStyle(previewScore > 0 ? .green : .orange)
                    }
                }
            }
            .navigationTitle("Log Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Remove \(tagsMarkedForDelete.count) tag\(tagsMarkedForDelete.count == 1 ? "" : "s")?",
                   isPresented: $showDeleteConfirm) {
                Button("Remove", role: .destructive) { commitBulkDelete() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("These tags will be hidden from the tag list. Past moments using them are not affected.")
            }
        }
    }

    private func save() {
        let moment = Moment(
            type: momentType,
            intensity: intensity,
            tags: Array(selectedTags),
            note: note
        )
        Task { await store.add(moment) }
        dismiss()
    }
}

struct ScoreScrollPicker: View {
    @Binding var intensity: Int
    let momentType: MomentType

    @State private var scrolledID: Int? = nil
    private var accentColor: Color { momentType == .excited ? .blue : .orange }

    var body: some View {
        VStack(spacing: 6) {
            Text(momentType == .excited ? "+\(intensity)" : "-\(intensity)")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(accentColor)
                .contentTransition(.numericText())
                .animation(.snappy, value: intensity)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(1...20, id: \.self) { value in
                        let selected = value == intensity
                        Text("\(value)")
                            .font(.system(size: selected ? 22 : 15,
                                          weight: selected ? .bold : .regular))
                            .foregroundStyle(selected ? accentColor : Color.secondary)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selected ? accentColor.opacity(0.12) : Color.clear)
                            )
                            .id(value)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledID)
            .contentMargins(.horizontal, 148, for: .scrollContent)
            .frame(height: 52)
            .onAppear { scrolledID = intensity }
            .onChange(of: scrolledID) { _, v in if let v { intensity = v } }
        }
        .padding(.vertical, 4)
    }
}

private struct TagChip: View {
    let tag: String
    let isCustom: Bool
    let isSelected: Bool
    let isMarked: Bool
    let isEditing: Bool
    let action: () -> Void

    private var background: Color {
        if isEditing {
            if isMarked { return Color.red.opacity(0.85) }
            if isCustom { return Color(.tertiarySystemBackground) }
            return Color(.tertiarySystemBackground).opacity(0.4)
        }
        return isSelected ? Color.accentColor : Color(.tertiarySystemBackground)
    }

    private var foreground: Color {
        if isEditing {
            if isMarked { return .white }
            return isCustom ? .primary : .secondary
        }
        return isSelected ? .white : .primary
    }

    private var borderColor: Color {
        (isEditing && isCustom && !isMarked) ? Color.red.opacity(0.6) : .clear
    }

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                .background(background)
                .foregroundStyle(foreground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(borderColor,
                                      style: StrokeStyle(lineWidth: 1, dash: [3]))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isEditing && !isCustom)
    }
}
