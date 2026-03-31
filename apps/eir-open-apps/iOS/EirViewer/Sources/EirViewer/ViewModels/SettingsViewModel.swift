import StoreKit
import SwiftUI

#if canImport(DeviceCheck)
import DeviceCheck
#endif

private let managedCloudKeyVersion = "v2"

@MainActor
class SettingsViewModel: ObservableObject {
    static let eirTrialRequestsPerToken = 100
    static let eirTrialDailyTokenGrant = 10
    static let hostedClientKeyVersion = managedCloudKeyVersion

    @Published var providers: [LLMProviderConfig]
    @Published var activeProviderType: LLMProviderType
    @Published var activePromptVersionId: String {
        didSet {
            UserDefaults.standard.set(activePromptVersionId, forKey: "eir_active_prompt_version")
        }
    }
    @Published var customPrompts: [PromptVersion] {
        didSet { saveCustomPrompts() }
    }
    @Published private(set) var managedAccessSnapshots: [LLMProviderType: ManagedCloudAccessSnapshot]

    init() {
        let saved = Self.loadProviders()
        self.providers = saved
        self.activeProviderType = Self.loadActiveProvider()
        self.activePromptVersionId = UserDefaults.standard.string(forKey: "eir_active_prompt_version")
            ?? PromptLibrary.defaultVersionId
        self.customPrompts = Self.loadCustomPrompts()
        self.managedAccessSnapshots = Self.loadManagedAccessSnapshots()
    }

    var activeProvider: LLMProviderConfig? {
        providers.first(where: { $0.type == activeProviderType })
    }

    /// All available prompts: built-in + custom
    var allPromptVersions: [PromptVersion] {
        PromptLibrary.versions + customPrompts
    }

    var activePromptVersion: PromptVersion? {
        allPromptVersions.first(where: { $0.id == activePromptVersionId })
    }

    func addCustomPrompt(name: String, description: String, systemPrompt: String) {
        let prompt = PromptVersion(
            id: "custom_\(UUID().uuidString)",
            name: name,
            description: description,
            systemPrompt: systemPrompt
        )
        customPrompts.append(prompt)
    }

    func updateCustomPrompt(_ prompt: PromptVersion) {
        if let idx = customPrompts.firstIndex(where: { $0.id == prompt.id }) {
            customPrompts[idx] = prompt
        }
    }

    func deleteCustomPrompt(_ id: String) {
        customPrompts.removeAll { $0.id == id }
        if activePromptVersionId == id {
            activePromptVersionId = PromptLibrary.defaultVersionId
        }
    }

    private func saveCustomPrompts() {
        if let data = try? JSONEncoder().encode(customPrompts) {
            UserDefaults.standard.set(data, forKey: "eir_custom_prompts")
        }
    }

