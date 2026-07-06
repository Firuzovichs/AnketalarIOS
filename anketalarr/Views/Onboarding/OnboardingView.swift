import SwiftUI

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @State private var currentIndex = 0
    @State private var logoScale:   CGFloat = 0.7
    @State private var logoOpacity: Double  = 0
    @State private var textOffset:  CGFloat = 30
    @State private var textOpacity: Double  = 0

    var onFinish: () -> Void

    private var pages: [(title: String, subtitle: String)] {
        [
            (lang[.onb1Title], lang[.onb1Sub]),
            (lang[.onb2Title], lang[.onb2Sub]),
            (lang[.onb3Title], lang[.onb3Sub]),
        ]
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack {
                TabView(selection: $currentIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageContent(title: page.title, subtitle: page.subtitle)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentIndex)
                .onChange(of: currentIndex) { _, _ in animateText() }

                HStack {
                    dotsView
                    Spacer()
                    nextButton
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
        .onAppear { animateAppear() }
    }

    private func pageContent(title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            Spacer()
            LogoImageView(size: 220)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
            Spacer().frame(height: 48)
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 28)
                Text(subtitle)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(theme.textSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 36)
            }
            .offset(y: textOffset)
            .opacity(textOpacity)
            Spacer()
            Spacer()
        }
    }

    private var dotsView: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Circle()
                    .fill(i == currentIndex ? theme.primary : theme.primary.opacity(0.25))
                    .frame(width: i == currentIndex ? 10 : 7,
                           height: i == currentIndex ? 10 : 7)
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
    }

    private var nextButton: some View {
        let isLast = currentIndex == pages.count - 1
        return Button {
            withAnimation(.spring(response: 0.4)) {
                if isLast { onFinish() }
                else { currentIndex += 1 }
            }
        } label: {
            Text(isLast ? lang[.start] : lang[.next])
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.primary)
        }
    }

    private func animateAppear() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
            logoScale = 1; logoOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            textOffset = 0; textOpacity = 1
        }
    }

    private func animateText() {
        textOffset = 20; textOpacity = 0
        withAnimation(.easeOut(duration: 0.4)) {
            textOffset = 0; textOpacity = 1
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
