import Foundation
import AppKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Project Model

final class Project: ObservableObject, Codable {
    @Published var name: String
    @Published var items: [CueItem]
    @Published var cartItems: [CartItem]
    @Published var theme: AppTheme
    var createdAt: String
    var lastModified: String

    enum CodingKeys: String, CodingKey {
        case name, items, cartItems, theme, createdAt, lastModified
    }

    init(name: String = "Untitled Show") {
        self.name = name
        self.items = []
        self.cartItems = []
        self.theme = AppTheme()
        let iso = ISO8601DateFormatter()
        let now = iso.string(from: Date())
        self.createdAt = now
        self.lastModified = now
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name         = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled Show"
        items        = try c.decodeIfPresent([CueItem].self, forKey: .items) ?? []
        cartItems    = try c.decodeIfPresent([CartItem].self, forKey: .cartItems) ?? []
        theme        = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? AppTheme()
        createdAt    = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        lastModified = try c.decodeIfPresent(String.self, forKey: .lastModified) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name,         forKey: .name)
        try c.encode(items,        forKey: .items)
        try c.encode(cartItems,    forKey: .cartItems)
        try c.encode(theme,        forKey: .theme)
        try c.encode(createdAt,    forKey: .createdAt)
        try c.encode(lastModified, forKey: .lastModified)
    }

    func touchModified() {
        lastModified = ISO8601DateFormatter().string(from: Date())
    }

    // MARK: Flat cue lookup

    func allAudioCues() -> [AudioCue] {
        var result: [AudioCue] = []
        func walk(_ list: [CueItem]) {
            for item in list {
                switch item {
                case .audio(let c): result.append(c)
                case .group(let g): walk(g.children)
                }
            }
        }
        walk(items)
        return result
    }

    func findAudioCue(byID uuid: String) -> AudioCue? {
        return allAudioCues().first { $0.id == uuid }
    }

    func findNextAudioCue(after uuid: String) -> AudioCue? {
        let all = allAudioCues()
        guard let idx = all.firstIndex(where: { $0.id == uuid }),
              idx + 1 < all.count else { return nil }
        return all[idx + 1]
    }

    // MARK: Remove cue helpers

    func removeCue(id: String) {
        items = removeCueFromList(items, id: id)
    }

    private func removeCueFromList(_ list: [CueItem], id: String) -> [CueItem] {
        var result: [CueItem] = []
        for item in list {
            switch item {
            case .audio(let c):
                if c.id != id { result.append(item) }
            case .group(let g):
                if g.id == id { continue }
                g.children = removeCueFromList(g.children, id: id)
                result.append(.group(g))
            }
        }
        return result
    }

    // MARK: Duplicate cue

    func duplicateCue(_ original: AudioCue) -> AudioCue {
        let copy = AudioCue(
            displayName: original.displayName + " (copy)",
            mediaPath: original.mediaPath,
            duration: original.duration
        )
        copy.color = original.color
        copy.inPoint = original.inPoint
        copy.outPoint = original.outPoint
        copy.volume = original.volume
        copy.endBehavior = original.endBehavior
        copy.startBehavior = original.startBehavior
        copy.duckingBehavior = original.duckingBehavior
        copy.fadeOutDuration = original.fadeOutDuration
        copy.playFade = original.playFade
        copy.stopFade = original.stopFade
        copy.crossFade = original.crossFade
        copy.notes = original.notes
        return copy
    }
}

// MARK: - Project Manager

@MainActor
final class ProjectManager: ObservableObject {
    @Published var project: Project = Project()
    @Published var projectFileURL: URL?
    @Published var isDirty: Bool = false
    @Published var recentProjects: [URL] = []

    private let recentProjectsKey = "recentProjects"

    init() {
        loadRecentProjects()
    }

    // MARK: - New Project

    func newProject() {
        project = Project()
        projectFileURL = nil
        isDirty = false
    }