    private func saveManagedAccessSnapshots() {
        let payload = managedAccessSnapshots.map { ManagedAccessRecord(type: $0.key, snapshot: $0.value) }
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: "eir_managed_access_snapshots")
        }
    }

    private static func loadCustomPrompts() -> [PromptVersion] {
        if let data = UserDefaults.standard.data(forKey: "eir_custom_prompts"),
           let saved = try? JSONDecoder().decode([PromptVersion].self, from: data) {
            return saved
        }
        return []
    }

    func apiKey(for type: LLMProviderType) -> String {
        KeychainService.get(key: "eir_api_key_\(type.rawValue)") ?? ""
    }

    func setApiKey(_ key: String, for type: LLMProviderType) {
        if key.isEmpty {
            KeychainService.delete(key: "eir_api_key_\(type.rawValue)")
        } else {
            KeychainService.set(key: "eir_api_key_\(type.rawValue)", value: key)
        }
        objectWillChange.send()
    }

    func managedAccessSnapshot(for type: LLMProviderType) -> ManagedCloudAccessSnapshot? {
        managedAccessSnapshots[type]
    }

    func hasManagedAccessToken(for type: LLMProviderType) -> Bool {
        !managedAccessToken(for: type).isEmpty
    }

    func resolvedCredential(for config: LLMProviderConfig) async throws -> String {
        if config.type.usesManagedTrialAccess {
            let existing = managedAccessToken(for: config.type)
            if !existing.isEmpty {
                return existing
            }

            _ = try await provisionManagedAccess(for: config)
            let token = managedAccessToken(for: config.type)
            guard !token.isEmpty else {
                throw LLMError.requestFailed("Trial access was provisioned, but no usable cloud token was returned.")
            }
            return token
        }

        let key = apiKey(for: config.type)
        guard !key.isEmpty else {
            throw LLMError.noAPIKey
        }
        return key
    }

    @discardableResult
    func provisionManagedAccess(for config: LLMProviderConfig) async throws -> ManagedCloudAccessSnapshot {
        let normalizedBaseURL = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBaseURL.isEmpty else {
            throw LLMError.requestFailed("Set the hosted Eir cloud API URL before provisioning trial credits.")
        }

        let bootstrap = try await ManagedCloudBootstrapClient.bootstrap(baseURLString: normalizedBaseURL)
        let token = bootstrap.bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw LLMError.requestFailed("Secure cloud access setup completed without a usable client token.")
        }

        KeychainService.set(key: managedAccessTokenKey(for: config.type), value: token)

        let snapshot = ManagedCloudAccessSnapshot(
            clientId: bootstrap.clientId,
            mode: bootstrap.mode,
            attestation: bootstrap.attestation,
            quota: bootstrap.quota,
            provisionedAt: Date(),
            bootstrapBaseURL: normalizedBaseURL
        )
        managedAccessSnapshots[config.type] = snapshot
        if UserDefaults.standard.object(forKey: trialStartedAtKey(for: config.type)) == nil {
            UserDefaults.standard.set(snapshot.provisionedAt, forKey: trialStartedAtKey(for: config.type))
        }
        saveManagedAccessSnapshots()
        objectWillChange.send()
        return snapshot
    }

    func clearManagedAccess(for type: LLMProviderType) {
        KeychainService.delete(key: managedAccessTokenKey(for: type))
        managedAccessSnapshots.removeValue(forKey: type)
        UserDefaults.standard.removeObject(forKey: trialStartedAtKey(for: type))
        saveManagedAccessSnapshots()
        objectWillChange.send()
    }

    func updateManagedAccessQuota(_ quota: ManagedCloudQuota, for type: LLMProviderType) {
        guard var snapshot = managedAccessSnapshots[type] else { return }
        snapshot = ManagedCloudAccessSnapshot(
            clientId: snapshot.clientId,
            mode: snapshot.mode,
            attestation: snapshot.attestation,
            quota: quota,
            provisionedAt: snapshot.provisionedAt,
            bootstrapBaseURL: snapshot.bootstrapBaseURL
        )
        managedAccessSnapshots[type] = snapshot
        saveManagedAccessSnapshots()
        objectWillChange.send()
    }

    @discardableResult
    func syncBillingPurchases(_ purchases: [BillingPurchaseClaim], for type: LLMProviderType) async throws -> ManagedCloudAccessSnapshot {
        guard let config = providers.first(where: { $0.type == type }) else {
            throw LLMError.noProvider
        }

        let token = try await resolvedCredential(for: config)
        let normalizedBaseURL = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalizedBaseURL)?.appending(path: "client/billing/sync") else {
            throw LLMError.requestFailed("The hosted Eir cloud billing URL is not valid.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(BillingPurchaseSyncRequest(purchases: purchases))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let payload = try? JSONDecoder().decode(ManagedCloudBootstrapError.self, from: data)
            let message = payload?.error ?? String(data: data, encoding: .utf8) ?? "Billing sync failed."
            throw LLMError.requestFailed(message)
        }

        let payload = try JSONDecoder().decode(BillingPurchaseSyncResponse.self, from: data)
        let snapshot = ManagedCloudAccessSnapshot(
            clientId: payload.clientId,
            mode: payload.mode,
            attestation: managedAccessSnapshots[type]?.attestation,
            quota: payload.quota,
            provisionedAt: managedAccessSnapshots[type]?.provisionedAt ?? Date(),
            bootstrapBaseURL: normalizedBaseURL
        )
        managedAccessSnapshots[type] = snapshot
        saveManagedAccessSnapshots()
        objectWillChange.send()
        return snapshot
    }

    func updateProvider(_ config: LLMProviderConfig) {
        if let idx = providers.firstIndex(where: { $0.type == config.type }) {
            let oldConfig = providers[idx]
            providers[idx] = config

            if config.type.usesManagedTrialAccess &&
                oldConfig.baseURL.trimmingCharacters(in: .whitespacesAndNewlines) !=
                config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines) {
                clearManagedAccess(for: config.type)
            }
        }
        saveProviders()
    }

    func setActiveProvider(_ type: LLMProviderType) {
        activeProviderType = type
        UserDefaults.standard.set(type.rawValue, forKey: "eir_active_provider")
    }

    private func saveProviders() {
        if let data = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(data, forKey: "eir_providers")
        }
    }

    private static func loadProviders() -> [LLMProviderConfig] {
        let sortOrder = Dictionary(uniqueKeysWithValues: LLMProviderType.allCases.enumerated().map { ($1, $0) })

        if let data = UserDefaults.standard.data(forKey: "eir_providers"),
           let saved = try? JSONDecoder().decode([LLMProviderConfig].self, from: data) {
            // Merge in any new provider types that were added since last save
            let existingTypes = Set(saved.map(\.type))
            let missing = LLMProviderType.allCases
                .filter { !existingTypes.contains($0) }
                .map { LLMProviderConfig(type: $0) }
            return (saved + missing).sorted {
                (sortOrder[$0.type] ?? .max) < (sortOrder[$1.type] ?? .max)
            }
        }
        return LLMProviderType.allCases.map { LLMProviderConfig(type: $0) }
    }

    private static func loadManagedAccessSnapshots() -> [LLMProviderType: ManagedCloudAccessSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: "eir_managed_access_snapshots"),
              let records = try? JSONDecoder().decode([ManagedAccessRecord].self, from: data) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: records.map { ($0.type, $0.snapshot) })
    }

    private static func loadActiveProvider() -> LLMProviderType {
        if let raw = UserDefaults.standard.string(forKey: "eir_active_provider"),
           let type = LLMProviderType(rawValue: raw) {
            return type
        }
        return .bergetTrial
    }

    private func managedAccessToken(for type: LLMProviderType) -> String {
        KeychainService.get(key: managedAccessTokenKey(for: type))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func managedAccessTokenKey(for type: LLMProviderType) -> String {
        "eir_managed_cloud_token_\(type.storageSlug)_\(Self.hostedClientKeyVersion)"
    }

    private func trialStartedAtKey(for type: LLMProviderType) -> String {
        "eir_managed_cloud_trial_started_at_\(type.storageSlug)_\(Self.hostedClientKeyVersion)"
    }

    func eirTrialBalance(for snapshot: ManagedCloudAccessSnapshot, type: LLMProviderType, now: Date = Date()) -> EirTrialBalance {
        let calendar = Calendar.current
        let trialStartedAt = (UserDefaults.standard.object(forKey: trialStartedAtKey(for: type)) as? Date) ?? snapshot.provisionedAt
        let startDay = calendar.startOfDay(for: trialStartedAt)
        let currentDay = calendar.startOfDay(for: now)
        let elapsedDays = max(calendar.dateComponents([.day], from: startDay, to: currentDay).day ?? 0, 0)
        let totalTokens = (elapsedDays + 1) * Self.eirTrialDailyTokenGrant
        let usedRequests = max(snapshot.quota.used.requests, 0)
        let usedTokens = usedRequests == 0 ? 0 : Int(ceil(Double(usedRequests) / Double(Self.eirTrialRequestsPerToken)))

        return EirTrialBalance(
            usedTokens: usedTokens,
            totalTokens: totalTokens,
            remainingTokens: max(totalTokens - usedTokens, 0),
            requestsPerToken: Self.eirTrialRequestsPerToken,
            dailyTokenGrant: Self.eirTrialDailyTokenGrant
        )
    }
}

