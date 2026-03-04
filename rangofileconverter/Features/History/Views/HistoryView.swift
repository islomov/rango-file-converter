import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var selectedRecord: ConversionRecord?
    @State private var searchText: String = ""

    private let categories = ["image", "video", "audio", "document"]

    private var groupedRecords: [(category: String, records: [ConversionRecord])] {
        let allRecords: [ConversionRecord]
        if searchText.isEmpty {
            allRecords = historyStore.records
        } else {
            allRecords = historyStore.records.filter {
                $0.sourceFileName.localizedCaseInsensitiveContains(searchText)
            }
        }

        let sorted = allRecords.sorted { $0.date > $1.date }
        var groups: [(category: String, records: [ConversionRecord])] = []

        for category in categories {
            let categoryRecords = sorted.filter { $0.mediaCategory == category }
            if !categoryRecords.isEmpty {
                groups.append((category: category, records: categoryRecords))
            }
        }
        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("My converts")
                    .font(.custom("Montserrat-Bold", size: 28))
                    .foregroundColor(Color(hex: "1D1D1D"))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)

            // Search bar + filter
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image("icon_search")
                        .resizable()
                        .frame(width: 24, height: 24)

                    TextField("Search", text: $searchText)
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundColor(Color(hex: "1D1D1D"))
                }
                .padding(4)
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    // Filter action placeholder
                } label: {
                    Image("icon_filter")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .frame(width: 48, height: 48)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            // Content
            if groupedRecords.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No history yet")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundStyle(.secondary)
                    Text("Your conversions will appear here")
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedRecords, id: \.category) { group in
                            Section {
                                ForEach(group.records) { record in
                                    Button {
                                        selectedRecord = record
                                    } label: {
                                        HistoryRowView(record: record)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text(group.category.capitalized)
                                    .font(.custom("Montserrat-SemiBold", size: 20))
                                    .foregroundColor(Color(hex: "1D1D1D"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "F2F2F6"))
                            }
                        }

                        // Spacer for floating tab bar
                        Color.clear
                            .frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(Color(hex: "F2F2F6"))
        .sheet(item: $selectedRecord) { record in
            HistoryResultSheet(record: record)
        }
    }

}
