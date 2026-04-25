//
//  TodayView.swift
//  NoIReject
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: MomentStore
    @State private var showingAddSheet = false
    @State private var showingSignOutConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var todayMoments: [Moment] {
        store.moments.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayScore: Int {
        todayMoments.reduce(0) { $0 + $1.score }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Score card
                VStack(spacing: 6) {
                    Text(todayMoments.isEmpty ? "✨" : dailyEmoji(for: todayScore))
                        .font(.system(size: 56))
                    Text(todayMoments.isEmpty
                         ? "No moments logged yet"
                         : "Score: \(todayScore > 0 ? "+" : "")\(todayScore)")
                        .font(.title3.bold())
                        .foregroundStyle(todayMoments.isEmpty ? .secondary : scoreColor(todayScore))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemBackground))

                // Moments list
                List {
                    if todayMoments.isEmpty {
                        ContentUnavailableView(
                            "Log your first moment",
                            systemImage: "sparkles",
                            description: Text("Tap + to record something uncomfortable or exciting.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(todayMoments) { moment in
                            MomentRow(moment: moment)
                        }
                        .onDelete { offsets in
                            let toDelete = offsets.map { todayMoments[$0] }
                            Task {
                                for m in toDelete { await store.delete(m) }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await store.reload() }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        if let email = auth.email {
                            Text(email)
                        }
                        Link("Privacy Policy",
                             destination: URL(string: "https://zguo66-stoxx.github.io/no-I-reject/privacy.html")!)
                        Link("Contact",
                             destination: URL(string: "https://zguo66-stoxx.github.io/no-I-reject/contact.html")!)
                        Button("Sign Out", role: .destructive) {
                            // Defer so the menu fully dismisses before the dialog appears.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showingSignOutConfirm = true
                            }
                        }
                        Button("Delete Account", role: .destructive) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showingDeleteConfirm = true
                            }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddMomentView()
            }
            .confirmationDialog("Sign out?",
                                isPresented: $showingSignOutConfirm,
                                titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete your account?",
                                isPresented: $showingDeleteConfirm,
                                titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        isDeleting = true
                        defer { isDeleting = false }
                        do {
                            try await auth.deleteAccount()
                        } catch {
                            deleteError = error.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your account and all your moments, tags, and goals. This cannot be undone.")
            }
            .alert("Could not delete account",
                   isPresented: Binding(get: { deleteError != nil },
                                        set: { if !$0 { deleteError = nil } })) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
            .overlay(alignment: .top) {
                if let err = store.lastError {
                    Text(err)
                        .font(.caption)
                        .padding(8)
                        .background(Color.red.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.top, 4)
                        .onTapGesture { store.lastError = nil }
                }
            }
        }
    }
}

private func scoreColor(_ score: Int) -> Color {
    if score > 10 { return .green }
    if score < -10 { return .red }
    return .primary
}

struct MomentRow: View {
    let moment: Moment

    var body: some View {
        HStack(spacing: 12) {
            Text(moment.type == .excited ? "🚀" : "😤")
                .font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(moment.type == .excited ? "Excited" : "Uncomfortable")
                        .font(.headline)
                    Spacer()
                    Text(moment.score > 0 ? "+\(moment.score)" : "\(moment.score)")
                        .font(.headline.bold())
                        .foregroundStyle(moment.score > 0 ? .green : .orange)
                }
                if !moment.tags.isEmpty {
                    Text(moment.tags.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !moment.note.isEmpty {
                    Text(moment.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
