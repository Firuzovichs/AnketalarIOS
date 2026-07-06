import SwiftUI
import PhotosUI

// MARK: ─── 5. Rasmlar ───────────────────────────────────────────
struct ProfilePhotosStep: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @ObservedObject var vm: AuthViewModel

    @Binding var pickerItems: [PhotosPickerItem]
    @Binding var selectedImages: [UIImage]
    @Binding var uploadingPhotos: Bool
    var onUpload: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ProfileStepHeader(title: lang[.psStep5], subtitle: lang[.psMinPhoto])

            // Grid preview
            if !selectedImages.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 10) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, img in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 14))

                            Button {
                                selectedImages.remove(at: idx)
                                if idx < pickerItems.count { pickerItems.remove(at: idx) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .shadow(radius: 3)
                            }
                            .padding(4)
                        }
                    }
                }
            }

            PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: selectedImages.isEmpty ? "camera.fill" : "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.primary)
                    Text(lang[.psAddPhoto])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.primary.opacity(0.3), lineWidth: 1.5)
                )
            }

            PrimaryButton(title: lang[.psContinue], isLoading: uploadingPhotos) {
                guard !selectedImages.isEmpty else {
                    vm.errorMessage = lang[.psMinPhoto]; return
                }
                onUpload()
            }

            ProfileSkipButton(action: onSkip)
        }
    }
}
