//
//  CalendarView.swift
//  NoIReject
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: MomentStore
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDay: SelectedDay?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var moments: [Moment] { store.moments }

    private var weekdayHeaders: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var daysInMonth: [Date?] {
        guard
            let range = calendar.range(of: .day, in: .month, for: displayedMonth),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let firstWeekday = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for i in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: i, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func scoreFor(date: Date) -> Int? {
        let dayMoments = moments.filter { calendar.isDate($0.date, inSameDayAs: date) }
        guard !dayMoments.isEmpty else { return nil }
        return dayMoments.reduce(0) { $0 + $1.score }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.left").font(.title2).padding(8)
                    }
                    Spacer()
                    Text(displayedMonth, format: .dateTime.year().month(.wide))
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.right").font(.title2).padding(8)
                    }
                }
                .padding(.horizontal, 12).padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(weekdayHeaders, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12).padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                        if let date {
                            Button { selectedDay = SelectedDay(date: date) } label: {
                                CalendarDayCell(date: date, score: scoreFor(date: date))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.top, 4)

                Spacer()
            }
            .navigationTitle("Calendar")
        }
        .sheet(item: $selectedDay) { item in
            DayDetailSheet(date: item.date, moments: momentsFor(date: item.date))
        }
    }

    private func momentsFor(date: Date) -> [Moment] {
        moments.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }
}

struct SelectedDay: Identifiable {
    let id = UUID()
    let date: Date
}

struct DayDetailSheet: View {
    let date: Date
    let moments: [Moment]
    @Environment(\.dismiss) private var dismiss

    private var totalScore: Int { moments.reduce(0) { $0 + $1.score } }

    var body: some View {
        NavigationStack {
            Group {
                if moments.isEmpty {
                    ContentUnavailableView("No moments", systemImage: "moon.stars",
                                          description: Text("Nothing logged on this day."))
                } else {
                    List {
                        Section {
                            HStack {
                                Text(dailyEmoji(for: totalScore)).font(.largeTitle)
                                Spacer()
                                Text(totalScore > 0 ? "Score: +\(totalScore)" : "Score: \(totalScore)")
                                    .font(.title3.bold())
                                    .foregroundStyle(totalScore > 0 ? .green : totalScore < 0 ? .orange : .primary)
                            }
                            .padding(.vertical, 4)
                        }
                        Section("Moments") {
                            ForEach(moments) { moment in
                                MomentRow(moment: moment)
                            }
                        }
                    }
                }
            }
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let score: Int?

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isToday ? Color.accentColor : Color.clear)
                    .frame(width: 28, height: 28)
                Text(date, format: .dateTime.day())
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : .primary)
            }
            if let score {
                Text(dailyEmoji(for: score))
                    .font(.system(size: 16))
            } else {
                Color.clear.frame(height: 20)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
