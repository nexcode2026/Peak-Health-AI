import Foundation
import SwiftData

// MARK: - SwiftData + CloudKit container bootstrap

enum DataStoreMode: String, Sendable {
    case cloudKitPrivate
    case cloudKitAutomatic
    case localPersistent
    case inMemory
}

struct ModelContainerBootstrap {
    let container: ModelContainer
    let mode: DataStoreMode
}

enum ModelContainerFactory {
    /// True when the active container is syncing via CloudKit.
    private(set) static var isCloudKitEnabled = false
    private(set) static var activeMode: DataStoreMode = .localPersistent
    /// Human-readable reason CloudKit did not load (shown in Today banner).
    private(set) static var lastCloudKitError: String?

    private static let cloudStoreName = "PeakCloud"
    private static let localStoreName = "PeakLocal"

    static func makeContainer() -> ModelContainer? {
        makeBootstrap()?.container
    }

    static func makeBootstrap(allowPersistentStore: Bool = true) -> ModelContainerBootstrap? {
        isCloudKitEnabled = false
        lastCloudKitError = nil
        LaunchBootstrap.logPhase("makeBootstrap.start allowPersistent=\(allowPersistentStore)")

        if OnboardingStorage.previousLaunchDidNotComplete {
            LaunchBootstrap.logPhase("crashRecovery.detected.skippingWipe")
            OnboardingStorage.previousLaunchDidNotComplete = false
        }

        wipeLegacyDefaultStoresAlways()

        if isRunningInXcodePreview {
            if let bootstrap = tryBootstrapInMemory(label: "preview") {
                persistMode(bootstrap.mode)
                return bootstrap
            }
            return createEmergencyContainer(reason: "preview-fallback")
        }

        if OnboardingStorage.pendingCloudRecovery {
            wipeCloudStoreFilesOnly()
            OnboardingStorage.pendingCloudRecovery = false
            PeakLogger.cloudKit.info("Cleared CloudKit cache before local bootstrap.")
        }

        guard validateSchemaInMemory(label: "preflight") else {
            lastCloudKitError = "Peak could not load its data models. Reinstall the app or contact support."
            LaunchBootstrap.logPhase("schema.preflight.failed")
            return createEmergencyContainer(reason: "schema-preflight-failed")
        }

        guard allowPersistentStore else {
            LaunchBootstrap.logPhase("persistent.skipped.protectedDataUnavailable")
            lastCloudKitError = "Unlock your iPhone to save data. Relaunch Peak after unlocking."
            PeakLogger.cloudKit.fault("Refusing in-memory store — device must be unlocked for persistence.")
            return nil
        }

        // 1) CloudKit private database — primary store when iCloud is available.
        if isICloudAvailable {
            LaunchBootstrap.logPhase("cloudKit.open.start")
            if let bootstrap = tryBootstrapCloudKit() {
                LaunchBootstrap.logPhase("cloudKit.open.success.\(bootstrap.mode.rawValue)")
                persistMode(bootstrap.mode)
                return bootstrap
            }
            lastCloudKitError = lastCloudKitError
                ?? "CloudKit unavailable. Using on-device storage until iCloud is ready."
            PeakLogger.cloudKit.warning("CloudKit bootstrap failed — falling back to local store.")
        } else {
            lastCloudKitError = "Sign into iCloud in Settings → Apple ID for cross-device sync."
            PeakLogger.cloudKit.warning("\(lastCloudKitError!)")
        }

        // 2) Local persistent fallback — survives app restarts even without iCloud.
        LaunchBootstrap.logPhase("local.open.start")
        if let bootstrap = tryBootstrapLocalPersistent(label: "primary") {
            LaunchBootstrap.logPhase("local.open.success.\(bootstrap.mode.rawValue)")
            persistMode(bootstrap.mode)
            return bootstrap
        }

        lastCloudKitError = "Peak could not open its database. Delete the app and reinstall."
        PeakLogger.cloudKit.fault("All persistent bootstrap attempts failed.")
        return nil
    }

    /// Wipe only CloudKit SQLite caches and schedule a clean CloudKit bootstrap on next launch.
    static func noteCloudKitAccountIssue(_ message: String) {
        guard !isCloudKitEnabled else { return }
        lastCloudKitError = message
    }

