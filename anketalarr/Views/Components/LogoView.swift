import SwiftUI

// MARK: - Logo (rasm bo'lgunga qadar dasturiy versiya)
struct LogoView: View {
    var size: CGFloat = 220

    var body: some View {
        ZStack {
            // Qora doira
            Circle()
                .fill(Color(hex: "#1C1C1E"))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)

            VStack(spacing: 6) {
                // Yurak + qo'llar
                ZStack {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#E05C7A"), Color(hex: "#C0392B")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.52, height: size * 0.52)

                    // Qo'llar
                    HStack(spacing: -8) {
                        Image(systemName: "hand.point.right.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: size * 0.18)
                            .foregroundColor(Color(hex: "#F5CBA7"))
                            .rotationEffect(.degrees(15))
                            .offset(x: -4, y: 6)

                        Image(systemName: "hand.point.left.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: size * 0.18)
                            .foregroundColor(Color(hex: "#D4A574"))
                            .rotationEffect(.degrees(-15))
                            .offset(x: 4, y: 6)
                    }
                }

                // Nom
                Text("ANKETALAR.UZ")
                    .font(.system(size: size * 0.085, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.5)
            }
        }
    }
}

// Logo rasm asset mavjud bo'lsa shu view ishlatiladi
struct LogoImageView: View {
    var size: CGFloat = 220

    var body: some View {
        Group {
            if let _ = UIImage(named: "AppLogo") {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                LogoView(size: size)
            }
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "#FFF0F2")
        LogoView(size: 220)
    }
}
