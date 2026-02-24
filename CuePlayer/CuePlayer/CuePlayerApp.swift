import SwiftUI

@main
struct CuePlayerApp: App {
    @StateObject private var projectManager = ProjectManager()
    @StateObject private var audioEngine    = AudioEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectManager)
                .environmentObject(audioEngine)
                .frame(minWidth: 1100, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands(projectManager: projectManager, audioEngine: audioEngine)
        }

        Settings {
            SettingsView()
                .environmentObject(projectManager)
        }
    }
}

// MARK: - App Commands

struct AppCommands: Commands {
    let projectManager: ProjectManager
    let audioEngine: AudioEngine

    var body: some Commands {
        // File menu
        CommandGroup(replacing: .newItem) {
            Button("New Show") {
                Task { @MainActor in projectManager.newProject() }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open Show…") {
                Task { @MainActor in projectManager.openProject() }
            }
            .keyboardShortcut("o", modifiers: .command)

            if !projectManager.recentProjects.isEmpty {
                Menu("Open Recent") {
                    ForEach(projectManager.recentProjects, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            Task { @MainActor in projectManager.loadProject(from: url) }
                        }
                    }
                    Divider()
                    Button("Clear Menu") {
                        projectManager.recentProjects = []
                    }
                }
            }

            Divider()

            Button("Save") {
                Task { @MainActor in projectManager.saveProject() }
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Save As…") {
                Task { @MainActor in projectManager.saveProjectAs() }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            Button("Import Audio Files…") {
                Task { @MainActor in projectManager.importAudioFiles() }
            }
            .keyboardShortcut("i", modifiers: .command)
        }

        // Playback menu
        CommandMenu("Playback") {
            Button("Stop All Cues") {
                Task { @MainActor in audioEngine.stopAll() }
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button("Toggle Master Mute") {
                Task { @MainActor in
                    audioEngine.masterVolume = audioEngine.masterVolume > 0 ? 0 : 1
                }
            }
            .keyboardShortcut("m", modifiers: .command)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var projectManager: ProjectManager

    var body: some View {
        Form {
            Section("Appearance") {
                Text("Theme and accent color are configured per-project in the Project Settings panel.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 420, height: 160)
    }
}
