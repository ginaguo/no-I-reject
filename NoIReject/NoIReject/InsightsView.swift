//
//  InsightsView.swift
//  NoIReject
//

import SwiftUI

// MARK: - Focus storage (per-user, local)

struct UserFocus: Codable, Equatable {
    var goals: String = ""
    var helpers: String = ""
    var updatedAt: Date? = nil
}

@MainActor
final class FocusStore: ObservableObject {
    @Published var focus: UserFocus = .init()
    private var userId: String?

    func load(for userId: String?) {
        self.userId = userId
        guard let key = key(for: userId),
              let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(UserFocus.self, from: data) else {
            focus = .init()
            return
        }
        focus = decoded
    }

    func save(_ value: UserFocus) {
        var v = value
        v.updatedAt = Date()
        focus = v
        guard let key = key(for: userId),
              let data = try? JSONEncoder().encode(v) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func key(for userId: String?) -> String? {
        guard let userId else { return nil }
        return "noireject.focus.\(userId)"
    }
}

// MARK: - InsightsView

struct InsightsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: MomentStore
    @StateObject private var focusStore = FocusStore()
    @State private var showingFocusEditor = false

    private var moments: [Moment] { store.moments }

    struct TagStat: Identifiable {
        var id: String { tag }
        let tag: String
        let totalScore: Int
        let count: Int
        var avgScore: Double { Double(totalScore) / Double(count) }
    }

    private var tagStats: [TagStat] {
        var dict: [String: (score: Int, count: Int)] = [:]
        for moment in moments {
            for tag in moment.tags {
                let existing = dict[tag] ?? (0, 0)
                dict[tag] = (existing.score + moment.score, existing.count + 1)
            }
        }
        return dict.map { TagStat(tag: $0.key, totalScore: $0.value.score, count: $0.value.count) }
            .sorted { $0.avgScore > $1.avgScore }
    }

    private var positiveTags: [TagStat] {
        tagStats.filter { $0.avgScore > 0 }
    }

    private var negativeTags: [TagStat] {
        tagStats.filter { $0.avgScore <= 0 }.sorted { $0.avgScore < $1.avgScore }
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        var date = cal.startOfDay(for: Date())
        var count = 0
        for _ in 0..<365 {
            let dayScore = moments
                .filter { cal.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.score }
            if dayScore > 0 {
                count += 1
            } else {
                break
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return count
    }

    private var loggedDays: Int {
        Set(moments.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private var overallEmoji: String {
        guard !moments.isEmpty else { return "✨" }
        let total = moments.reduce(0) { $0 + $1.score }
        return dailyEmoji(for: total / max(loggedDays, 1))
    }

    var body: some View {
        NavigationStack {
            List {
                // My Focus (goals & helpers)
                Section {
                    FocusCard(focus: focusStore.focus) {
                        showingFocusEditor = true
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack(spacing: 8) {
                        InsightCard(value: "\(moments.count)", label: "Moments", color: .blue)
                        InsightCard(value: "\(loggedDays)", label: "Days", color: .purple)
                        InsightCard(value: "\(currentStreak)🔥", label: "Streak", color: .orange)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                if tagStats.isEmpty {
                    ContentUnavailableView(
                        "No insights yet",
                        systemImage: "lightbulb",
                        description: Text("Log moments with tags to discover what drives you.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section("Your overall vibe") {
                        HStack {
                            Text(overallEmoji).font(.largeTitle)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Average daily score")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                let avg = moments.isEmpty ? 0 : moments.reduce(0) { $0 + $1.score } / max(loggedDays, 1)
                                Text(avg > 0 ? "+\(avg)" : "\(avg)")
                                    .font(.title2.bold())
                                    .foregroundStyle(avg > 0 ? .green : avg < 0 ? .orange : .primary)
                            }
                        }
                    }

                    if !positiveTags.isEmpty {
                        Section("What makes you happy 😊") {
                            ForEach(Array(positiveTags.prefix(5))) { stat in
                                TagStatRow(stat: stat)
                            }
                        }
                    }

                    if !negativeTags.isEmpty {
                        Section("What drains you 😔") {
                            ForEach(Array(negativeTags.prefix(5))) { stat in
                                TagStatRow(stat: stat)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Insights")
        }
        .onAppear { focusStore.load(for: auth.userId) }
        .onChange(of: auth.userId) { _, newID in focusStore.load(for: newID) }
        .sheet(isPresented: $showingFocusEditor) {
            FocusEditorView(initial: focusStore.focus) { updated in
                focusStore.save(updated)
            }
        }
    }
}

// MARK: - Focus card

struct FocusCard: View {
    let focus: UserFocus
    let onEdit: () -> Void

    private var goals: [String] {
        focus.goals.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var helpers: [String] {
        focus.helpers.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var isEmpty: Bool { goals.isEmpty && helpers.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📍 My Focus")
                    .font(.headline)
                Spacer()
                Button(action: onEdit) {
                    Text(isEmpty ? "+ Add" : "Edit")
                        .font(.subheadline.weight(.semibold))
                }
            }

            FocusSection(title: "🎯 Goals", items: goals)
            FocusSection(title: "💚 What Helps Me", items: helpers)

            if let updated = focus.updatedAt {
                Text("Updated \(updated.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct FocusSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text("Nothing set yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(.secondary)
                        Text(item).font(.subheadline)
                    }
                }
            }
        }
    }
}

// MARK: - Focus editor

struct FocusEditorView: View {
    let initial: UserFocus
    let onSave: (UserFocus) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var goals: String = ""
    @State private var helpers: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Run a 5k by June\nRead 2 books this month\nBe more present with family",
                              text: $goals, axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    Text("🎯 Goals")
                } footer: {
                    Text("One goal per line — update whenever things change.")
                }

                Section {
                    TextField("e.g. Morning walk\nCall a friend\nCooking something new",
                              text: $helpers, axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    Text("💚 What Helps Me")
                } footer: {
                    Text("Things that lift your mood when you're struggling.")
                }
            }
            .navigationTitle("My Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(UserFocus(goals: goals.trimmingCharacters(in: .whitespacesAndNewlines),
                                         helpers: helpers.trimmingCharacters(in: .whitespacesAndNewlines)))
                        dismiss()
                    }
                }
            }
            .onAppear {
                goals = initial.goals
                helpers = initial.helpers
            }
        }
    }
}

// MARK: - Stat cards

struct InsightCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TagStatRow: View {
    let stat: InsightsView.TagStat

    var body: some View {
        HStack {
            Text(stat.tag)
                .font(.headline)
            Spacer()
            Text("\(stat.count)×")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(stat.avgScore >= 0
                 ? String(format: "+%.0f avg", stat.avgScore)
                 : String(format: "%.0f avg", stat.avgScore))
                .font(.subheadline.bold())
                .foregroundStyle(stat.avgScore >= 0 ? .green : .orange)
                .frame(width: 72, alignment: .trailing)
        }
    }
}
