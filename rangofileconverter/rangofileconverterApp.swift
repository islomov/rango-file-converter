//
//  rangofileconverterApp.swift
//  rangofileconverter
//
//  Created by Sardor Islomov on 20/02/26.
//

import SwiftUI
import SwiftData

@main
struct rangofileconverterApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: ConversionRecord.self)
            let context = container.mainContext
            let descriptor = FetchDescriptor<ConversionRecord>()
            let count = try context.fetchCount(descriptor)
            print("[App] ModelContainer created successfully")
            print("[App] Store URL: \(container.configurations.first?.url.path() ?? "unknown")")
            print("[App] Existing records on launch: \(count)")
        } catch {
            print("[App] ModelContainer FAILED: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
