import SwiftUI

struct LaunchScreenView: View {
    var message: String = "Preparing your health command center…"
    @State private var isOrbiting = false
    @State private var isPulsing = false
    @State private var isVisible = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.015, green: 0.025, blue: 0.09), Color(red: 0.025, green: 0.09, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            AnimatedMeshBackground()
                .opacity(0.75)
                .ignoresSafeArea()

            orbitalField

            VStack(spacing: 30) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(PeakTheme.electricBlue.opacity(0.18))
                        .frame(width: 178, height: 178)
                        .blur(radius: 18)
                        .scaleEffect(isPulsing ? 1.15 : 0.88)

                    Image("AppIconPreviewPrimary")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 126, height: 126)
                        .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 29, style: .continuous)
                                .stroke(.white.opacity(0.36), lineWidth: 1)
                        }
                        .shadow(color: PeakTheme.electricBlue.opacity(0.42), radius: 28, y: 14)
                        .scaleEffect(isVisible ? 1 : 0.82)
                        .opacity(isVisible ? 1 : 0)
                }

                VStack(spacing: 8) {
                    Text("PEAK")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .tracking(9)
                        .foregroundStyle(.white)

                    Text("HEALTH INTELLIGENCE")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(3.2)
                        .foregroundStyle(PeakTheme.electricBlue)
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 12)

                Spacer()

                VStack(spacing: PeakTheme.Spacing.md) {
                    HStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(PeakTheme.spectralGradient)
                                .frame(width: index == 1 ? 42 : 18, height: 5)
                                .opacity(isPulsing ? 1 : 0.35)
                                .animation(
                                    .easeInOut(duration: 0.75)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.16),
                                    value: isPulsing
                                )
                        }
                    }

                    Text(message)
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                        Text("Private by design")
                    }
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.mint)
                }
                .padding(.horizontal, PeakTheme.Spacing.xl)
                .padding(.vertical, PeakTheme.Spacing.lg)
                .glassCard(cornerRadius: PeakTheme.Radius.xl, tint: PeakTheme.electricBlue.opacity(0.08))
                .padding(.horizontal, PeakTheme.Spacing.xl)
                .padding(.bottom, 34)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.72)) {
                isVisible = true
            }
            withAnimation(.linear(duration: 13).repeatForever(autoreverses: false)) {
                isOrbiting = true
            }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var orbitalField: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Ellipse()
                    .trim(from: 0.08, to: 0.72)
                    .stroke(
                        index == 1 ? PeakTheme.ultraviolet.opacity(0.28) : PeakTheme.electricBlue.opacity(0.22),
                        style: StrokeStyle(lineWidth: index == 1 ? 1.5 : 0.8, lineCap: .round)
                    )
                    .frame(width: 310 + CGFloat(index * 76), height: 180 + CGFloat(index * 58))
                    .rotationEffect(.degrees(Double(index * 48) + (isOrbiting ? 360 : 0)))
            }
        }
        .blur(radius: 0.2)
        .allowsHitTesting(false)
    }
}

#Preview {
    LaunchScreenView(message: "Syncing your private iCloud health graph…")
}
