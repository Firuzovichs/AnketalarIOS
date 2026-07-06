import SwiftUI

// MARK: ─── 7. Yuz tekshiruvi ─────────────────────────────────────
struct ProfileFaceScanStep: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager

    @Binding var faceImage: UIImage?
    @Binding var showCamera: Bool
    @Binding var uploadingFace: Bool
    @Binding var faceUploaded: Bool
    var onUploadFace: (UIImage) -> Void
    var onFinish: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ProfileStepHeader(title: lang[.psFaceTitle], subtitle: lang[.psFaceSub])

            // Preview yoki placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.06), radius: 12)
                    .frame(height: 260)

                if let img = faceImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    // Uploaded badge
                    if faceUploaded {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.white)
                                Text("Tasdiqlandi")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.green.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(.bottom, 12)
                        }
                    }
                } else {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle().fill(theme.primaryLight).frame(width: 80, height: 80)
                            Image(systemName: "faceid")
                                .font(.system(size: 40))
                                .foregroundColor(theme.primary)
                        }
                        Text(lang[.psFaceSub])
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
            }

            if uploadingFace {
                HStack(spacing: 10) {
                    ProgressView().tint(theme.primary)
                    Text(lang[.psUploading]).foregroundColor(theme.textSecondary)
                }
            }

            // Rasmni qayta olish
            if faceImage != nil {
                Button { faceImage = nil; faceUploaded = false } label: {
                    Text(lang[.psRetake])
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.primary)
                }
            }

            // Rasm olish tugmasi
            if faceImage == nil {
                Button { showCamera = true } label: {
                    Text(lang[.psTakePhoto])
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

            // Yuklash tugmasi (rasm olindi, lekin yuklash kerak)
            if let img = faceImage, !faceUploaded {
                PrimaryButton(title: lang[.psFinish], isLoading: uploadingFace) {
                    onUploadFace(img)
                }
            }

            // Finish without face scan
            if faceUploaded {
                PrimaryButton(title: lang[.psFinish]) {
                    onFinish()
                }
            }

            ProfileSkipButton(action: onSkip)
        }
    }
}
