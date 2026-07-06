import SwiftUI

// MARK: - Bosqich sarlavhasi (barcha bosqichlarda ishlatiladi)
struct ProfileStepHeader: View {
    @EnvironmentObject var theme: AppTheme
    let title: String
    var subtitle: String = ""

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - "O'tkazib yuborish" tugmasi (bir nechta bosqichda ishlatiladi)
struct ProfileSkipButton: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(lang[.psSkip])
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
        }
    }
}

// MARK: - Qiziqish/Maqsad chiplari grid (Interests va Goals bosqichlarida ishlatiladi)
struct ChipGrid: View {
    @EnvironmentObject var theme: AppTheme
    let items: [(Int, String, String)]
    @Binding var selected: Set<Int>

    var body: some View {
        FlowLayout(spacing: 10) {
            ForEach(items, id: \.0) { id, name, icon in
                let isSelected = selected.contains(id)
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        if isSelected { selected.remove(id) }
                        else          { selected.insert(id) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if !icon.isEmpty { Text(icon).font(.system(size: 16)) }
                        Text(name)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundColor(isSelected ? .white : theme.primary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(isSelected ? theme.primary : theme.primaryLight)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(theme.primary.opacity(isSelected ? 0 : 0.3), lineWidth: 1))
                }
            }
        }
    }
}
