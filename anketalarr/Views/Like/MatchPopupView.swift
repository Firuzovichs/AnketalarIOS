import SwiftUI

/// Ikki tomon ham bir-birini like bosganda (mutual swipe) to'liq ekranli "Match!" popup.
struct MatchPopupView: View {
    let user: DashUser
    var onContinue: () -> Void

    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            VStack(spacing: 22) {
                Text("🎉")
                    .font(.system(size: 48))

                Text(lang[.likeMatchTitle])
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                avatar

                Text(String(format: lang[.likeMatchSub], user.displayName))
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Button(action: onContinue) {
                    Text(lang[.likeContinue])
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(colors: [Color.red, theme.primary, Color.orange],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 40)
                .padding(.top, 6)
            }
            .padding(.vertical, 40)
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(theme.primaryLight)
                .frame(width: 124, height: 124)
            AsyncImage(url: user.photoURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(theme.primary.opacity(0.4))
                }
            }
            .frame(width: 114, height: 114)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
        }
    }
}

#Preview {
    let user = DashUser(
        id: 1,
        profile: DashProfile(
            first_name: "Laylo", last_name: "Karimova", patronymic: nil, birth_date: nil,
            age: 24, gender: "female", bio: nil, height: 165, weight: 55,
            interests: nil, goals: nil, latitude: nil, longitude: nil, district: nil
        ),
        main_photo: nil, photos: nil, subscription_type: nil, is_online: true, last_seen: nil
    )
    MatchPopupView(user: user, onContinue: {})
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