    static func scheduleCloudKitRecovery() {
        wipeCloudStoreFilesOnly()
        OnboardingStorage.pendingCloudRecovery = true
        OnboardingStorage.preferLocalStore = false
        OnboardingStorage.cloudKitSyncEnabled = true
        lastCloudKitError = "CloudKit cache cleared. Force quit Peak and reopen to attempt iCloud sync."
        PeakLogger.cloudKit.warning("CloudKit recovery scheduled for next launch.")
    }

    /// Attempt CloudKit bootstrap — call only after local launch succeeds and user opted in.
    static func attemptCloudKitBootstrap() -> ModelContainerBootstrap? {
        guard isICloudAvailable, OnboardingStorage.cloudKitSyncEnabled else { return nil }
        return tryBootstrapCloudKit()
    }

    /// Opt in to CloudKit on the next launch.
    static func enableCloudKitSyncOnNextLaunch() {
        OnboardingStorage.preferLocalStore = false
        OnboardingStorage.cloudKitSyncEnabled = true
        lastCloudKitError = "iCloud sync enabled. Force quit Peak and reopen the app."
    }

    // MARK: - CloudKit bootstrap

    private static func tryBootstrapCloudKit() -> ModelContainerBootstrap? {
        // 1) Simple schema — SwiftData registers the development schema on first launch.
        if let container = tryCreateSimpleCloudContainer(
            database: .private(PeakConstants.cloudKitContainer),
            label: "simple-private"
        ) {
            return finishCloudKit(container: container, mode: .cloudKitPrivate, label: "simple-private")
        }

        // 2) Versioned schema + migration plan
        if let container = tryCreateVersionedCloudContainer(
            database: .private(PeakConstants.cloudKitContainer),
            label: "versioned-private"
        ) {
            return finishCloudKit(container: container, mode: .cloudKitPrivate, label: "versioned-private")
        }

        // 3) Automatic container from entitlements
        if let container = tryCreateSimpleCloudContainer(database: .automatic, label: "simple-automatic") {
            return finishCloudKit(container: container, mode: .cloudKitAutomatic, label: "simple-automatic")
        }

        // 4) Wipe corrupted CloudKit cache (never touches PeakLocal) and retry once
        PeakLogger.cloudKit.warning("Wiping CloudKit store cache and retrying...")
        wipeCloudStoreFilesOnly()

        if let container = tryCreateSimpleCloudContainer(
            database: .private(PeakConstants.cloudKitContainer),
            label: "simple-private-retry"
        ) {
            return finishCloudKit(container: container, mode: .cloudKitPrivate, label: "simple-private-retry")
        }

        if let container = tryCreateVersionedCloudContainer(
            database: .private(PeakConstants.cloudKitContainer),
            label: "versioned-private-retry"
        ) {
            return finishCloudKit(container: container, mode: .cloudKitPrivate, label: "versioned-private-retry")
        }

        if lastCloudKitError == nil {
            lastCloudKitError = "CloudKit could not load. Check the iCloud account and CloudKit container, then restart Peak."
        }
        return nil
    }

