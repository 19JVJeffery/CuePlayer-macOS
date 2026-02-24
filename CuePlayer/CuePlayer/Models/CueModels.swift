import Foundation
import AppKit

// MARK: - End Behavior

struct EndBehavior: Codable, Equatable {
    enum Action: String, Codable, CaseIterable {
        case nothing    = "nothing"
        case next       = "next"
        case gotoItem   = "goto-item"
        case loop       = "loop"
    }
    var action: Action = .next
    var targetUUID: String?

    init(action: Action = .next, targetUUID: String? = nil) {
        self.action = action
        self.targetUUID = targetUUID
    }
}

// MARK: - Start Behavior

struct StartBehavior: Codable, Equatable {
    enum Action: String, Codable, CaseIterable {
        case nothing    = "nothing"
        case playNext   = "play-next"
        case playItem   = "play-item"
    }
    var action: Action = .nothing
    var targetUUID: String?

    init(action: Action = .nothing, targetUUID: String? = nil) {
        self.action = action
        self.targetUUID = targetUUID
    }
}

// MARK: - Group Start Behavior

struct GroupStartBehavior: Codable, Equatable {
    enum Action: String, Codable, CaseIterable {
        case playFirst  = "play-first"
        case playAll    = "play-all"
    }
    var action: Action = .playFirst
}

// MARK: - Ducking Behavior

struct DuckingBehavior: Codable, Equatable {
    enum Mode: String, Codable, CaseIterable {
        case stopAll    = "stop-all"
        case noDucking  = "no-ducking"
        case duckOthers = "duck-others"
    }
    var mode: Mode = .stopAll
    var duckLevel: Double = 0.2
    var duckFadeIn: Double = 0.25
    var duckFadeOut: Double = 1.0
}

// MARK: - Audio Cue

final class AudioCue: ObservableObject, Identifiable, Codable {
    var id: String
    @Published var displayName: String
    @Published var color: String
    var mediaFileName: String
    var mediaPath: String
    @Published var inPoint: Double
    @Published var outPoint: Double
    @Published var volume: Double
    @Published var endBehavior: EndBehavior
    @Published var startBehavior: StartBehavior
    @Published var duckingBehavior: DuckingBehavior
    var duration: Double
    @Published var fadeOutDuration: Double
    @Published var playFade: Double
    @Published var stopFade: Double
    @Published var crossFade: Double
    @Published var notes: String

    enum CodingKeys: String, CodingKey {
        case id, displayName, color, mediaFileName, mediaPath
        case inPoint, outPoint, volume, endBehavior, startBehavior
        case duckingBehavior, duration, fadeOutDuration, playFade
        case stopFade, crossFade, notes
    }

    init(displayName: String = "New Cue",
         mediaPath: String = "",
         duration: Double = 0) {
        self.id = UUID().uuidString
        self.displayName = displayName
        self.color = "#DA1E28"
        self.mediaFileName = URL(fileURLWithPath: mediaPath).lastPathComponent
        self.mediaPath = mediaPath
        self.inPoint = 0
        self.outPoint = duration
        self.volume = 1.0
        self.endBehavior = EndBehavior(action: .next)
        self.startBehavior = StartBehavior(action: .nothing)
        self.duckingBehavior = DuckingBehavior(mode: .stopAll)
        self.duration = duration
        self.fadeOutDuration = 1.0
        self.playFade = 0
        self.stopFade = 0
        self.crossFade = 0
        self.notes = ""
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self, forKey: .id)
        displayName     = try c.decode(String.self, forKey: .displayName)
        color           = try c.decodeIfPresent(String.self, forKey: .color) ?? "#DA1E28"
        mediaFileName   = try c.decodeIfPresent(String.self, forKey: .mediaFileName) ?? ""
        mediaPath       = try c.decodeIfPresent(String.self, forKey: .mediaPath) ?? ""
        inPoint         = try c.decodeIfPresent(Double.self, forKey: .inPoint) ?? 0
        outPoint        = try c.decodeIfPresent(Double.self, forKey: .outPoint) ?? 0
        volume          = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 1.0
        endBehavior     = try c.decodeIfPresent(EndBehavior.self, forKey: .endBehavior) ?? EndBehavior()
        startBehavior   = try c.decodeIfPresent(StartBehavior.self, forKey: .startBehavior) ?? StartBehavior()
        duckingBehavior = try c.decodeIfPresent(DuckingBehavior.self, forKey: .duckingBehavior) ?? DuckingBehavior()
        duration        = try c.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        fadeOutDuration = try c.decodeIfPresent(Double.self, forKey: .fadeOutDuration) ?? 1.0
        playFade        = try c.decodeIfPresent(Double.self, forKey: .playFade) ?? 0
        stopFade        = try c.decodeIfPresent(Double.self, forKey: .stopFade) ?? 0
        crossFade       = try c.decodeIfPresent(Double.self, forKey: .crossFade) ?? 0
        notes           = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,              forKey: .id)
        try c.encode(displayName,     forKey: .displayName)
        try c.encode(color,           forKey: .color)
        try c.encode(mediaFileName,   forKey: .mediaFileName)
        try c.encode(mediaPath,       forKey: .mediaPath)
        try c.encode(inPoint,         forKey: .inPoint)
        try c.encode(outPoint,        forKey: .outPoint)
        try c.encode(volume,          forKey: .volume)
        try c.encode(endBehavior,     forKey: .endBehavior)
        try c.encode(startBehavior,   forKey: .startBehavior)
        try c.encode(duckingBehavior, forKey: .duckingBehavior)
        try c.encode(duration,        forKey: .duration)
        try c.encode(fadeOutDuration, forKey: .fadeOutDuration)
        try c.encode(playFade,        forKey: .playFade)
        try c.encode(stopFade,        forKey: .stopFade)
        try c.encode(crossFade,       forKey: .crossFade)
        try c.encode(notes,           forKey: .notes)
    }
}

