//
//  rangofileconverterApp.swift
//  rangofileconverter
//
//  Created by Sardor Islomov on 20/02/26.
//

import SwiftUI

@main
struct rangofileconverterApp: App {
    @StateObject private var historyStore = HistoryStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(historyStore)
        }
    }
}
