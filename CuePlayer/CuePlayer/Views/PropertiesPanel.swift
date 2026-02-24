import SwiftUI
import UniformTypeIdentifiers

struct PropertiesPanel: View {
    @Binding var selectedCueID: String?
    @EnvironmentObject var projectManager: ProjectManager
    @EnvironmentObject var audioEngine: AudioEngine

    var selectedAudioCue: AudioCue? {
        guard let id = selectedCueID else { return nil }
        return projectManager.project.findAudioCue(byID: id)
    }

    var selectedGroupCue: GroupCue? {
        guard let id = selectedCueID else { return nil }
        func findGroup(_ items: [CueItem]) -> GroupCue? {
            for item in items {
                if case .group(let g) = item {
                    if g.id == id { return g }
                    if let found = findGroup(g.children) { return found }
                }
            }
            return nil
        }
        return findGroup(projectManager.project.items)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let cue = selectedAudioCue {
                AudioCueProperties(cue: cue)
                    .environmentObject(projectManager)
                    .environmentObject(audioEngine)
            } else if let group = selectedGroupCue {
                GroupCueProperties(group: group)
                    .environmentObject(projectManager)
            } else {
                nothingSelected
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text("Inspector")
                .font(.headline)
            Spacer()
            if let cue = selectedAudioCue {
                Button {
                    audioEngine.playCue(cue, project: projectManager.project)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color(cue.color.nsColor))
                .help("Play \"\(cue.displayName)\"")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var nothingSelected: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "info.circle")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Select a cue to inspect")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Audio Cue Properties

struct AudioCueProperties: View {
    @ObservedObject var cue: AudioCue
    @EnvironmentObject var projectManager: ProjectManager
    @EnvironmentObject var audioEngine: AudioEngine

    @State private var expandedSections: Set<String> = ["basic", "timing", "playback", "behaviors", "notes"]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                basicSection
                Divider()
                timingSection
                Divider()
                playbackSection
                Divider()
                behaviorsSection
                Divider()
                notesSection
            }
        }
    }

    // MARK: - Basic

