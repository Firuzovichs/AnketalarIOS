import SwiftUI

struct DashNewsRow: View {
    let news: DashNews
    let onTap: () -> Void

    @EnvironmentObject var theme: AppTheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                newsImage
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(news.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(2)
                    Text(news.description)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                    if !news.formattedDate.isEmpty {
                        Text(news.formattedDate)
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary.opacity(0.55))
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary.opacity(0.4))
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var newsImage: some View {
        if let url = news.imageURL {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else {
                    fallbackImg
                }
            }
        } else {
            fallbackImg
        }
    }

    private var fallbackImg: some View {
        ZStack {
            theme.primaryLight
            Image(systemName: "newspaper.fill")
                .font(.system(size: 22))
                .foregroundColor(theme.primary.opacity(0.45))
        }
    }
}
