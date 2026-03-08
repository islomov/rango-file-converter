import SwiftUI

struct LanguagePickerSheet: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredLanguages: [AppLanguage] {
        if searchText.isEmpty {
            return LanguageManager.supportedLanguages
        }
        let query = searchText.lowercased()
        return LanguageManager.supportedLanguages.filter {
            $0.nativeName.lowercased().contains(query) ||
            $0.englishName.lowercased().contains(query) ||
            $0.code.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(AppColors.textSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Header
            HStack {
                Text("App language")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)

                TextField("Search", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.textSecondary.opacity(0.08))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Language list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredLanguages.enumerated()), id: \.element.id) { index, language in
                        languageRow(
                            language: language,
                            isSelected: language.code == languageManager.currentLanguageCode,
                            isLast: index == filteredLanguages.count - 1
                        )
                    }
                }
                .background(AppColors.surface)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(AppColors.background)
    }

    private func languageRow(language: AppLanguage, isSelected: Bool, isLast: Bool) -> some View {
        Button {
            languageManager.setLanguage(language.code)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.nativeName)
                        .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    if language.nativeName != language.englishName {
                        Text(language.englishName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 22, height: 22)
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.12))
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
