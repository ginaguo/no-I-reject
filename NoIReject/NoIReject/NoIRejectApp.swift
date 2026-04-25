//
//  NoIRejectApp.swift
//  NoIReject
//

import SwiftUI

@main
struct NoIRejectApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var store: MomentStore
    @StateObject private var customTags: CustomTagsStore

    init() {
        let auth = AuthService()
        _auth = StateObject(wrappedValue: auth)
        _store = StateObject(wrappedValue: MomentStore(auth: auth))
        _customTags = StateObject(wrappedValue: CustomTagsStore(auth: auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(store)
                .environmentObject(customTags)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: MomentStore
    @EnvironmentObject private var customTags: CustomTagsStore

    var body: some View {
        Group {
            if auth.isLoggedIn {
                ContentView()
                    .task {
                        await store.reload()
                        await customTags.refresh()
                    }
            } else {
                LoginView()
            }
        }
        .onChange(of: auth.isLoggedIn) { _, loggedIn in
            if loggedIn {
                Task {
                    await store.reload()
                    await customTags.refresh()
                }
            } else {
                store.clear()
            }
        }
    }
}
