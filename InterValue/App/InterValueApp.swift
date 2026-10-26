import SwiftUI
import SwiftData

@main
struct InterValueApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Workout.self, WorkoutInterval.self, AppSettings.self])
    }
}
