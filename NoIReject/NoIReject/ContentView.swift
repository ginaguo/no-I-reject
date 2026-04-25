//
//  ContentView.swift
//  NoIReject
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: MomentStore

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            YearView()
                .tabItem { Label("Year", systemImage: "chart.bar.fill") }
            InsightsView()
                .tabItem { Label("Insights", systemImage: "lightbulb.fill") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(MomentStore(auth: AuthService()))
}
