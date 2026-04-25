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
    @State private var tagPendingDelete: String? = nil

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

                Section("Tags (optional)") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            let isCustom = !predefinedTags.contains(tag)
                            Button {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            } label: {
                                Text(tag)
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        selectedTags.contains(tag) ? Color.accentColor : Color(.tertiarySystemBackground)
                                    )
                                    .foregroundStyle(selectedTags.contains(tag) ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if isCustom {
                                    Button(role: .destructive) {
                                        tagPendingDelete = tag
                                    } label: {
                                        Label("Remove tag", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    if !customTags.isEmpty {
                        Text("Long-press a custom tag to remove it.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Add custom tag...", text: $newTagText)
                            .textInputAutocapitalization(.words)
                            .onSubmit { addCustomTag() }
                        Button("Add") { addCustomTag() }
                            .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
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
            .alert("Remove tag?",
                   isPresented: Binding(
                    get: { tagPendingDelete != nil },
                    set: { if !$0 { tagPendingDelete = nil } }
                   ),
                   presenting: tagPendingDelete) { tag in
                Button("Remove", role: .destructive) {
                    removeCustomTag(tag)
                    tagPendingDelete = nil
                }
                Button("Cancel", role: .cancel) { tagPendingDelete = nil }
            } message: { tag in
                Text("\"\(tag)\" will be hidden from the tag list. Past moments using this tag are not affected.")
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