    // MARK: - Open Project

    func openProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "cueshow")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open CuePlayer Show"

        if panel.runModal() == .OK, let url = panel.url {
            loadProject(from: url)
        }
    }

    func loadProject(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode(Project.self, from: data)
            project = loaded
            projectFileURL = url
            isDirty = false
            addRecentProject(url)
        } catch {
            showError("Failed to open project: \(error.localizedDescription)")
        }
    }

    // MARK: - Save Project

    func saveProject() {
        guard let url = projectFileURL else {
            saveProjectAs()
            return
        }
        writeToDisk(url: url)
    }

    func saveProjectAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "cueshow")!]
        panel.nameFieldStringValue = project.name + ".cueshow"
        panel.title = "Save CuePlayer Show"

        if panel.runModal() == .OK, let url = panel.url {
            projectFileURL = url
            project.name = url.deletingPathExtension().lastPathComponent
            writeToDisk(url: url)
            addRecentProject(url)
        }
    }

    private func writeToDisk(url: URL) {
        do {
            project.touchModified()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(project)
            try data.write(to: url, options: .atomic)
            isDirty = false
        } catch {
            showError("Failed to save project: \(error.localizedDescription)")
        }
    }

    func markDirty() {
        isDirty = true
    }

    // MARK: - Recent Projects

    private func loadRecentProjects() {
        let paths = UserDefaults.standard.stringArray(forKey: recentProjectsKey) ?? []
        recentProjects = paths.compactMap { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func addRecentProject(_ url: URL) {
        recentProjects.removeAll { $0 == url }
        recentProjects.insert(url, at: 0)
        if recentProjects.count > 10 { recentProjects = Array(recentProjects.prefix(10)) }
        UserDefaults.standard.set(recentProjects.map { $0.path }, forKey: recentProjectsKey)
    }

    // MARK: - Import Audio Files

    func importAudioFiles(into parentGroup: GroupCue? = nil) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff, UTType(filenameExtension: "flac") ?? .audio, .mpeg4Audio]
        panel.title = "Import Audio Files"

        if panel.runModal() == .OK {
            let urls = panel.urls
            var newCues: [CueItem] = []
            for url in urls {
                let duration = AudioFileHelper.duration(of: url)
                let cue = AudioCue(displayName: url.deletingPathExtension().lastPathComponent,
                                   mediaPath: url.path,
                                   duration: duration)
                cue.outPoint = duration
                newCues.append(.audio(cue))
            }
            if let group = parentGroup {
                group.children.append(contentsOf: newCues)
            } else {
                project.items.append(contentsOf: newCues)
            }
            markDirty()
        }
    }

    // MARK: - Add Cue

    func addAudioCue(toGroup group: GroupCue? = nil) {
        let cue = AudioCue(displayName: "New Cue \(project.allAudioCues().count + 1)")
        if let g = group {
            g.children.append(.audio(cue))
        } else {
            project.items.append(.audio(cue))
        }
        markDirty()
    }

    func addGroup() {
        let group = GroupCue(displayName: "New Group \(project.items.filter { $0.isGroup }.count + 1)")
        project.items.append(.group(group))
        markDirty()
    }

    // MARK: - Cart Management

    func assignToCart(cue: AudioCue, slot: Int) {
        project.cartItems.removeAll { $0.slot == slot }
        let item = CartItem(slot: slot, itemUUID: cue.id, displayName: cue.displayName, color: cue.color)
        project.cartItems.append(item)
        markDirty()
    }

    func removeFromCart(slot: Int) {
        project.cartItems.removeAll { $0.slot == slot }
        markDirty()
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}

// MARK: - Audio File Helper

enum AudioFileHelper {
    static func duration(of url: URL) -> Double {
        guard let file = try? AVAudioFile(forReading: url) else { return 0 }
        return Double(file.length) / file.processingFormat.sampleRate
    }
}
