//
//  anyappApp.swift
//  anyapp
//
//  Created by ijaejun on 6/25/26.
//

import SwiftUI
import SwiftData

#if DEBUG
private final class LiveFinishSmokeAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard ProcessInfo.processInfo.environment["LIVE_FINISH_SMOKE"] == "1" else {
            return true
        }

        DispatchQueue.main.async {
            Task { @MainActor in
                let output = await LiveFinishSmokeVerification.run()
                print(output)
                fputs(output + "\n", stderr)
                fflush(stderr)
                let ok = output.contains("LIVE_INTEGRATED_PASS") || output.contains("LIVE_SKIP")
                exit(ok ? 0 : 1)
            }
        }
        return true
    }
}
#endif

@main
struct anyappApp: App {
    #if DEBUG
    @UIApplicationDelegateAdaptor(LiveFinishSmokeAppDelegate.self) private var liveFinishSmokeDelegate
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