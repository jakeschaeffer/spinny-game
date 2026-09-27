import SwiftUI

struct SettingsView: View {
    @Bindable var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Feel") {
                    Toggle(isOn: $model.soundEnabled) {
                        Label("Sound", systemImage: "speaker.wave.2.fill")
                    }
                    Toggle(isOn: $model.hapticsEnabled) {
                        Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    Toggle(isOn: $model.showOrbitGuide) {
                        Label("Orbit guide", systemImage: "scope")
                    }
                }

                Section {
                    SliderRow(title: "Spin speed", systemImage: "arrow.triangle.2.circlepath",
                              value: $model.physics.spin, range: 0.6...1.6, step: 0.05, format: multiplier)
                    SliderRow(title: "Tether effect", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                              value: $model.physics.tetherEffect, range: 0...1, step: 0.05, format: percent)
                    SliderRow(title: "Launch power", systemImage: "paperplane.fill",
                              value: $model.physics.launchPower, range: 0.7...1.5, step: 0.05, format: multiplier)
                    SliderRow(title: "Gravity", systemImage: "arrow.down.circle",
                              value: $model.physics.gravity, range: 0...2, step: 0.1,
                              format: { $0 == 0 ? "Off" : multiplier($0) })
                    SliderRow(title: "Game speed", systemImage: "gauge.with.dots.needle.50percent",
                              value: $model.gameSpeed, range: 0.5...2, step: 0.05, format: multiplier)
                    if model.physics != Physics() || model.gameSpeed != 1 {
                        Button("Restore default physics") {
                            model.physics = Physics()
                            model.gameSpeed = 1
                        }
                    }
                } header: {
                    Text("Physics")
                } footer: {
                    Text("Tether effect sets how much tether length matters: higher makes short tethers whip around faster and long ones swing slower. Big, fast swings fling you off harder. Changes apply straight away, even mid-run.")
                }

                Section {
                    Button("Reset best score", role: .destructive) { confirmReset = true }
                        .disabled(model.best == 0)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.spaceInk)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset your best score?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { model.resetBest() }
            }
        }
        .tint(.spaceCyan)
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    private func multiplier<Value: BinaryFloatingPoint>(_ value: Value) -> String {
        String(format: "%.2f×", Double(value))
    }

    private func percent<Value: BinaryFloatingPoint>(_ value: Value) -> String {
        "\(Int((Double(value) * 100).rounded()))%"
    }
}

private struct SliderRow<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    let title: String
    let systemImage: String
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value.Stride
    let format: (Value) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
        .padding(.vertical, 2)
    }
}