    private static func tryCreateSimpleCloudContainer(
        database: ModelConfiguration.CloudKitDatabase,
        label: String
    ) -> ModelContainer? {
        let schema = Schema(PeakSchema.allModels)
        let configuration = ModelConfiguration(cloudStoreName, cloudKitDatabase: database)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            recordCloudKitError(label: label, error: error)
            return nil
        }
    }

    private static func tryCreateVersionedCloudContainer(
        database: ModelConfiguration.CloudKitDatabase,
        label: String
    ) -> ModelContainer? {
        let configuration = ModelConfiguration(cloudStoreName, cloudKitDatabase: database)
        return tryCreateVersionedContainer(configuration: configuration, label: label)
    }

    private static func finishCloudKit(
        container: ModelContainer,
        mode: DataStoreMode,
        label: String
    ) -> ModelContainerBootstrap {
        isCloudKitEnabled = true
        activeMode = mode
        lastCloudKitError = nil
        OnboardingStorage.preferLocalStore = false
        OnboardingStorage.cloudKitSyncEnabled = true
        PeakLogger.cloudKit.info("SwiftData CloudKit loaded (\(label), \(PeakConstants.cloudKitContainer))")
        return ModelContainerBootstrap(container: container, mode: mode)
    }

    private static var isRunningInXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Last-resort in-memory container — never uses `try!` so launch cannot trap here.
    private static func createEmergencyContainer(reason: String) -> ModelContainerBootstrap? {
        let attempts: [(String, Schema, ModelConfiguration)] = [
            ("profile-only", Schema([UserProfile.self]), ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)),
            ("full-simple", Schema(PeakSchema.allModels), ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)),
        ]

        for (label, schema, config) in attempts {
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                activeMode = .inMemory
                persistMode(.inMemory)
                lastCloudKitError = "Peak started in temporary storage (\(reason), \(label))."
                PeakLogger.cloudKit.warning("\(lastCloudKitError!)")
                return ModelContainerBootstrap(container: container, mode: .inMemory)
            } catch {
                PeakLogger.cloudKit.error("Emergency container [\(label)] failed: \(error)")
            }
        }

        return nil
    }

    // MARK: - Local bootstrap

    private static func tryBootstrapLocalPersistent(label: String) -> ModelContainerBootstrap? {
        if let bootstrap = tryBootstrapLocalSimpleSchema(label: "\(label)-simple") {
            return bootstrap
        }

        // Retry once after clearing only PeakLocal — never wipe CloudKit cache or all stores on launch.
        PeakLogger.cloudKit.warning("Local store open failed — resetting PeakLocal and retrying once...")
        wipeLocalStoreFilesOnly()

        if let bootstrap = tryBootstrapLocalSimpleSchema(label: "\(label)-simple-reset") {
            lastCloudKitError = "Local data was reset after a database issue."
            return bootstrap
        }

        return nil
    }

    private static func tryBootstrapLocalSimpleSchema(label: String) -> ModelContainerBootstrap? {
        let schema = Schema(PeakSchema.allModels)
        let config = localPersistentConfiguration()
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            activeMode = .localPersistent
            PeakLogger.cloudKit.warning("Using local store with simple schema (\(label)).")
            return ModelContainerBootstrap(container: container, mode: .localPersistent)
        } catch {
            PeakLogger.cloudKit.error("Local simple schema failed [\(label)]: \(error)")
            return nil
        }
    }

    /// Verifies the SwiftData schema can load without touching on-disk stores.
    private static func validateSchemaInMemory(label: String) -> Bool {
        let schema = Schema(PeakSchema.allModels)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            _ = try ModelContainer(for: schema, configurations: [config])
            LaunchBootstrap.logPhase("schema.preflight.ok.\(label)")
            return true
        } catch {
            PeakLogger.cloudKit.fault("Schema preflight failed [\(label)]: \(error)")
            return false
        }
    }

    private static func localPersistentConfiguration() -> ModelConfiguration {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return ModelConfiguration(localStoreName, cloudKitDatabase: .none)
        }

        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let storeURL = appSupport.appendingPathComponent("\(localStoreName).store")
        return ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
    }

    private static func tryBootstrapInMemory(label: String) -> ModelContainerBootstrap? {
        let schema = Schema(PeakSchema.allModels)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            activeMode = .inMemory
            PeakLogger.cloudKit.warning("Using in-memory store (\(label)).")
            return ModelContainerBootstrap(container: container, mode: .inMemory)
        } catch {
            PeakLogger.cloudKit.error("In-memory store failed [\(label)]: \(error)")
            return nil
        }
    }

    private static var peakSchema: Schema {
        Schema(versionedSchema: PeakSchemaV1.self)
    }

    private static func tryCreateVersionedContainer(
        configuration: ModelConfiguration,
        label: String
    ) -> ModelContainer? {
        do {
            return try ModelContainer(
                for: peakSchema,
                migrationPlan: PeakMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            recordCloudKitError(label: label, error: error)
            return nil
        }
    }

    private static func recordCloudKitError(label: String, error: Error) {
        let message = "\(label): \(error.localizedDescription)"
        lastCloudKitError = message
        PeakLogger.cloudKit.error("ModelContainer [\(label)] failed: \(error)")
    }

    private static func persistMode(_ mode: DataStoreMode) {
        OnboardingStorage.lastDataStoreMode = mode.rawValue
    }

    // MARK: - Store helpers

    static var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }



    /// Removes only PeakLocal SwiftData stores.
    @discardableResult
    static func wipeLocalStoreFilesOnly() -> Bool {
        wipeStoreFiles(matching: { name in
            name.hasPrefix(localStoreName) || name.contains("\(localStoreName).store")
        })
    }

    /// Removes unnamed legacy default stores from older Peak builds (can conflict with CloudKit).
    @discardableResult
    static func wipeLegacyDefaultStoresAlways() -> Bool {
        let removed = wipeStoreFiles(matching: { name in
            let isNamedPeakStore = name.hasPrefix(cloudStoreName)
                || name.hasPrefix(localStoreName)
            return name == "default.store"
                || name.hasPrefix("default.store")
                || (name.hasSuffix(".store") && !isNamedPeakStore)
        })
        if removed {
            PeakLogger.cloudKit.warning("Removed legacy default SwiftData store files.")
        }
        return removed
    }

    /// Removes only CloudKit SwiftData stores — never deletes PeakLocal offline data.
    @discardableResult
    static func wipeCloudStoreFilesOnly() -> Bool {
        wipeStoreFiles(matching: { name in
            name.hasPrefix(cloudStoreName) || name.contains("\(cloudStoreName).store")
        })
    }

    @discardableResult
    private static func wipeStoreFiles(matching predicate: (String) -> Bool) -> Bool {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return false }

        var removed = false
        if let urls = try? FileManager.default.contentsOfDirectory(
            at: appSupport,
            includingPropertiesForKeys: nil
        ) {
            for url in urls {
                let name = url.lastPathComponent
                guard predicate(name) else { continue }
                try? FileManager.default.removeItem(at: url)
                removed = true
                PeakLogger.cloudKit.warning("Removed store file: \(name)")
            }
        }
        return removed
    }

    /// Full reset — only for explicit account deletion flows.
    @discardableResult
    static func wipeAllSwiftDataStores() -> Bool {
        wipeStoreFiles(matching: { name in
            name.hasSuffix(".store") || name.contains(".store-")
        })
    }
}

