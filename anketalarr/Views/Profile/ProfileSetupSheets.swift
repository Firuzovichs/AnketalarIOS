import SwiftUI

// MARK: - Date Picker Sheet (creative wheel style)
struct DatePickerSheet: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @Binding var selection: Date
    @Environment(\.dismiss) private var dismiss

    private let maxDate = Calendar.current.date(byAdding: .year, value: -16, to: Date())!

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            HStack {
                Button { dismiss() } label: {
                    Text(lang[.cancel])
                        .font(.system(size: 16))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                Text(lang[.psBirthDate])
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Text(lang[.done])
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            DatePicker("", selection: $selection,
                       in: ...maxDate,
                       displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier:
                    lang.language == .ru ? "ru_RU" :
                    lang.language == .en ? "en_US" : "uz_UZ"))
        }
    }
}

// MARK: - Wheel Picker Sheet (bo'y / vazn)
struct WheelPickerSheet: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit:  String
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            HStack {
                Button { dismiss() } label: {
                    Text(lang[.cancel])
                        .font(.system(size: 16))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Text(lang[.done])
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            Picker("", selection: $value) {
                ForEach(range, id: \.self) { v in
                    Text("\(v) \(unit)")
                        .font(.system(size: 20))
                        .tag(v)
                }
            }
            .pickerStyle(.wheel)
            .padding(.bottom, 8)
        }
    }
}