    private var basicSection: some View {
        PropertySection(title: "Basic", icon: "info.circle", key: "basic", expanded: $expandedSections) {
            PropertyRow(label: "Name") {
                TextField("Cue name", text: $cue.displayName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: cue.displayName) { projectManager.markDirty() }
            }

            PropertyRow(label: "File") {
                HStack {
                    Text(cue.mediaFileName.isEmpty ? "No file" : cue.mediaFileName)
                        .font(.system(size: 11))
                        .foregroundStyle(cue.mediaFileName.isEmpty ? .tertiary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose…") {
                        pickAudioFile()
                    }
                    .controlSize(.small)
                }
            }

            PropertyRow(label: "Color") {
                LazyVGrid(columns: Array(repeating: .init(.fixed(18)), count: 6), spacing: 4) {
                    ForEach(presetCueColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex.nsColor))
                            .frame(width: 16, height: 16)
                            .overlay {
                                if cue.color == hex {
                                    Circle().stroke(Color.primary, lineWidth: 1.5)
                                }
                            }
                            .onTapGesture {
                                cue.color = hex
                                projectManager.markDirty()
                            }
                    }
                }
            }
        }
    }

    // MARK: - Timing

    private var timingSection: some View {
        PropertySection(title: "Timing", icon: "clock", key: "timing", expanded: $expandedSections) {
            // Waveform
            if !cue.mediaPath.isEmpty {
                WaveformView(
                    audioURL: URL(fileURLWithPath: cue.mediaPath),
                    inPoint: cue.inPoint,
                    outPoint: cue.outPoint > 0 ? cue.outPoint : cue.duration,
                    duration: cue.duration,
                    accentColor: Color(cue.color.nsColor)
                )
                .frame(height: 48)
                .cornerRadius(4)
            }

            PropertyRow(label: "Duration") {
                Text(cue.duration.formattedTime)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            PropertyRow(label: "In Point") {
                HStack {
                    Slider(value: $cue.inPoint, in: 0...max(cue.duration, 0.001), step: 0.1)
                        .onChange(of: cue.inPoint) { _, newValue in
                            if newValue >= cue.outPoint { cue.inPoint = max(cue.outPoint - 0.1, 0) }
                            projectManager.markDirty()
                        }
                    Text(cue.inPoint.formattedTime)
                        .font(.system(size: 10).monospacedDigit())
                        .frame(width: 50, alignment: .trailing)
                }
            }

            PropertyRow(label: "Out Point") {
                HStack {
                    Slider(value: $cue.outPoint, in: 0...max(cue.duration, 0.001), step: 0.1)
                        .onChange(of: cue.outPoint) { _, newValue in
                            if newValue <= cue.inPoint { cue.outPoint = min(cue.inPoint + 0.1, cue.duration) }
                            projectManager.markDirty()
                        }
                    Text(cue.outPoint.formattedTime)
                        .font(.system(size: 10).monospacedDigit())
                        .frame(width: 50, alignment: .trailing)
                }
            }

            PropertyRow(label: "Effective") {
                Text(max(cue.outPoint - cue.inPoint, 0).formattedTime)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Playback

    private var playbackSection: some View {
        PropertySection(title: "Playback", icon: "speaker.wave.2", key: "playback", expanded: $expandedSections) {
            PropertyRow(label: "Volume") {
                HStack {
                    Image(systemName: "speaker")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Slider(value: $cue.volume, in: 0...1.5)
                        .onChange(of: cue.volume) { projectManager.markDirty() }
                    Image(systemName: "speaker.wave.3")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", cue.volume * 100))
                        .font(.system(size: 10).monospacedDigit())
                        .frame(width: 36, alignment: .trailing)
                }
            }

            PropertyRow(label: "Fade In") {
                HStack {
                    Slider(value: $cue.playFade, in: 0...10, step: 0.1)
                        .onChange(of: cue.playFade) { projectManager.markDirty() }
                    Text(cue.playFade > 0 ? "\(String(format: "%.1f", cue.playFade))s" : "Off")
                        .font(.system(size: 10).monospacedDigit())
                        .frame(width: 36, alignment: .trailing)
                }
            }

            PropertyRow(label: "Fade Out") {
                HStack {
                    Slider(value: $cue.stopFade, in: 0...10, step: 0.1)
                        .onChange(of: cue.stopFade) { projectManager.markDirty() }
                    Text(cue.stopFade > 0 ? "\(String(format: "%.1f", cue.stopFade))s" : "Off")
                        .font(.system(size: 10).monospacedDigit())
                        .frame(width: 36, alignment: .trailing)
                }
            }

            PropertyRow(label: "Stop Fade") {
                HStack {
                    Slider(value: $cue.fadeOutDuration, in: 0...10, step: 0.1)
                        .onChange(of: cue.fadeOutDuration) { projectManager.markDirty() }
                    Text("\(String(format: "%.1f", cue.fadeOutDuration))s")
                        .font(.system(size: 10).monospacedDigit())
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Behaviors

    private var behaviorsSection: some View {
        PropertySection(title: "Behaviors", icon: "arrow.triangle.branch", key: "behaviors", expanded: $expandedSections) {
            // Ducking
            PropertyRow(label: "Ducking") {
                Picker("", selection: $cue.duckingBehavior.mode) {
                    ForEach(DuckingBehavior.Mode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .onChange(of: cue.duckingBehavior.mode) { projectManager.markDirty() }
            }

            if cue.duckingBehavior.mode == .duckOthers {
                PropertyRow(label: "Duck Level") {
                    HStack {
                        Slider(value: $cue.duckingBehavior.duckLevel, in: 0...1)
                            .onChange(of: cue.duckingBehavior.duckLevel) { projectManager.markDirty() }
                        Text(String(format: "%.0f%%", cue.duckingBehavior.duckLevel * 100))
                            .font(.system(size: 10).monospacedDigit())
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            // End Behavior
            PropertyRow(label: "On End") {
                Picker("", selection: $cue.endBehavior.action) {
                    ForEach(EndBehavior.Action.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .onChange(of: cue.endBehavior.action) { projectManager.markDirty() }
            }

            // Start Behavior
            PropertyRow(label: "On Start") {
                Picker("", selection: $cue.startBehavior.action) {
                    ForEach(StartBehavior.Action.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .onChange(of: cue.startBehavior.action) { projectManager.markDirty() }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        PropertySection(title: "Notes", icon: "note.text", key: "notes", expanded: $expandedSections) {
            TextEditor(text: $cue.notes)
                .font(.system(size: 11))
                .frame(minHeight: 60, maxHeight: 120)
                .padding(4)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
                .onChange(of: cue.notes) { projectManager.markDirty() }
        }
    }

    // MARK: - Pick File

    private func pickAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff, UTType(filenameExtension: "flac") ?? .audio, .mpeg4Audio]
        panel.title = "Choose Audio File"
        if panel.runModal() == .OK, let url = panel.url {
            cue.mediaPath = url.path
            cue.mediaFileName = url.lastPathComponent
            cue.duration = AudioFileHelper.duration(of: url)
            if cue.outPoint == 0 { cue.outPoint = cue.duration }
            projectManager.markDirty()
        }
    }
}

// MARK: - Group Cue Properties

struct GroupCueProperties: View {
    @ObservedObject var group: GroupCue
    @EnvironmentObject var projectManager: ProjectManager
    @State private var expandedSections: Set<String> = ["basic", "behaviors", "notes"]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                basicGroupSection
                Divider()
                behaviorGroupSection
                Divider()
                notesGroupSection
            }
        }
    }

    private var basicGroupSection: some View {
        PropertySection(title: "Basic", icon: "folder", key: "basic", expanded: $expandedSections) {
            PropertyRow(label: "Name") {
                TextField("Group name", text: $group.displayName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: group.displayName) { projectManager.markDirty() }
            }
            PropertyRow(label: "Color") {
                LazyVGrid(columns: Array(repeating: .init(.fixed(18)), count: 6), spacing: 4) {
                    ForEach(presetCueColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex.nsColor))
                            .frame(width: 16, height: 16)
                            .overlay {
                                if group.color == hex { Circle().stroke(Color.primary, lineWidth: 1.5) }
                            }
                            .onTapGesture { group.color = hex; projectManager.markDirty() }
                    }
                }
            }
            PropertyRow(label: "Items") {
                Text("\(group.children.count) cues")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
            }
        }
    }

    private var behaviorGroupSection: some View {
        PropertySection(title: "Behaviors", icon: "arrow.triangle.branch", key: "behaviors", expanded: $expandedSections) {
            PropertyRow(label: "Start Mode") {
                Picker("", selection: $group.startBehavior.action) {
                    Text("Play First").tag(GroupStartBehavior.Action.playFirst)
                    Text("Play All").tag(GroupStartBehavior.Action.playAll)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .onChange(of: group.startBehavior.action) { projectManager.markDirty() }
            }
            PropertyRow(label: "On End") {
                Picker("", selection: $group.endBehavior.action) {
                    ForEach(EndBehavior.Action.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .onChange(of: group.endBehavior.action) { projectManager.markDirty() }
            }
        }
    }

    private var notesGroupSection: some View {
        PropertySection(title: "Notes", icon: "note.text", key: "notes", expanded: $expandedSections) {
            TextEditor(text: $group.notes)
                .font(.system(size: 11))
                .frame(minHeight: 60, maxHeight: 120)
                .padding(4)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
                .onChange(of: group.notes) { projectManager.markDirty() }
        }
    }
}

// MARK: - Property Section Component

struct PropertySection<Content: View>: View {
    var title: String
    var icon: String
    var key: String
    @Binding var expanded: Set<String>
    @ViewBuilder var content: () -> Content

    var isExpanded: Bool { expanded.contains(key) }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isExpanded { expanded.remove(key) } else { expanded.insert(key) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .frame(width: 14)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.secondary.opacity(0.06))

            if isExpanded {
                VStack(spacing: 8) {
                    content()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }
}

// MARK: - Property Row Component

struct PropertyRow<Content: View>: View {
    var label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .trailing)
            content()
        }
    }
}

// MARK: - Display Name Extensions

extension DuckingBehavior.Mode {
    var displayName: String {
        switch self {
        case .stopAll:    return "Stop All"
        case .noDucking:  return "No Ducking"
        case .duckOthers: return "Duck Others"
        }
    }
}

extension EndBehavior.Action {
    var displayName: String {
        switch self {
        case .nothing:  return "Nothing"
        case .next:     return "Play Next"
        case .gotoItem: return "Go To…"
        case .loop:     return "Loop"
        }
    }
}

extension StartBehavior.Action {
    var displayName: String {
        switch self {
        case .nothing:   return "Nothing"
        case .playNext:  return "Play Next"
        case .playItem:  return "Play Specific…"
        }
    }
}