private struct ManagedAccessRecord: Codable {
    let type: LLMProviderType
    let snapshot: ManagedCloudAccessSnapshot
}

struct ManagedCloudAccessSnapshot: Codable {
    let clientId: String
    let mode: String
    let attestation: ManagedCloudBootstrapAttestation?
    let quota: ManagedCloudQuota
    let provisionedAt: Date
    let bootstrapBaseURL: String
}

struct ManagedCloudQuota: Codable {
    struct UsageBlock: Codable {
        let requests: Int
        let audioSeconds: Int
        let estimatedCostUsd: Double
    }

    let used: UsageBlock
    let limits: UsageBlock
    let remaining: UsageBlock
}

struct EirTrialBalance {
    let usedTokens: Int
    let totalTokens: Int
    let remainingTokens: Int
    let requestsPerToken: Int
    let dailyTokenGrant: Int
}

struct BillingPurchaseClaim: Codable, Hashable, Identifiable {
    let transactionId: String
    let originalTransactionId: String
    let productId: String
    let productType: String
    let purchasedAt: Date
    let expiresAt: Date?
    let revokedAt: Date?

    var id: String { transactionId }
}

private struct BillingPurchaseSyncRequest: Encodable {
    let purchases: [BillingPurchaseClaim]
}

private struct BillingPurchaseSyncResponse: Decodable {
    let clientId: String
    let mode: String
    let quota: ManagedCloudQuota
}

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published var lastError: String?
    @Published var isLoading = false
    @Published var isPurchasing = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task {
            await observeTransactionUpdates()
        }

        Task {
            await refreshProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var subscriptionProductID: String {
        Bundle.main.object(forInfoDictionaryKey: "EIRBillingSubscriptionProductID") as? String ?? ""
    }

    var topUpProductIDs: [String] {
        Bundle.main.object(forInfoDictionaryKey: "EIRBillingTopUpProductIDs") as? [String] ?? []
    }

    var hasBillingProducts: Bool {
        !allProductIDs.isEmpty
    }

    var subscriptionProduct: Product? {
        let id = subscriptionProductID
        guard !id.isEmpty else { return nil }
        return products.first(where: { $0.id == id })
    }

    var topUpProducts: [Product] {
        let ids = Set(topUpProductIDs)
        return products.filter { ids.contains($0.id) }
    }

    func refreshProducts() async {
        let ids = allProductIDs
        guard !ids.isEmpty else {
            products = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: ids).sorted { lhs, rhs in
                let lhsRank = productTypeRank(lhs.type)
                let rhsRank = productTypeRank(rhs.type)
                if lhsRank == rhsRank {
                    return lhs.price < rhs.price
                }
                return lhsRank < rhsRank
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            purchased.insert(transaction.productID)
        }
        purchasedProductIDs = purchased
    }

    @discardableResult
    func purchase(_ product: Product, settingsVM: SettingsViewModel) async throws -> ManagedCloudAccessSnapshot? {
        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            let claim = BillingPurchaseClaim(
                transactionId: String(transaction.id),
                originalTransactionId: String(transaction.originalID),
                productId: transaction.productID,
                productType: productTypeName(transaction.productType),
                purchasedAt: transaction.purchaseDate,
                expiresAt: transaction.expirationDate,
                revokedAt: transaction.revocationDate
            )
            let snapshot = try await settingsVM.syncBillingPurchases([claim], for: .bergetTrial)
            await transaction.finish()
            await refreshEntitlements()
            return snapshot
        case .pending:
            lastError = "Purchase is pending approval."
            return nil
        case .userCancelled:
            return nil
        @unknown default:
            lastError = "Purchase failed."
            return nil
        }
    }

    @discardableResult
    func restorePurchases(settingsVM: SettingsViewModel) async throws -> ManagedCloudAccessSnapshot? {
        try await AppStore.sync()
        await refreshEntitlements()

        var claims: [BillingPurchaseClaim] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            claims.append(
                BillingPurchaseClaim(
                    transactionId: String(transaction.id),
                    originalTransactionId: String(transaction.originalID),
                    productId: transaction.productID,
                    productType: productTypeName(transaction.productType),
                    purchasedAt: transaction.purchaseDate,
                    expiresAt: transaction.expirationDate,
                    revokedAt: transaction.revocationDate
                )
            )
        }

        guard !claims.isEmpty else { return nil }
        return try await settingsVM.syncBillingPurchases(claims, for: .bergetTrial)
    }

    private var allProductIDs: [String] {
        var ids: [String] = []
        let subscription = subscriptionProductID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !subscription.isEmpty {
            ids.append(subscription)
        }
        ids.append(contentsOf: topUpProductIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return Array(Set(ids))
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            do {
                let transaction = try verifiedTransaction(from: result)
                await refreshEntitlements()
                await transaction.finish()
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func verifiedTransaction(from result: VerificationResult<StoreKit.Transaction>) throws -> StoreKit.Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw LLMError.requestFailed("Purchase verification failed.")
        }
    }

    private func productTypeName(_ type: Product.ProductType) -> String {
        switch type {
        case .autoRenewable:
            return "auto_renewable"
        case .consumable:
            return "consumable"
        case .nonConsumable:
            return "non_consumable"
        case .nonRenewable:
            return "non_renewing"
        default:
            return "unknown"
        }
    }

    private func productTypeRank(_ type: Product.ProductType) -> Int {
        switch type {
        case .autoRenewable:
            return 0
        case .consumable:
            return 1
        case .nonConsumable:
            return 2
        case .nonRenewable:
            return 3
        default:
            return 4
        }
    }
}

