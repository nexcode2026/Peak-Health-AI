import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID = PeakConstants.Products.premiumYearly
    @State private var isPurchasing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.xl) {
                    header
                    featuresGrid
                    planPicker
                    purchaseButton
                    restoreButton
                    legalFooter
                }
                .padding(PeakTheme.Spacing.lg)
            }
            .peakScreenBackground()
            .navigationTitle("Peak Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if isPurchasing {
                    Color.black.opacity(0.10).ignoresSafeArea()
                    LoadingView(message: "Confirming with the App Store…")
                }
            }
            .alert("Subscription Error", isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .task {
                await container.subscription.loadProducts()
                if !container.subscription.products.contains(where: { $0.id == selectedProductID }),
                   let first = container.subscription.products.first {
                    selectedProductID = first.id
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: PeakTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(PeakTheme.spectralGradient)
                    .frame(width: 124, height: 124)
                    .blur(radius: 28)
                    .opacity(0.22)
                Image("AppIconPreviewPrism")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 94, height: 94)
                    .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                    .shadow(color: PeakTheme.ultraviolet.opacity(0.35), radius: 20, y: 10)
            }

            Text("Turn your data into momentum")
                .font(PeakTheme.Typography.largeTitle)
                .multilineTextAlignment(.center)

            Text("Deeper recovery intelligence, unlimited tracking, advanced trends, and a more capable Peak Coach.")
                .font(PeakTheme.Typography.body)
                .foregroundStyle(PeakTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featuresGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PeakTheme.Spacing.sm) {
            feature("Unlimited habits", icon: "checkmark.seal.fill", color: PeakTheme.mint)
            feature("Advanced trends", icon: "chart.xyaxis.line", color: PeakTheme.electricBlue)
            feature("500 AI messages", icon: "sparkles", color: PeakTheme.ultraviolet)
            feature("PDF health reports", icon: "doc.richtext.fill", color: PeakTheme.coral)
        }
    }

    private func feature(_ title: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(title)
                .font(PeakTheme.Typography.caption)
                .foregroundStyle(PeakTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(PeakTheme.Spacing.md)
        .glassCard(tint: color.opacity(0.06))
    }

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            Text("Choose your plan")
                .font(PeakTheme.Typography.headline)

            if container.subscription.products.isEmpty {
                HStack(spacing: PeakTheme.Spacing.sm) {
                    ProgressView()
                    Text("Loading weekly, monthly, and yearly plans…")
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(PeakTheme.Spacing.lg)
                .glassCard()
            } else {
                ForEach(container.subscription.products, id: \.id) { product in
                    planCard(product)
                }
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let selected = selectedProductID == product.id

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedProductID = product.id
            }
            PeakHaptics.selection()
        } label: {
            HStack(spacing: PeakTheme.Spacing.md) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? PeakTheme.mint : PeakTheme.textSecondary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(planName(product.id))
                            .font(PeakTheme.Typography.headline)
                        if let badge = planBadge(product.id) {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(PeakTheme.spectralGradient, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(planDetail(product.id))
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }

                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(PeakTheme.Typography.headline)
                    Text(planUnit(product.id))
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
            .padding(PeakTheme.Spacing.md)
            .glassCard(
                tint: selected ? PeakTheme.accent.opacity(0.15) : nil,
                interactive: true
            )
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        Button("Continue with Peak Premium") {
            guard let product = container.subscription.products.first(where: { $0.id == selectedProductID }) else {
                error = "Subscription products are not available yet. Check your connection and App Store configuration."
                return
            }
            Task { await purchase(product) }
        }
        .buttonStyle(PeakPrimaryButtonStyle())
        .disabled(isPurchasing || container.subscription.products.isEmpty)
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task {
                isPurchasing = true
                defer { isPurchasing = false }
                do {
                    try await container.subscription.restorePurchases()
                    dismiss()
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
        .font(PeakTheme.Typography.caption)
        .foregroundStyle(PeakTheme.textSecondary)
    }

    private var legalFooter: some View {
        VStack(spacing: PeakTheme.Spacing.sm) {
            Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless canceled at least 24 hours before the current period ends. Manage or cancel in App Store settings.")
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
                .multilineTextAlignment(.center)
            HStack {
                Link("Terms", destination: URL(string: PeakConstants.URLs.termsOfService)!)
                Text("•")
                Link("Privacy", destination: URL(string: PeakConstants.URLs.privacyPolicy)!)
            }
            .font(PeakTheme.Typography.micro)
        }
    }

    private func planName(_ id: String) -> String {
        switch id {
        case PeakConstants.Products.premiumWeekly: "Weekly"
        case PeakConstants.Products.premiumMonthly: "Monthly"
        case PeakConstants.Products.premiumYearly: "Yearly"
        default: "Premium"
        }
    }

    private func planDetail(_ id: String) -> String {
        switch id {
        case PeakConstants.Products.premiumWeekly: "Maximum flexibility"
        case PeakConstants.Products.premiumMonthly: "A balanced monthly commitment"
        case PeakConstants.Products.premiumYearly: "The lowest long-term price"
        default: "Full Premium access"
        }
    }

    private func planBadge(_ id: String) -> String? {
        switch id {
        case PeakConstants.Products.premiumMonthly: "POPULAR"
        case PeakConstants.Products.premiumYearly: "BEST VALUE"
        default: nil
        }
    }

    private func planUnit(_ id: String) -> String {
        switch id {
        case PeakConstants.Products.premiumWeekly: "per week"
        case PeakConstants.Products.premiumMonthly: "per month"
        case PeakConstants.Products.premiumYearly: "per year"
        default: ""
        }
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let success = try await container.subscription.purchase(product)
            if success { dismiss() }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
