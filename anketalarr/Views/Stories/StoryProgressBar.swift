import SwiftUI

// MARK: - Progress Bar

struct StoryProgressBar: View {
    let progress: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.35)).frame(height: 2.5)
                Capsule().fill(color)
                    .frame(width: g.size.width * min(progress, 1), height: 2.5)
            }
        }
        .frame(height: 2.5)
    }
}
