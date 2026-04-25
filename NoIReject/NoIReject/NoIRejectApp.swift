//
//  NoIRejectApp.swift
//  NoIReject
//

import SwiftUI

@main
struct NoIRejectApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var store: MomentStore

    init() {
        let auth = AuthService()
        _auth = StateObject(wrappedValue: auth)
        _store = StateObject(wrappedValue: MomentStore(auth: auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: MomentStore

    var body: some View {
        Group {
            if auth.isLoggedIn {
                ContentView()
                    .task { await store.reload() }
            } else {
                LoginView()
            }
        }
        .onChange(of: auth.isLoggedIn) { _, loggedIn in
            if loggedIn {
                Task { await store.reload() }
            } else {
                store.clear()
            }
        }
    }
}
