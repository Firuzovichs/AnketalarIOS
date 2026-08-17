import SwiftUI
import CoreLocation

// MARK: ─── 6. Joylashuv ─────────────────────────────────────────
struct ProfileLocationStep: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @ObservedObject var loc: LocationManager

    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ProfileStepHeader(title: lang[.psLocTitle], subtitle: lang[.psLocSub])

            // Joylashuv kartasi
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            loc.location != nil
                            ? Color.green.opacity(0.12)
                            : theme.primaryLight
                        )
                        .frame(width: 100, height: 100)

                    if loc.isLoading {
                        ProgressView()
                            .tint(theme.primary)
                            .scaleEffect(1.5)
                    } else {
                        Image(systemName: loc.location != nil ? "location.fill" : "location")
                            .font(.system(size: 44))
                            .foregroundColor(loc.location != nil ? .green : theme.primary)
                    }
                }

                if let location = loc.location {
                    VStack(spacing: 4) {
                        Text(lang[.psLocDetected])
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                        Text(String(format: "%.4f°, %.4f°",
                                    location.coordinate.latitude,
                                    location.coordinate.longitude))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                    }
                } else if loc.denied {
                    Text("Ruxsat berilmadi. Sozlamalardan joylashuvni yoqing.")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.05), radius: 10)

            if loc.location == nil {
                Button { loc.requestLocation() } label: {
                    Text(lang[.psDetectLoc])
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [theme.primary, theme.primary.opacity(0.8)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            if loc.location != nil {
                PrimaryButton(title: lang[.psContinue]) { onContinue() }
            }

        }
    }
}
