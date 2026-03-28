import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        TabView(selection: $model.selectedTab) {
            NavigationStack {
                ProgramScreen()
            }
            .tabItem {
                Label("Program", systemImage: "calendar")
            }
            .tag(AppTab.program)

            NavigationStack {
                WorkoutScreen()
            }
            .tabItem {
                Label("Workout", systemImage: "dumbbell.fill")
            }
            .tag(AppTab.workout)

            NavigationStack {
                DashboardScreen()
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.xyaxis.line")
            }
            .tag(AppTab.dashboard)

            NavigationStack {
                ArchiveScreen()
            }
            .tabItem {
                Label("Archive", systemImage: "archivebox")
            }
            .tag(AppTab.archive)
        }
        .onAppear {
            model.refreshTodaySelectionIfNeeded()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
