//
//  RangoFileConverterApp.swift
//  RangoFileConverter
//
//  Created by Sardor Islomov on 20/02/26.
//

import SwiftUI

@main
struct RangoFileConverterApp: App {
    @StateObject private var historyStore = HistoryStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(historyStore)
        }
    }
}
