import SwiftUI

/// Settings as one scrolling column of rows. Click a switch to flip it; swipe or press left and right
/// on a number to change it.
struct TVSettingsView: View {
    @Bindable var model: GameModel
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("SETTINGS")
                    .font(.display(48, .black))
                    .tracking(6)
                    .foregroundStyle(.white)
                    .padding(.bottom, 10)

                header("Mode")
                ChoiceRow(title: "Mode", systemImage: "dial.medium.fill", value: model.difficulty.title) { _ in
                    model.difficulty = model.difficulty == .easy ? .astro : .easy
                }
                ToggleRow(title: "Bumpers in Easy", systemImage: "arrow.uturn.backward.circle", isOn: $model.easyBumpers)
                footer("Easy has fewer planets and runs a bit slower. Bumpers turn its side walls gold and bounce you back instead of ending the run. Each mode keeps its own best score, and a mode change applies from your next run.")

                header("Remote")
                ToggleRow(title: "Touch to latch", systemImage: "hand.point.up.left.fill", isOn: $model.touchToLatch)
                footer("On: rest your thumb on the remote's touch surface to latch, and lift it to launch. Off: hold a click instead. Clicking always works, and so does a game controller's A button.")

                header("Feel")
                ToggleRow(title: "Sound", systemImage: "speaker.wave.2.fill", isOn: $model.soundEnabled)
                ToggleRow(title: "Orbit guide", systemImage: "scope", isOn: $model.showOrbitGuide)
                ToggleRow(title: "Trace path", systemImage: "scribble.variable", isOn: $model.tracePath)
                footer("Trace path keeps your whole line on screen and shows all of it when the run ends.")

                header("Physics")
                AdjustRow(title: "Spin speed", systemImage: "arrow.triangle.2.circlepath",
                          value: $model.physics.spin, range: 0.6...1.6, step: 0.05, format: multiplier)
                AdjustRow(title: "Tether effect", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                          value: $model.physics.tetherEffect, range: 0...1, step: 0.05, format: percent)
                AdjustRow(title: "Launch power", systemImage: "paperplane.fill",
                          value: $model.physics.launchPower, range: 0.7...1.5, step: 0.05, format: multiplier)
                AdjustRow(title: "Gravity", systemImage: "arrow.down.circle",
                          value: $model.physics.gravity, range: 0...2, step: 0.1,
                          format: { $0 == 0 ? "Off" : multiplier($0) })
                AdjustRow(title: "Regrab window", systemImage: "hand.raised.fingers.spread",
                          value: $model.physics.regrabWindow, range: 0...0.3, step: 0.01,
                          format: { $0 == 0 ? "Off" : "\(Int(($0 * 1000).rounded())) ms" })
                AdjustRow(title: "Game speed", systemImage: "gauge.with.dots.needle.50percent",
                          value: $model.gameSpeed, range: 0.5...2, step: 0.05, format: multiplier)
                if model.physics != Physics() || model.gameSpeed != 1 {
                    ActionRow(title: "Restore default physics", systemImage: "arrow.counterclockwise") {
                        model.physics = Physics()
                        model.gameSpeed = 1
                    }
                }
                footer("Swipe or press left and right to change a number. Tether effect sets how much tether length matters: higher makes short tethers whip around faster and long ones swing slower. Regrab window is how long you have to grab again if you let go while your swing is past a wall.")

                header("Scores")
                ActionRow(title: "Reset best scores", systemImage: "trash", destructive: true) { confirmReset = true }
                    .disabled(model.bests.values.allSatisfy { $0 == 0 } && model.bestCombos.values.allSatisfy { $0 == 0 })

                ActionRow(title: "Done", systemImage: "checkmark") { model.showSettings = false }
                    .padding(.top, 30)
            }
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
        .background(Color.spaceInk.opacity(0.97).ignoresSafeArea())
        .onExitCommand { model.showSettings = false }
        .confirmationDialog("Reset your best scores and combos in every mode?", isPresented: $confirmReset,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) { model.resetBests() }
        }
        .preferredColorScheme(.dark)
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.display(20, .bold))
            .tracking(4)
            .foregroundStyle(Color.spaceCyan.opacity(0.85))
            .padding(.top, 30)
            .padding(.leading, 30)
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.white.opacity(0.5))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 30)
            .padding(.top, 2)
    }

    private func multiplier<Value: BinaryFloatingPoint>(_ value: Value) -> String {
        String(format: "%.2f×", Double(value))
    }

    private func percent<Value: BinaryFloatingPoint>(_ value: Value) -> String {
        "\(Int((Double(value) * 100).rounded()))%"
    }
}

/// How every settings row looks, and how it lights up under focus.
private struct RowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration)
    }

    private struct Face: View {
        let configuration: Configuration
        @Environment(\.isFocused) private var isFocused
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 29, weight: .semibold))
                .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.35))
                .padding(.horizontal, 30)
                .frame(maxWidth: .infinity, minHeight: 78)
                .background(.white.opacity(isFocused ? 0.2 : 0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.spaceCyan.opacity(isFocused ? 0.9 : 0), lineWidth: 3))
                .scaleEffect(isFocused ? 1.025 : 1)
                .animation(.spring(duration: 0.22), value: isFocused)
        }
    }
}

private struct RowLabel: View {
    let title: String
    let systemImage: String
    let value: String
    var valueColor: Color = .white.opacity(0.6)

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.spaceCyan)
                .frame(width: 44)
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            RowLabel(title: title, systemImage: systemImage, value: isOn ? "On" : "Off",
                     valueColor: isOn ? .spaceCyan : .white.opacity(0.45))
        }
        .buttonStyle(RowStyle())
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// A row that steps through choices on a click or a left/right move. `change` gets -1 or +1.
private struct ChoiceRow: View {
    let title: String
    let systemImage: String
    let value: String
    let change: (Int) -> Void

    var body: some View {
        Button { change(1) } label: {
            RowLabel(title: title, systemImage: systemImage, value: "‹  \(value)  ›")
        }
        .buttonStyle(RowStyle())
        .onMoveCommand { direction in
            switch direction {
            case .left: change(-1)
            case .right: change(1)
            default: break
            }
        }
        .accessibilityValue(value)
    }
}

/// A number changed with left and right, the remote's stand-in for a slider.
private struct AdjustRow<Value: BinaryFloatingPoint>: View {
    let title: String
    let systemImage: String
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value
    let format: (Value) -> String

    var body: some View {
        ChoiceRow(title: title, systemImage: systemImage, value: format(value)) { direction in
            // Snap to the step grid so repeated moves don't drift.
            let stepped = ((value + Value(direction) * step) / step).rounded() * step
            value = min(max(stepped, range.lowerBound), range.upperBound)
        }
    }
}

private struct ActionRow: View {
    let title: String
    let systemImage: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: systemImage)
                    .frame(width: 44)
                Text(title)
                Spacer()
            }
            .foregroundStyle(destructive ? Color(uiColor: Theme.danger) : Color.spaceCyan)
        }
        .buttonStyle(RowStyle())
    }
}