// MARK: - Group Cue

final class GroupCue: ObservableObject, Identifiable, Codable {
    var id: String
    @Published var displayName: String
    @Published var color: String
    @Published var children: [CueItem]
    @Published var startBehavior: GroupStartBehavior
    @Published var endBehavior: EndBehavior
    @Published var isExpanded: Bool
    @Published var notes: String

    enum CodingKeys: String, CodingKey {
        case id, displayName, color, children, startBehavior, endBehavior, isExpanded, notes
    }

    init(displayName: String = "New Group") {
        self.id = UUID().uuidString
        self.displayName = displayName
        self.color = "#3300FF"
        self.children = []
        self.startBehavior = GroupStartBehavior(action: .playFirst)
        self.endBehavior = EndBehavior(action: .nothing)
        self.isExpanded = true
        self.notes = ""
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        displayName   = try c.decode(String.self, forKey: .displayName)
        color         = try c.decodeIfPresent(String.self, forKey: .color) ?? "#3300FF"
        children      = try c.decodeIfPresent([CueItem].self, forKey: .children) ?? []
        startBehavior = try c.decodeIfPresent(GroupStartBehavior.self, forKey: .startBehavior) ?? GroupStartBehavior()
        endBehavior   = try c.decodeIfPresent(EndBehavior.self, forKey: .endBehavior) ?? EndBehavior(action: .nothing)
        isExpanded    = try c.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        notes         = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,            forKey: .id)
        try c.encode(displayName,   forKey: .displayName)
        try c.encode(color,         forKey: .color)
        try c.encode(children,      forKey: .children)
        try c.encode(startBehavior, forKey: .startBehavior)
        try c.encode(endBehavior,   forKey: .endBehavior)
        try c.encode(isExpanded,    forKey: .isExpanded)
        try c.encode(notes,         forKey: .notes)
    }
}

// MARK: - CueItem (Enum wrapper for polymorphism)

enum CueItem: Identifiable, Codable {
    case audio(AudioCue)
    case group(GroupCue)

    var id: String {
        switch self {
        case .audio(let c): return c.id
        case .group(let g): return g.id
        }
    }

    var displayName: String {
        get {
            switch self {
            case .audio(let c): return c.displayName
            case .group(let g): return g.displayName
            }
        }
    }

    var color: String {
        switch self {
        case .audio(let c): return c.color
        case .group(let g): return g.color
        }
    }

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }

    var audioCue: AudioCue? {
        if case .audio(let c) = self { return c }
        return nil
    }

    var groupCue: GroupCue? {
        if case .group(let g) = self { return g }
        return nil
    }

    private enum TypeKey: String, CodingKey { case type }
    private enum CueType: String, Codable { case audio, group }

    init(from decoder: Decoder) throws {
        let typeContainer = try decoder.container(keyedBy: TypeKey.self)
        let type = try typeContainer.decode(CueType.self, forKey: .type)
        switch type {
        case .audio:
            self = .audio(try AudioCue(from: decoder))
        case .group:
            self = .group(try GroupCue(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var typeContainer = encoder.container(keyedBy: TypeKey.self)
        switch self {
        case .audio(let c):
            try typeContainer.encode(CueType.audio, forKey: .type)
            try c.encode(to: encoder)
        case .group(let g):
            try typeContainer.encode(CueType.group, forKey: .type)
            try g.encode(to: encoder)
        }
    }
}

// MARK: - Cart Item

struct CartItem: Identifiable, Codable {
    var id: String { "\(slot)" }
    var slot: Int
    var itemUUID: String
    var displayName: String
    var color: String

    init(slot: Int, itemUUID: String, displayName: String, color: String) {
        self.slot = slot
        self.itemUUID = itemUUID
        self.displayName = displayName
        self.color = color
    }
}

// MARK: - Active Playback State

struct ActiveCue: Identifiable {
    var id: String
    var displayName: String
    var color: String
    var totalDuration: Double
    var currentTime: Double = 0
    var volume: Double = 1.0
    var isDucked: Bool = false

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(currentTime / totalDuration, 1.0)
    }

    var timeRemaining: Double {
        max(totalDuration - currentTime, 0)
    }
}

// MARK: - Preset Colors

let presetCueColors: [String] = [
    "#DA1E28", // Red (IBM Carbon danger)
    "#FF832B", // Orange
    "#F1C21B", // Yellow
    "#24A148", // Green
    "#0E6027", // Dark Green
    "#0072C3", // Blue
    "#002D9C", // Dark Blue
    "#8A3FFC", // Purple
    "#9F1853", // Magenta
    "#005D5D", // Teal
    "#6E6E6E", // Gray
    "#393939"  // Dark Gray
]

// MARK: - Theme

struct AppTheme: Codable {
    var mode: String = "dark"
    var accentColor: String = "#DA1E28"
}

// MARK: - Helpers

extension String {
    var nsColor: NSColor {
        guard self.hasPrefix("#"), self.count == 7,
              let r = UInt8(self.dropFirst().prefix(2), radix: 16),
              let g = UInt8(self.dropFirst(3).prefix(2), radix: 16),
              let b = UInt8(self.dropFirst(5).prefix(2), radix: 16) else {
            return .systemRed
        }
        return NSColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}

extension Double {
    var formattedTime: String {
        let t = max(self, 0)
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        let tenths  = Int((t - Double(Int(t))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}