struct ManagedCloudBootstrapAttestation: Codable, Sendable {
    let provider: String
    let status: String
    let isSupported: Bool
    let keyID: String?
    let evidence: String?
}

private struct ManagedCloudBootstrapResponse: Decodable {
    let clientId: String
    let bearerToken: String
    let mode: String
    let attestation: ManagedCloudBootstrapAttestation?
    let quota: ManagedCloudQuota
}

private struct ManagedCloudBootstrapError: Decodable {
    let error: String
}

private struct ManagedCloudBootstrapContext {
    let installID: String
    let platform: String
    let attestation: ManagedCloudBootstrapAttestation
}

private enum ManagedCloudBootstrapClient {
    private static let installIDKey = "eir_managed_cloud_install_id_\(managedCloudKeyVersion)"
    private static let appAttestKeyIDKey = "eir_managed_cloud_app_attest_key_id_\(managedCloudKeyVersion)"

    private struct RequestBody: Encodable {
        let installId: String
        let platform: String
        let attestation: ManagedCloudBootstrapAttestation
    }

    static func bootstrap(baseURLString: String) async throws -> ManagedCloudBootstrapResponse {
        let normalizedBaseURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: normalizedBaseURL) else {
            throw LLMError.requestFailed("The hosted Eir cloud API URL is not valid.")
        }

