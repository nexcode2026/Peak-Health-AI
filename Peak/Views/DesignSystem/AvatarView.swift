import SwiftUI

struct AvatarView: View {
    let name: String
    var avatarData: Data?
    var size: CGFloat = 64
    var showEditBadge: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let data = avatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(PeakTheme.heroGradient)
                        .overlay {
                            Text(String(name.prefix(1)).uppercased())
                                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(PeakTheme.surface, lineWidth: 3))

            if showEditBadge {
                Image(systemName: "camera.fill")
                    .font(.system(size: size * 0.18))
                    .foregroundStyle(.white)
                    .padding(size * 0.08)
                    .background(PeakTheme.coral)
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }
        }
    }
}