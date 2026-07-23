import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    header
                    featuresList
                    productsList
                    restoreButton
                    DisclaimerBanner()
                }
                .padding(PeakTheme.Spacing.lg)
            }
            .background(PeakTheme.background)
            .navigationTitle("Go Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if isPurchasing { LoadingView(message: "Processing...") }
            }
            .alert("Error", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: PeakTheme.Spacing.md) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 56))
                .foregroundStyle(PeakTheme.heroGradient)

            Text("Unlock Your Peak")
                .font(PeakTheme.Typography.largeTitle)

            Text("Full recovery insights, unlimited habits, advanced AI coaching, and more.")
                .font(PeakTheme.Typography.body)
                .foregroundStyle(PeakTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            featureRow("Unlimited micro-habits", icon: "checkmark.circle.fill")
            featureRow("Full history & advanced charts", icon: "chart.line.uptrend.xyaxis")
            featureRow("500 AI coach messages/month", icon: "bubble.left.and.bubble.right.fill")
            featureRow("PDF recovery reports", icon: "doc.richtext.fill")
            featureRow("Priority sync & support", icon: "icloud.fill")
        }
        .padding(PeakTheme.Spacing.md)
        .background(PeakTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.lg))
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(spacing: PeakTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(PeakTheme.coral)
            Text(text)
                .font(PeakTheme.Typography.body)
        }
    }

    private var productsList: some View {
        VStack(spacing: PeakTheme.Spacing.sm) {
            if let subscription = container.subscription as? SubscriptionService {
                ForEach(subscription.products, id: \.id) { product in
                    Button {
                        Task { await purchase(product) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(product.displayName)
                                    .font(PeakTheme.Typography.headline)
                                Text(product.description)
                                    .font(PeakTheme.Typography.caption)
                                    .foregroundStyle(PeakTheme.textSecondary)
                            }
                            Spacer()
                            Text(product.displayPrice)
                                .font(PeakTheme.Typography.headline)
                                .foregroundStyle(PeakTheme.coral)
                        }
                        .padding(PeakTheme.Spacing.md)
                        .background(PeakTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
                    }
                    .foregroundStyle(PeakTheme.textPrimary)
                }
            }

            if (container.subscription as? SubscriptionService)?.products.isEmpty != false {
                Text("Products load from App Store Connect. Configure IAP IDs in portal.")
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
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