        let context = await currentContext()

        var request = URLRequest(url: baseURL.appending(path: "client/bootstrap"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                installId: context.installID,
                platform: context.platform,
                attestation: context.attestation
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let payload = try? JSONDecoder().decode(ManagedCloudBootstrapError.self, from: data)
            let message = payload?.error ?? String(data: data, encoding: .utf8) ?? "Secure cloud access setup failed."
            throw LLMError.requestFailed(message)
        }

        return try JSONDecoder().decode(ManagedCloudBootstrapResponse.self, from: data)
    }

    private static func currentContext() async -> ManagedCloudBootstrapContext {
        ManagedCloudBootstrapContext(
            installID: installID(),
            platform: "ios",
            attestation: await attestation()
        )
    }

    private static func installID() -> String {
        let stored = KeychainService.get(key: installIDKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !stored.isEmpty {
            return stored
        }

        let generated = UUID().uuidString.lowercased()
        KeychainService.set(key: installIDKey, value: generated)
        return generated
    }

    private static func attestation() async -> ManagedCloudBootstrapAttestation {
#if canImport(DeviceCheck)
        if #available(iOS 14.0, *), DCAppAttestService.shared.isSupported {
            let keyID = await appAttestKeyID()
            return ManagedCloudBootstrapAttestation(
                provider: "app_attest",
                status: keyID == nil ? "supported_uninitialized" : "supported_key_ready",
                isSupported: true,
                keyID: keyID,
                evidence: nil
            )
        }
#endif

        return ManagedCloudBootstrapAttestation(
            provider: "none",
            status: "unavailable",
            isSupported: false,
            keyID: nil,
            evidence: nil
        )
    }

#if canImport(DeviceCheck)
    @available(iOS 14.0, *)
    private static func appAttestKeyID() async -> String? {
        let stored = KeychainService.get(key: appAttestKeyIDKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !stored.isEmpty {
            return stored
        }

        do {
            let generated: String = try await withCheckedThrowingContinuation { continuation in
                DCAppAttestService.shared.generateKey { keyID, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: keyID ?? "")
                }
            }

            let normalized = generated.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                return nil
            }

            KeychainService.set(key: appAttestKeyIDKey, value: normalized)
            return normalized
        } catch {
            return nil
        }
    }
#endif
}
