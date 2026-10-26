import SwiftUI
import SwiftData

enum AppTab {
    case saved, quickstart, settings
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsResults: [AppSettings]
    @State private var selectedTab: AppTab = .quickstart
    @State private var pendingImportDTOs: [WorkoutDTO]? = nil

    private var preferredColorScheme: ColorScheme? {
        switch settingsResults.first?.theme {
        case .light:  return .light
        case .dark:   return .dark
        default:      return nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Saved", systemImage: "star.fill", value: AppTab.saved) {
                NavigationStack {
                    SavedWorkoutsView()
                }
            }

            Tab("Quickstart", systemImage: "timer", value: AppTab.quickstart) {
                NavigationStack {
                    QuickstartView()
                }
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onOpenURL { url in
            if let dtos = DeepLinkManager.parseImportURL(url) {
                pendingImportDTOs = dtos
            }
        }
        .sheet(isPresented: Binding(
            get: { pendingImportDTOs != nil },
            set: { if !$0 { pendingImportDTOs = nil } }
        )) {
            if let dtos = pendingImportDTOs {
                ImportWorkoutsView(workouts: dtos) {
                    selectedTab = .saved
                }
            }
        }
        .onAppear {
            if settingsResults.isEmpty {
                modelContext.insert(AppSettings())
            }
        }
    }
}
