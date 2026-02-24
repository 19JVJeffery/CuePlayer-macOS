import SwiftUI

struct ContentView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @EnvironmentObject var audioEngine: AudioEngine

    @State private var selectedCueID: String?
    @State private var showProjectSettings = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Playlist
            PlaylistView(selectedCueID: $selectedCueID)
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 500)
        } content: {
            // Center: Active cues + Cart player
            VStack(spacing: 0) {
                ActiveCuesView()
                Divider()
                CartPlayerView()
            }
            .navigationSplitViewColumnWidth(min: 400, ideal: 520)
        } detail: {
            // Detail: Properties inspector
            PropertiesPanel(selectedCueID: $selectedCueID)
                .navigationSplitViewColumnWidth(min: 280, ideal: 300, max: 400)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                projectTitleButton
            }
            ToolbarItemGroup(placement: .primaryAction) {
                masterVolumeControl
                stopAllButton
            }
        }
        .sheet(isPresented: $showProjectSettings) {
            ProjectSettingsSheet()
                .environmentObject(projectManager)
        }
        .navigationTitle("")
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
    }

    // MARK: - Toolbar Components

    private var projectTitleButton: some View {
        Button {
            showProjectSettings = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "theatermasks")
                    .foregroundStyle(.accent)
                Text(projectManager.project.name)
                    .font(.headline)
                if projectManager.isDirty {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Click to edit project settings")
    }

    private var masterVolumeControl: some View {
        HStack(spacing: 4) {
            Image(systemName: audioEngine.masterVolume > 0 ? "speaker.wave.2" : "speaker.slash")
                .foregroundStyle(audioEngine.masterVolume > 0 ? .primary : .red)
                .font(.system(size: 12))
            Slider(value: $audioEngine.masterVolume, in: 0...1)
                .frame(width: 80)
                .help("Master Volume")
        }
    }

    private var stopAllButton: some View {
        Button {
            audioEngine.stopAll()
        } label: {
            Label("Stop All", systemImage: "stop.fill")
                .foregroundStyle(.red)
        }
        .keyboardShortcut(.escape, modifiers: [])
        .help("Stop all playing cues (Escape)")
        .buttonStyle(.borderedProminent)
        .tint(.red.opacity(0.15))
        .disabled(audioEngine.activeCues.isEmpty)
    }

    // MARK: - Drop Handler

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.pathExtension.lowercased().isAudioExtension else { return }
                Task { @MainActor in
                    let duration = AudioFileHelper.duration(of: url)
                    let cue = AudioCue(
                        displayName: url.deletingPathExtension().lastPathComponent,
                        mediaPath: url.path,
                        duration: duration
                    )
                    cue.outPoint = duration
                    self.projectManager.project.items.append(.audio(cue))
                    self.projectManager.markDirty()
                }
            }
            handled = true
        }
        return handled
    }
}

extension String {
    var isAudioExtension: Bool {
        ["mp3", "wav", "aiff", "aif", "flac", "m4a", "ogg", "caf"].contains(self.lowercased())
    }
}

// MARK: - Project Settings Sheet

struct ProjectSettingsSheet: View {
    @EnvironmentObject var projectManager: ProjectManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Settings")
                .font(.title2.bold())

            Divider()

            LabeledContent("Show Name") {
                TextField("Show Name", text: $projectManager.project.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .onChange(of: projectManager.project.name) { _ in
                        projectManager.markDirty()
                    }
            }

            LabeledContent("Theme") {
                Picker("Theme", selection: $projectManager.project.theme.mode) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .onChange(of: projectManager.project.theme.mode) { _ in
                    projectManager.markDirty()
                }
            }

            LabeledContent("Accent Color") {
                LazyVGrid(columns: Array(repeating: .init(.fixed(24)), count: 6), spacing: 6) {
                    ForEach(presetCueColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex.nsColor))
                            .frame(width: 22, height: 22)
                            .overlay {
                                if projectManager.project.theme.accentColor == hex {
                                    Circle().stroke(Color.primary, lineWidth: 2)
                                }
                            }
                            .onTapGesture {
                                projectManager.project.theme.accentColor = hex
                                projectManager.markDirty()
                            }
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
