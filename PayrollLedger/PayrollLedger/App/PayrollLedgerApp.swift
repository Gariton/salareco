import CoreData
import SwiftData
import SwiftUI
import UIKit
#if DEBUG
import _SwiftData_CoreData
#endif

@main
struct PayrollLedgerApp: App {
    @UIApplicationDelegateAdaptor(PayrollAppDelegate.self) private var appDelegate

    private let modelContainer = Self.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: PayrollSchemaV5.self)
        let cloudKitConfiguration = ModelConfiguration(
            "PayrollLedger",
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )
        let localConfiguration = ModelConfiguration(
            "PayrollLedger",
            schema: schema,
            cloudKitDatabase: .none
        )

        do {
            initializeCloudKitDevelopmentSchemaIfNeeded(schema: schema)
            return try ModelContainer(
                for: schema,
                migrationPlan: PayrollMigrationPlan.self,
                configurations: [cloudKitConfiguration]
            )
        } catch {
            let fallbackMessage =
                "CloudKit-backed SwiftData container could not be created. Falling back to local storage. Error: \(error)"
            assertionFailure(fallbackMessage)
            print(fallbackMessage)

            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: PayrollMigrationPlan.self,
                    configurations: [localConfiguration]
                )
            } catch {
                fatalError("Unable to create the payroll model container: \(error)")
            }
        }
    }

    private static var cloudKitContainerIdentifier: String {
        if let configuredIdentifier = Bundle.main.object(
            forInfoDictionaryKey: "PayrollCloudKitContainerIdentifier"
        ) as? String, !configuredIdentifier.isEmpty {
            return configuredIdentifier
        }

        return "iCloud.\(Bundle.main.bundleIdentifier ?? "com.example.PayrollLedger")"
    }

    private static func initializeCloudKitDevelopmentSchemaIfNeeded(
        schema: Schema
    ) {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["PAYROLL_INIT_CLOUDKIT_SCHEMA"] == "1" else {
            return
        }

        let containerIdentifier = cloudKitContainerIdentifier
        guard !containerIdentifier.isEmpty else {
            return
        }

        do {
            try autoreleasepool {
                let temporaryStoreURL = FileManager.default.temporaryDirectory
                    .appending(path: "PayrollLedgerCloudKitBootstrap-\(UUID().uuidString).store")
                let description = NSPersistentStoreDescription(url: temporaryStoreURL)
                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
                description.cloudKitContainerOptions = options
                description.shouldAddStoreAsynchronously = false

                let managedObjectModel: NSManagedObjectModel?
                if #available(iOS 26.0, *) {
                    managedObjectModel = NSManagedObjectModel.makeManagedObjectModel(for: schema)
                } else {
                    managedObjectModel = legacyManagedObjectModel(for: schema)
                }

                guard let managedObjectModel else {
                    throw NSError(
                        domain: "PayrollLedger.CloudKitBootstrap",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to generate a managed object model for CloudKit bootstrap."]
                    )
                }

                let container = NSPersistentCloudKitContainer(
                    name: "PayrollLedgerCloudKitBootstrap",
                    managedObjectModel: managedObjectModel
                )
                container.persistentStoreDescriptions = [description]

                var loadError: Error?
                container.loadPersistentStores { _, error in
                    loadError = error
                }

                if let loadError {
                    throw loadError
                }

                try container.initializeCloudKitSchema()
            }
        } catch {
            print("CloudKit development schema initialization was skipped: \(error)")
        }
        #endif
    }

    @available(iOS, introduced: 17.0, obsoleted: 26.0)
    private static func legacyManagedObjectModel(for schema: Schema) -> NSManagedObjectModel? {
        NSManagedObjectModel().makeManagedObjectModel(for: schema)
    }
}

enum PayrollHomeQuickAction: String, CaseIterable {
    case createSalaryRecord = "create-salary-record"
    case createBonusRecord = "create-bonus-record"
    case createTemplate = "create-template"
    case openTemplates = "open-templates"

    static func action(for shortcutItem: UIApplicationShortcutItem) -> PayrollHomeQuickAction? {
        allCases.first { shortcutItem.type.hasSuffix(".\($0.rawValue)") }
    }
}

@MainActor
final class PayrollQuickActionDispatcher {
    static let shared = PayrollQuickActionDispatcher()
    static let notificationName = Notification.Name("PayrollHomeQuickAction")

    private var pendingAction: PayrollHomeQuickAction?

    func dispatch(_ action: PayrollHomeQuickAction) {
        pendingAction = action
        NotificationCenter.default.post(
            name: Self.notificationName,
            object: nil,
            userInfo: ["action": action]
        )
    }

    func consumePendingAction() -> PayrollHomeQuickAction? {
        defer {
            pendingAction = nil
        }

        return pendingAction
    }
}

final class PayrollAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AdMobConfiguration.start()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )

        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = PayrollSceneDelegate.self
        }

        return configuration
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(Self.handle(shortcutItem))
    }

    static func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = PayrollHomeQuickAction.action(for: shortcutItem) else {
            return false
        }

        Task { @MainActor in
            PayrollQuickActionDispatcher.shared.dispatch(action)
        }

        return true
    }
}

final class PayrollSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcutItem = connectionOptions.shortcutItem {
            _ = PayrollAppDelegate.handle(shortcutItem)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(PayrollAppDelegate.handle(shortcutItem))
    }
}
