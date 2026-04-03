import Foundation
import Combine
import RevenueCat

final class SubscriptionManager: NSObject, ObservableObject {

    static let shared = SubscriptionManager()

    @Published var isProUser = false
    @Published var currentOffering: Offering?
    @Published var activeSubscription: String?

    private static let apiKey = "appl_wRWvMgzrxDLmbGvjOZCJUVzcJXf"

    private override init() {
        super.init()
    }

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)
        Purchases.shared.delegate = self
        refreshStatus()
    }

    func refreshStatus() {
        Purchases.shared.getCustomerInfo { [weak self] info, _ in
            DispatchQueue.main.async {
                self?.updateStatus(from: info)
            }
        }
    }

    func fetchOfferings() {
        Purchases.shared.getOfferings { [weak self] offerings, _ in
            DispatchQueue.main.async {
                self?.currentOffering = offerings?.current
            }
        }
    }

    func purchase(_ package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        let info = result.customerInfo
        await MainActor.run {
            updateStatus(from: info)
        }
        return !result.userCancelled
    }

    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        await MainActor.run {
            updateStatus(from: info)
        }
    }

    private func updateStatus(from info: CustomerInfo?) {
        guard let info else { return }
        isProUser = !info.entitlements.active.isEmpty
        activeSubscription = info.entitlements.active.values.first?.productIdentifier
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatus(from: customerInfo)
        }
    }
}
