import SwiftUI

/// Profil ekranidagi asosiy rasmga (avatar) bosilganda ochiladigan to'liq
/// ekran rasm ko'ruvchi. `ChatMediaViewerView`dagi TabView+page-style sahifa
/// almashtirish naqshiga o'xshash — chap/o'ngga surib foydalanuvchining
/// boshqa rasmlari bo'ylab ham o'tish mumkin.
struct ProfilePhotoViewerView: View {
    let photos: [DashPhoto]
    let startIndex: Int
    var onClose: () -> Void

    @State private var currentIndex: Int

    init(photos: [DashPhoto], startIndex: Int, onClose: @escaping () -> Void) {
        self.photos = photos
        self.startIndex = startIndex
        self.onClose = onClose
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { idx, photo in
                    photoPage(photo).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            .ignoresSafeArea()

            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .padding(.top, 54)
            .padding(.trailing, 16)
        }
        .statusBarHidden()
    }

    @ViewBuilder
    private func photoPage(_ photo: DashPhoto) -> some View {
        if let url = photo.photoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.7))
                default:
                    ProgressView().tint(.white)
                }
            }
        } else {
            Color.black
        }
    }
}
