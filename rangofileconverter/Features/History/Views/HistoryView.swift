import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var selectedCategory: String?
    @State private var selectedRecord: ConversionRecord?

    private var filteredRecords: [ConversionRecord] {
        let records: [ConversionRecord]
        if let category = selectedCategory {
            records = historyStore.records(for: category)
        } else {
            records = historyStore.records
        }
        return records.sorted { $0.date > $1.date }
    }

    private let categories = ["image", "video", "audio", "document"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }

                        ForEach(categories, id: \.self) { category in
                            FilterChip(title: category.capitalized, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if filteredRecords.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No history yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Your conversions will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredRecords) { record in
                            Button {
                                selectedRecord = record
                            } label: {
                                HistoryRowView(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                historyStore.remove(filteredRecords[index])
                            }
                        }

                        // Spacer for floating tab bar
                        Color.clear
                            .frame(height: 80)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .sheet(item: $selectedRecord) { record in
                HistoryResultSheet(record: record)
            }
        }
        .background(Color(hex: "F2F2F6"))
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : Color(hex: "1D1D1D"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "1D1D1D") : Color.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
