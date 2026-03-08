import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var selectedRecord: ConversionRecord?
    @State private var searchText: String = ""
    @State private var showFilterSheet = false
    @State private var filterState = HistoryFilterState()

    private let categories = ["image", "video", "audio", "document"]

    private var filteredRecords: [ConversionRecord] {
        var records = historyStore.records

        // Search filter
        if !searchText.isEmpty {
            records = records.filter {
                $0.sourceFileName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Category filter
        if !filterState.selectedCategories.isEmpty {
            records = records.filter {
                filterState.selectedCategories.contains($0.mediaCategory)
            }
        }

        // Tool type filter
        if !filterState.selectedToolTypes.isEmpty {
            records = records.filter {
                filterState.selectedToolTypes.contains($0.tool)
            }
        }

        // Status filter
        if !filterState.selectedStatuses.isEmpty {
            records = records.filter {
                filterState.selectedStatuses.contains($0.statusRaw)
            }
        }

        return records.sorted { $0.date > $1.date }
    }

    private var groupedRecords: [(category: String, records: [ConversionRecord])] {
        var groups: [(category: String, records: [ConversionRecord])] = []

        for category in categories {
            let categoryRecords = filteredRecords.filter { $0.mediaCategory == category }
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
                    .foregroundColor(AppColors.textPrimary)

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
                        .renderingMode(.template)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 24, height: 24)

                    TextField("Search", text: $searchText)
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(4)
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.border, lineWidth: 1)
                )

                Button {
                    showFilterSheet = true
                } label: {
                    Image("icon_filter")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 24, height: 24)
                        .frame(width: 48, height: 48)
                        .background(filterState.isActive ? AppColors.accent.opacity(0.12) : AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(filterState.isActive ? AppColors.accent : AppColors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            // Content
            if groupedRecords.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: filterState.isActive ? "line.3.horizontal.decrease.circle" : "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text(filterState.isActive ? "No matching results" : "No history yet")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundStyle(.secondary)
                    Text(filterState.isActive ? "Try adjusting your filters" : "Your conversions will appear here")
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
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
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .background(AppColors.background)
                            }
                        }

                        // Small bottom padding for visual breathing room
                        Color.clear
                            .frame(height: 16)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(AppColors.background)
        .sheet(item: $selectedRecord) { record in
            HistoryResultSheet(record: record)
        }
        .sheet(isPresented: $showFilterSheet) {
            HistoryFilterSheet(initialState: filterState) { applied in
                filterState = applied
            }
            .presentationDetents([.large])
        }
    }

}
