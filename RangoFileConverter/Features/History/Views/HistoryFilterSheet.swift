import SwiftUI

// Each filter feature has a unique integer ID for language-independent filtering.
// Categories: 1–4, Tool types: 100–116, Statuses: 200–203.
struct FilterFeature: Identifiable, Equatable {
    let id: Int
    let label: LocalizedStringKey
    let icon: String?
    let value: String // raw value for matching against ConversionRecord fields
}

enum FilterFeatures {
    static let categories: [FilterFeature] = [
        FilterFeature(id: 1, label: "Image", icon: "photo.fill", value: "image"),
        FilterFeature(id: 2, label: "Video", icon: "video.fill", value: "video"),
        FilterFeature(id: 3, label: "Audio", icon: "music.note", value: "audio"),
        FilterFeature(id: 4, label: "Documents", icon: "doc.fill", value: "document"),
    ]

    static let statuses: [FilterFeature] = [
        FilterFeature(id: 200, label: "Done", icon: nil, value: "converted"),
        FilterFeature(id: 201, label: "Failed", icon: nil, value: "failed"),
        FilterFeature(id: 202, label: "Loading", icon: nil, value: "converting"),
        FilterFeature(id: 203, label: "Pending", icon: nil, value: "pending"),
    ]

    static let toolTypes: [FilterFeature] = ToolType.allCases.map { tool in
        FilterFeature(id: tool.filterID, label: LocalizedStringKey(tool.rawValue), icon: nil, value: tool.rawValue)
    }

    static func categoryValues(for ids: Set<Int>) -> Set<String> {
        Set(categories.filter { ids.contains($0.id) }.map(\.value))
    }

    static func statusValues(for ids: Set<Int>) -> Set<String> {
        Set(statuses.filter { ids.contains($0.id) }.map(\.value))
    }

    static func toolTypeValues(for ids: Set<Int>) -> Set<ToolType> {
        Set(ids.compactMap { ToolType.fromFilterID($0) })
    }
}

struct HistoryFilterState: Equatable {
    var selectedCategoryIDs: Set<Int> = []
    var selectedToolTypeIDs: Set<Int> = []
    var selectedStatusIDs: Set<Int> = []

    var isActive: Bool {
        !selectedCategoryIDs.isEmpty || !selectedToolTypeIDs.isEmpty || !selectedStatusIDs.isEmpty
    }

    mutating func clearAll() {
        selectedCategoryIDs.removeAll()
        selectedToolTypeIDs.removeAll()
        selectedStatusIDs.removeAll()
    }
}

struct HistoryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onApply: (HistoryFilterState) -> Void

    @State private var selectedCategoryIDs: Set<Int>
    @State private var selectedToolTypeIDs: Set<Int>
    @State private var selectedStatusIDs: Set<Int>

    init(initialState: HistoryFilterState, onApply: @escaping (HistoryFilterState) -> Void) {
        self.onApply = onApply
        self._selectedCategoryIDs = State(initialValue: initialState.selectedCategoryIDs)
        self._selectedToolTypeIDs = State(initialValue: initialState.selectedToolTypeIDs)
        self._selectedStatusIDs = State(initialValue: initialState.selectedStatusIDs)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Grab handle
            Capsule()
                .fill(Color(.quaternaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            // Header
            header
                .padding(.horizontal, 8)
                .padding(.top, 8)

            // Filter sections
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    categorySection
                    typeSection
                    statusSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            Spacer()

            // Bottom buttons
            bottomButtons
        }
        .background(AppColors.surface)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Color.clear
                .frame(width: 40, height: 40)

            Spacer()

            Text("Filter")
                .font(.custom("Montserrat-SemiBold", size: 20))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.textSecondary.opacity(0.08))
                        .frame(width: 40, height: 40)

                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
    }

    // MARK: - Category Section (Show only)

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Show only")
                .font(.custom("Montserrat-SemiBold", size: 14))
                .foregroundColor(AppColors.textSecondary)

            FlowLayout(spacing: 8) {
                // "All" chip
                filterChip(
                    label: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategoryIDs.isEmpty
                ) {
                    selectedCategoryIDs.removeAll()
                }

                ForEach(FilterFeatures.categories) { category in
                    let isSelected = selectedCategoryIDs.contains(category.id)
                    filterChip(
                        label: category.label,
                        icon: category.icon,
                        isSelected: isSelected
                    ) {
                        if isSelected {
                            selectedCategoryIDs.remove(category.id)
                        } else {
                            selectedCategoryIDs.insert(category.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(.custom("Montserrat-SemiBold", size: 14))
                .foregroundColor(AppColors.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(FilterFeatures.toolTypes) { tool in
                    let isSelected = selectedToolTypeIDs.contains(tool.id)
                    filterChip(
                        label: tool.label,
                        isSelected: isSelected
                    ) {
                        if isSelected {
                            selectedToolTypeIDs.remove(tool.id)
                        } else {
                            selectedToolTypeIDs.insert(tool.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.custom("Montserrat-SemiBold", size: 14))
                .foregroundColor(AppColors.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(FilterFeatures.statuses) { status in
                    let isSelected = selectedStatusIDs.contains(status.id)
                    filterChip(
                        label: status.label,
                        isSelected: isSelected
                    ) {
                        if isSelected {
                            selectedStatusIDs.remove(status.id)
                        } else {
                            selectedStatusIDs.insert(status.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Filter Chip

    @ViewBuilder
    private func filterChip(
        label: LocalizedStringKey,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.3))
                        .clipShape(Circle())
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 20, height: 20)
                }

                Text(label)
                    .font(.custom("Montserrat-SemiBold", size: 14))
                    .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            }
            .padding(12)
            .background(
                isSelected
                    ? AnyView(AppColors.accent)
                    : AnyView(AppColors.textSecondary.opacity(0.08))
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    selectedCategoryIDs.removeAll()
                    selectedToolTypeIDs.removeAll()
                    selectedStatusIDs.removeAll()
                } label: {
                    Text("Clear all")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(AppColors.destructive)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(AppColors.textSecondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button {
                    let result = HistoryFilterState(
                        selectedCategoryIDs: selectedCategoryIDs,
                        selectedToolTypeIDs: selectedToolTypeIDs,
                        selectedStatusIDs: selectedStatusIDs
                    )
                    onApply(result)
                    dismiss()
                } label: {
                    Text("Apply")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return LayoutResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + rowHeight)
        )
    }
}
