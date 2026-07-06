import SwiftUI
import StoreKit
import Combine
/// Ilovadagi YAGONA Obuna (paywall) sahifasi. Eski har xil joydagi kichik
/// "Premium kerak" popup/karta (`VipPaywallCard` va boshqalar) endi shu
/// sahifaga yo'naltiriladi — `PaywallGate.present()` chaqirilganda
/// `.fullScreenCover` orqali ochiladi (qarang MainTabView.swift va
/// ChatConversationView.swift).
///
/// To'lov: Apple StoreKit2 (`SubscriptionManager`) orqali xarid qilinadi,
/// natijada olingan imzolangan tranzaksiya (`signed_transaction`) backendga
/// yuborilib, Apple'ning rasmiy server kutubxonasi orqali TO'LIQ
/// server-tomonda tasdiqlanadi (mijozga ishonib qolinmaydi).
struct SubscriptionView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @StateObject private var vm = SubscriptionViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var purchasingPlanId: Int?

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if vm.isLoading && vm.plans.isEmpty {
                    Spacer()
                    ProgressView().tint(theme.primary)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            heroIcon

                            ForEach(vm.plans) { plan in
                                PlanCard(
                                    plan: plan,
                                    isCurrent: vm.isCurrentPlan(plan),
                                    priceText: vm.priceText(for: plan),
                                    isPurchasing: purchasingPlanId == plan.id,
                                    onSubscribe: { await subscribe(plan) }
                                )
                            }

                            restoreButton

                            Text(lang[.subTermsFooter])
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .task { vm.start() }
        .alert(
            lang[.subPurchaseFailedTitle],
            isPresented: Binding(
                get: { vm.errorText != nil },
                set: { if !$0 { vm.errorText = nil } }
            )
        ) {
            Button(lang[.done], role: .cancel) { vm.errorText = nil }
        } message: {
            Text(vm.errorText ?? "")
        }
        .onChange(of: vm.purchaseSucceeded) { _, success in
            if success {
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    vm.purchaseSucceeded = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(lang[.subNavTitle])
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var heroIcon: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [theme.primary.opacity(0.18), theme.primary.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 76, height: 76)
                Image(systemName: "crown.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.yellow)
            }
            Text(lang[.subHeaderSubtitle])
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var restoreButton: some View {
        Button {
            Task { await vm.restore() }
        } label: {
            HStack(spacing: 6) {
                if vm.isRestoring {
                    ProgressView().tint(theme.textSecondary).scaleEffect(0.8)
                }
                Text(vm.isRestoring ? lang[.subRestoring] : lang[.subRestoreButton])
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(theme.textSecondary)
        }
        .disabled(vm.isRestoring)
        .padding(.top, 8)
    }

    private func subscribe(_ plan: SubPlan) async {
        purchasingPlanId = plan.id
        await vm.subscribe(to: plan)
        purchasingPlanId = nil
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let plan: SubPlan
    let isCurrent: Bool
    let priceText: String
    let isPurchasing: Bool
    let onSubscribe: () async -> Void

    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    if isCurrent {
                        Text(lang[.subCurrentPlanLabel])
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.primary)
                    }
                }
                Spacer()
                if !plan.isFree {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(priceText)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                        if plan.isPurchasable {
                            Text(lang[.subPriceMonthlySuffix])
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.0) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: feature.0)
                            .font(.system(size: 13))
                            .foregroundColor(theme.primary)
                            .frame(width: 18)
                        Text(feature.1)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }

            if !plan.isFree {
                actionButton
            }
        }
        .padding(18)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isCurrent ? theme.primary.opacity(0.5) : Color.black.opacity(0.05), lineWidth: isCurrent ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var actionButton: some View {
        if isCurrent {
            Text(lang[.subCurrentPlanButton])
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if !plan.isPurchasable {
            Text(lang[.subComingSoon])
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Button {
                Task { await onSubscribe() }
            } label: {
                HStack(spacing: 6) {
                    if isPurchasing {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    }
                    Text(isPurchasing ? lang[.subPurchasing] : lang[.subSubscribeButton])
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(colors: [Color.red, theme.primary, Color.orange],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isPurchasing)
        }
    }

    /// Tarifning haqiqiy imkoniyatlarini ikon+matn juftliklariga aylantiradi —
    /// faqat mazmunli (true/0 dan katta) qiymatlar ko'rsatiladi.
    private var features: [(String, String)] {
        var rows: [(String, String)] = []

        if plan.likes_per_day < 0 {
            rows.append(("heart.fill", "\(lang[.subUnlimited]) \(lang[.subFeatureLikesPerDay])"))
        } else {
            rows.append(("heart.fill", "\(plan.likes_per_day) \(lang[.subFeatureLikesPerDay])"))
        }
        if plan.super_likes_per_day > 0 {
            rows.append(("star.fill", "\(plan.super_likes_per_day) \(lang[.subFeatureSuperLikes])"))
        }
        if plan.can_see_who_liked {
            rows.append(("eye.fill", lang[.subFeatureWhoLiked]))
        }
        if plan.can_use_radius_filter {
            rows.append(("location.circle.fill", lang[.subFeatureRadius]))
        }
        if plan.can_send_voice {
            rows.append(("mic.fill", lang[.subFeatureVoice]))
        }
        if plan.can_send_video_msg {
            rows.append(("video.fill", lang[.subFeatureVideo]))
        }
        if plan.can_boost_profile {
            rows.append(("bolt.fill", lang[.subFeatureBoost]))
        }
        if plan.can_see_story_analytics {
            rows.append(("chart.bar.fill", lang[.subFeatureStoryAnalytics]))
        }
        if plan.stories_per_day > 1 {
            rows.append(("circle.dashed", "\(plan.stories_per_day) \(lang[.subFeatureStoriesPerDay])"))
        }
        if plan.ad_free {
            rows.append(("rectangle.slash", lang[.subFeatureAdFree]))
        }
        rows.append(("clock.fill", "\(plan.chat_duration_days) \(lang[.subFeatureChatDuration])"))

        return rows
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
