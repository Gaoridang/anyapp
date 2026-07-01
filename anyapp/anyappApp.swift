//
//  anyappApp.swift
//  anyapp
//
//  Created by ijaejun on 6/25/26.
//

import SwiftUI
import SwiftData

#if DEBUG
private final class RecordingSmokeAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard let modeName = ProcessInfo.processInfo.environment["RECORDING_SMOKE"],
              let mode = RecordingSmokeHarness.Mode(rawValue: modeName) else {
            return true
        }

        DispatchQueue.main.async {
            Task { @MainActor in
                let output = await RecordingSmokeHarness.run(mode)
                print(output)
                fputs(output + "\n", stderr)
                fflush(stderr)
                let success = output.contains("PASS") || output.contains("SKIP")
                exit(success ? 0 : 1)
            }
        }
        return true
    }
}
#endif

@main
struct anyappApp: App {
    #if DEBUG
    @UIApplicationDelegateAdaptor(RecordingSmokeAppDelegate.self) private var smokeAppDelegate
    #endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}