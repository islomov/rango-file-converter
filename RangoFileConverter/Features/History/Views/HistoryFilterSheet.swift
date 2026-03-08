import SwiftUI

struct HistoryFilterState: Equatable {
    var selectedCategories: Set<String> = []
    var selectedToolTypes: Set<ToolType> = []
    var selectedStatuses: Set<String> = []

    var isActive: Bool {
        !selectedCategories.isEmpty || !selectedToolTypes.isEmpty || !selectedStatuses.isEmpty
    }

    mutating func clearAll() {
        selectedCategories.removeAll()
        selectedToolTypes.removeAll()
        selectedStatuses.removeAll()
    }
}

struct HistoryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onApply: (HistoryFilterState) -> Void

    @State private var selectedCategories: Set<String>
    @State private var selectedToolTypes: Set<ToolType>
    @State private var selectedStatuses: Set<String>

    private let mediaCategories: [(id: String, label: String, icon: String)] = [
        ("image", "Image", "photo.fill"),
        ("video", "Video", "video.fill"),
        ("audio", "Audio", "music.note"),
        ("document", "Documents", "doc.fill"),
    ]

    private let statuses: [(id: String, label: String)] = [
        ("converted", "Done"),
        ("failed", "Failed"),
        ("converting", "Loading"),
        ("pending", "Pending"),
    ]

    init(initialState: HistoryFilterState, onApply: @escaping (HistoryFilterState) -> Void) {
        self.onApply = onApply
        self._selectedCategories = State(initialValue: initialState.selectedCategories)
        self._selectedToolTypes = State(initialValue: initialState.selectedToolTypes)
        self._selectedStatuses = State(initialValue: initialState.selectedStatuses)
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

            Text("Filtr")
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
                    isSelected: selectedCategories.isEmpty
                ) {
                    selectedCategories.removeAll()
                }

                ForEach(mediaCategories, id: \.id) { category in
                    let isSelected = selectedCategories.contains(category.id)
                    filterChip(
                        label: category.label,
                        icon: category.icon,
                        isSelected: isSelected
                    ) {
                        if isSelected {
                            selectedCategories.remove(category.id)
                        } else {
                            selectedCategories.insert(category.id)
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
                ForEach(ToolType.allCases, id: \.self) { tool in
                    let isSelected = selectedToolTypes.contains(tool)
                    filterChip(
                        label: tool.rawValue,
                        isSelected: isSelected
                    ) {
                        if isSelected {
                            selectedToolTypes.remove(tool)
                        } else {
                            selectedToolTypes.insert(tool)
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
                ForEach(statuses, id: \.id) { status in
                    let isSelected = selectedStatuses.contains(status.id)
                    filterChip(
                        label: status.label,
                        isSelected: isSelected
                    ) {
                        if isSelected {
                            selectedStatuses.remove(status.id)
                        } else {
                            selectedStatuses.insert(status.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Filter Chip

    @ViewBuilder
    private func filterChip(
        label: String,
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
                    selectedCategories.removeAll()
                    selectedToolTypes.removeAll()
                    selectedStatuses.removeAll()
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
                        selectedCategories: selectedCategories,
                        selectedToolTypes: selectedToolTypes,
                        selectedStatuses: selectedStatuses
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