enum OnboardingStorage {
    private static let completedKey = "peak.onboarding.completed"
    private static let storeModeKey = "peak.datastore.mode"
    private static let cloudRecoveryKey = "peak.cloudkit.pendingRecovery"
    private static let preferLocalKey = "peak.cloudkit.preferLocal"
    private static let cloudSyncEnabledKey = "peak.cloudkit.syncEnabled"
    private static let purgeOnInstallKey = "peak.datastore.purgedOnInstall"
    private static let launchInProgressKey = "peak.launch.inProgress"

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    static var lastDataStoreMode: String? {
        get { UserDefaults.standard.string(forKey: storeModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: storeModeKey) }
    }

    static var pendingCloudRecovery: Bool {
        get { UserDefaults.standard.bool(forKey: cloudRecoveryKey) }
        set { UserDefaults.standard.set(newValue, forKey: cloudRecoveryKey) }
    }

    /// When true, skip CloudKit bootstrap and use local storage (set after a failed CloudKit load).
    static var preferLocalStore: Bool {
        get { UserDefaults.standard.bool(forKey: preferLocalKey) }
        set { UserDefaults.standard.set(newValue, forKey: preferLocalKey) }
    }

    /// CloudKit is opt-in — prevents launch aborts from uninitialized/bad CloudKit schema on device.
    static var cloudKitSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: cloudSyncEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: cloudSyncEnabledKey) }
    }

    static var didPurgeStoresOnInstall: Bool {
        get { UserDefaults.standard.bool(forKey: purgeOnInstallKey) }
        set { UserDefaults.standard.set(newValue, forKey: purgeOnInstallKey) }
    }

    /// True when the previous process exited before clearing the launch watchdog.
    static var previousLaunchDidNotComplete: Bool {
        get { UserDefaults.standard.bool(forKey: launchInProgressKey) }
        set { UserDefaults.standard.set(newValue, forKey: launchInProgressKey) }
    }

    static func markLaunchStarted() {
        previousLaunchDidNotComplete = true
    }

    static func markLaunchFinished() {
        previousLaunchDidNotComplete = false
    }

    static func markIncomplete() {
        hasCompletedOnboarding = false
    }
}

enum HealthKitAuthStorage {
    private static let key = "peak.healthkit.authorizationRequested"

    static var hasRequested: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
