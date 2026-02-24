import SwiftUI

struct CartPlayerView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @EnvironmentObject var audioEngine: AudioEngine

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    private let totalSlots = 16

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            grid
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Cart Player", systemImage: "grid.circle.fill")
                .font(.headline)
            Spacer()
            Text("Drag cues from playlist to assign")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<totalSlots, id: \.self) { slot in
                CartSlotButton(
                    slot: slot,
                    cartItem: cartItem(for: slot)
                )
            }
        }
        .padding(10)
    }

    private func cartItem(for slot: Int) -> CartItem? {
        projectManager.project.cartItems.first { $0.slot == slot }
    }
}

// MARK: - Cart Slot Button

struct CartSlotButton: View {
    @EnvironmentObject var projectManager: ProjectManager
    @EnvironmentObject var audioEngine: AudioEngine

    var slot: Int
    var cartItem: CartItem?

    @State private var isTargeted = false

    var isPlaying: Bool {
        guard let item = cartItem else { return false }
        return audioEngine.isPlaying(item.itemUUID)
    }

    var body: some View {
        Button {
            triggerCart()
        } label: {
            cartButtonContent
        }
        .buttonStyle(.plain)
        .dropDestination(for: CueDragItem.self) { items, _ in
            guard let dragItem = items.first,
                  let cue = projectManager.project.findAudioCue(byID: dragItem.cueID) else {
                return false
            }
            projectManager.assignToCart(cue: cue, slot: slot)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .contextMenu {
            if cartItem != nil {
                Button("Stop") {
                    if let id = cartItem?.itemUUID {
                        audioEngine.stopCue(id: id)
                    }
                }
                Divider()
                Button("Clear Slot", role: .destructive) {
                    projectManager.removeFromCart(slot: slot)
                }
            }
        }
    }

    @ViewBuilder
    private var cartButtonContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: isTargeted ? 2 : 1)
                )
                .shadow(color: isPlaying ? Color(cartItem?.color.nsColor ?? .systemGreen).opacity(0.4) : .clear,
                        radius: 4)

            if let item = cartItem {
                VStack(spacing: 3) {
                    // Slot number badge
                    HStack {
                        Text("\(slot + 1)")
                            .font(.system(size: 9, weight: .bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.green)
                                .symbolEffect(.pulse)
                        }
                    }

                    Spacer()

                    Text(item.displayName)
                        .font(.system(size: 11, weight: isPlaying ? .bold : .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(isPlaying ? Color(item.color.nsColor) : .primary)

                    Spacer()

                    // Color strip at bottom
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(item.color.nsColor))
                        .frame(height: 3)
                }
                .padding(6)
            } else {
                VStack(spacing: 4) {
                    Text("\(slot + 1)")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .frame(height: 70)
        .scaleEffect(isPlaying ? 1.02 : 1.0)
        .animation(.spring(response: 0.2), value: isPlaying)
    }

    private var backgroundColor: Color {
        if isPlaying {
            return Color(cartItem?.color.nsColor ?? .systemGreen).opacity(0.15)
        }
        if isTargeted {
            return Color.accentColor.opacity(0.1)
        }
        if cartItem != nil {
            return Color(NSColor.controlBackgroundColor)
        }
        return Color(NSColor.controlBackgroundColor).opacity(0.5)
    }

    private var borderColor: Color {
        if isPlaying { return Color(cartItem?.color.nsColor ?? .systemGreen).opacity(0.6) }
        if isTargeted { return Color.accentColor }
        if cartItem != nil { return Color.secondary.opacity(0.3) }
        return Color.secondary.opacity(0.15)
    }

    private func triggerCart() {
        guard let item = cartItem,
              let cue = projectManager.project.findAudioCue(byID: item.itemUUID) else { return }

        if isPlaying {
            audioEngine.stopCue(id: item.itemUUID)
        } else {
            audioEngine.playCue(cue, project: projectManager.project)
        }
    }
}
