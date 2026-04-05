import SwiftUI

struct MainWindow: View {
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            switch selectedTab {
            case .dashboard:
                DashboardView()
            case .dictation:
                DictationView()
            case .models:
                ModelManagementView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case dictation = "Dictation"
    case models = "Models"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .dictation: return "mic.fill"
        case .models: return "brain"
        case .settings: return "gear"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        List(AppTab.allCases, id: \.self, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(180)
    }
}
