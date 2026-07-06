import Foundation

// MARK: - Story group (all stories of one user)

struct StoryGroup: Identifiable {
    let id: Int           // user id
    let user: DashUser?
    let stories: [DashStory]
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
