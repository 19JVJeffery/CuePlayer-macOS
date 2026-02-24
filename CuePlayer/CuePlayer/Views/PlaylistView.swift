import SwiftUI
import UniformTypeIdentifiers

struct PlaylistView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @EnvironmentObject var audioEngine: AudioEngine
    @Binding var selectedCueID: String?

    @State private var showAddMenu = false
    @State private var expandedGroups: Set<String> = []
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            cueList
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Playlist")
                .font(.headline)
            Spacer()
            Button {
                projectManager.importAudioFiles()
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            .help("Import audio files")
            .buttonStyle(.plain)

            Menu {
                Button("Add Audio Cue") { projectManager.addAudioCue() }
                Button("Add Group") { projectManager.addGroup() }
                Divider()
                Button("Import Audio Files…") { projectManager.importAudioFiles() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Add cue or group")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Cue List

    @ViewBuilder
    private var cueList: some View {
        if projectManager.project.items.isEmpty {
            emptyState
        } else {
            List(selection: $selectedCueID) {
                ForEach(Array(projectManager.project.items.enumerated()), id: \.element.id) { index, item in
                    cueItemRow(item: item, index: index)
                }
                .onMove { from, to in
                    projectManager.project.items.move(fromOffsets: from, toOffset: to)
                    projectManager.markDirty()
                }
                .onDelete { offsets in
                    projectManager.project.items.remove(atOffsets: offsets)
                    projectManager.markDirty()
                }
            }
            .listStyle(.sidebar)
            .overlay(dropOverlay)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Cues Yet")
                .font(.title3.bold())
            Text("Drop audio files here or press + to add cues")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Import Audio Files…") {
                projectManager.importAudioFiles()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
        .overlay(dropOverlay)
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
            .padding(4)
            .opacity(isTargeted ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isTargeted)
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func cueItemRow(item: CueItem, index: Int) -> some View {
        switch item {
        case .audio(let cue):
            CueRow(
                cue: cue,
                isSelected: selectedCueID == cue.id,
                isPlaying: audioEngine.isPlaying(cue.id)
            )
            .tag(cue.id)
            .onTapGesture { selectedCueID = cue.id }
            .contextMenu { audioCueContextMenu(cue: cue) }
            .draggable(CueDragItem(cueID: cue.id, displayName: cue.displayName))

        case .group(let group):
            GroupRow(
                group: group,
                selectedCueID: $selectedCueID,
                isExpanded: expandedGroups.contains(group.id)
            ) {
                toggleGroup(group.id)
            }
            .tag(group.id)
            .contextMenu { groupContextMenu(group: group) }
        }
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func audioCueContextMenu(cue: AudioCue) -> some View {
        Button("Play") { audioEngine.playCue(cue, project: projectManager.project) }
        Button("Stop") { audioEngine.stopCue(id: cue.id) }
        Divider()
        Button("Duplicate") {
            let copy = projectManager.project.duplicateCue(cue)
            projectManager.project.items.append(.audio(copy))
            projectManager.markDirty()
        }
        Button("Add to Cart…") {
            // Show cart assignment dialog
            CartAssignmentHelper.showPicker(cue: cue, projectManager: projectManager)
        }
        Divider()
        Button("Delete", role: .destructive) {
            projectManager.project.removeCue(id: cue.id)
            projectManager.markDirty()
        }
    }

    @ViewBuilder
    private func groupContextMenu(group: GroupCue) -> some View {
        Button("Add Audio Cue to Group") {
            projectManager.addAudioCue(toGroup: group)
        }
        Button("Import Audio Files into Group…") {
            projectManager.importAudioFiles(into: group)
        }
        Divider()
        Button("Delete Group", role: .destructive) {
            projectManager.project.removeCue(id: group.id)
            projectManager.markDirty()
        }
    }

    // MARK: - Helpers

    private func toggleGroup(_ id: String) {
        if expandedGroups.contains(id) {
            expandedGroups.remove(id)
        } else {
            expandedGroups.insert(id)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.pathExtension.isAudioExtension else { return }
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

// MARK: - Drag Item

struct CueDragItem: Transferable, Codable {
    var cueID: String
    var displayName: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .init(exportedAs: "com.cueplayer.cue"))
    }
}

// MARK: - Cue Row

struct CueRow: View {
    @ObservedObject var cue: AudioCue
    var isSelected: Bool
    var isPlaying: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(cue.color.nsColor))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(cue.displayName)
                    .font(.system(size: 13, weight: isPlaying ? .semibold : .regular))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if !cue.mediaFileName.isEmpty {
                        Image(systemName: "waveform")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(cue.mediaFileName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No file assigned")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(cue.duration.formattedTime)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Group Row

struct GroupRow: View {
    @ObservedObject var group: GroupCue
    @Binding var selectedCueID: String?
    @EnvironmentObject var projectManager: ProjectManager
    @EnvironmentObject var audioEngine: AudioEngine
    var isExpanded: Bool
    var onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack(spacing: 6) {
                Button {
                    onToggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 14)
                }
                .buttonStyle(.plain)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(group.color.nsColor))
                    .frame(width: 4, height: 24)

                Image(systemName: "folder.fill")
                    .foregroundStyle(Color(group.color.nsColor))
                    .font(.system(size: 12))

                Text(group.displayName)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text("\(group.children.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
            .padding(.vertical, 4)

            // Children (when expanded)
            if isExpanded {
                ForEach(Array(group.children.enumerated()), id: \.element.id) { idx, child in
                    if case .audio(let cue) = child {
                        CueRow(
                            cue: cue,
                            isSelected: selectedCueID == cue.id,
                            isPlaying: audioEngine.isPlaying(cue.id)
                        )
                        .tag(cue.id)
                        .padding(.leading, 24)
                        .onTapGesture { selectedCueID = cue.id }
                    }
                }
                .onMove { from, to in
                    group.children.move(fromOffsets: from, toOffset: to)
                    projectManager.markDirty()
                }
            }
        }
    }
}

// MARK: - Cart Assignment Helper

enum CartAssignmentHelper {
    static func showPicker(cue: AudioCue, projectManager: ProjectManager) {
        // Show a simple alert asking for slot number
        let alert = NSAlert()
        alert.messageText = "Assign to Cart"
        alert.informativeText = "Enter cart slot number (1-16) for \"\(cue.displayName)\":"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 80, height: 22))
        field.stringValue = ""
        alert.accessoryView = field
        alert.addButton(withTitle: "Assign")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let slot = Int(field.stringValue), (1...16).contains(slot) {
            projectManager.assignToCart(cue: cue, slot: slot - 1)
        }
    }
}
