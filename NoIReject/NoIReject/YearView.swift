//
//  YearView.swift
//  NoIReject
//

import SwiftUI

struct YearView: View {
    @EnvironmentObject private var store: MomentStore
    @State private var displayedYear: Int = Calendar.current.component(.year, from: Date())

    private let calendar = Calendar.current
    private static let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    private var moments: [Moment] { store.moments }

    private func scoreFor(date: Date) -> Int? {
        let dayMoments = moments.filter { calendar.isDate($0.date, inSameDayAs: date) }
        guard !dayMoments.isEmpty else { return nil }
        return dayMoments.reduce(0) { $0 + $1.score }
    }

    private func heatColor(for score: Int) -> Color {
        if score < -20 { return Color(red: 0.85, green: 0.1, blue: 0.1) }
        if score <   0 { return Color.orange.opacity(0.8) }
        if score ==  0 { return Color.gray.opacity(0.4) }
        if score <  20 { return Color.green.opacity(0.5) }
        return Color(red: 0.1, green: 0.65, blue: 0.1)
    }

    private func datesForMonth(_ month: Int) -> [Date] {
        var components = DateComponents()
        components.year = displayedYear
        components.month = month
        components.day = 1
        guard
            let firstDay = calendar.date(from: components),
            let range = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
    }

    private func paddedDates(for month: Int) -> [Date?] {
        let dates = datesForMonth(month)
        guard let first = dates.first else { return [] }
        let offset = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: offset) + dates.map { Optional($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Button { displayedYear -= 1 } label: {
                            Image(systemName: "chevron.left").font(.title2)
                        }
                        Spacer()
                        Text(String(displayedYear)).font(.title2.bold())
                        Spacer()
                        Button { displayedYear += 1 } label: {
                            Image(systemName: "chevron.right").font(.title2)
                        }
                    }
                    .padding(.horizontal)

                    HStack(spacing: 6) {
                        Text("Low").font(.caption).foregroundStyle(.secondary)
                        ForEach([-40, -20, 0, 20, 40], id: \.self) { s in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(s == 0 ? Color.gray.opacity(0.35) : heatColor(for: s))
                                .frame(width: 14, height: 14)
                        }
                        Text("High").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    ForEach(Array(1...12), id: \.self) { month in
                        YearMonthStrip(
                            monthName: Self.monthNames[month - 1],
                            paddedDates: paddedDates(for: month),
                            scoreFor: scoreFor,
                            heatColor: heatColor
                        )
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Year")
        }
    }
}

struct YearMonthStrip: View {
    let monthName: String
    let paddedDates: [Date?]
    let scoreFor: (Date) -> Int?
    let heatColor: (Int) -> Color

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    private let calendar = Calendar.current

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(monthName)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(paddedDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let score = scoreFor(date)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(score != nil ? heatColor(score!) : Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if calendar.isDateInToday(date) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                                }
                            }
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
