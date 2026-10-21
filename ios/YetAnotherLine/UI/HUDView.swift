import SwiftUI

struct HUDView: View {
    let model: GameModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(model.score)")
                        .font(.display(52, .black))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .spaceCyan.opacity(0.5), radius: 12)
                    bestLine
                }
                .allowsHitTesting(false)
                Spacer()
                GlassIconButton(systemName: "pause.fill", label: "Pause") { model.pause() }
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)

            HStack {
                if model.combo > 1 {
                    ComboBadge(combo: model.combo)
                        .id(model.combo)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                Spacer()
            }
            .frame(height: 34)
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .allowsHitTesting(false)
            // Scoped to the badge so the constantly changing score never cross-fades.
            .animation(.spring(duration: 0.3, bounce: 0.4), value: model.combo)

            Spacer()
            // Low on the screen, behind the comet, so it never hides the planets ahead.
            ZStack {
                if let lesson = model.lesson {
                    LessonCoachCard(step: lesson.step, score: model.score)
                        .id(lesson.step)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if model.showTutorial {
                    TutorialCard()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.4), value: model.showTutorial)
            .animation(.easeOut(duration: 0.35), value: model.lesson?.step)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder private var bestLine: some View {
        if model.lesson != nil {
            Text("LESSON · GOAL \(Lesson.goal)")
                .font(.display(12, .bold))
                .tracking(1.5)
                .foregroundStyle(Color.spaceCyan.opacity(0.8))
        } else if model.passedBest {
            Label("NEW BEST", systemImage: "star.fill")
                .font(.display(12, .heavy))
                .tracking(1.5)
                .foregroundStyle(Color.spaceGold)
        } else {
            Text(model.best > 0 ? "\(model.runDifficulty.badge) · BEST \(model.best)" : model.runDifficulty.badge)
                .font(.display(12, .bold))
                .tracking(1.5)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

private struct ComboBadge: View {
    let combo: Int

    var body: some View {
        Text("×\(combo) COMBO")
            .font(.display(13, .black))
            .tracking(1.5)
            .foregroundStyle(Color(white: 0.08))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(LinearGradient(colors: [.spaceGold, Color(uiColor: UIColor(hex: 0xFB923C))],
                                       startPoint: .leading, endPoint: .trailing), in: Capsule())
            .shadow(color: .spaceGold.opacity(0.5), radius: 10)
    }
}

/// The learning mode's current tip, low on the screen like the tutorial card.
private struct LessonCoachCard: View {
    let step: Lesson.Step
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: tip.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(step == .walls ? Color(uiColor: Theme.danger) : .spaceCyan)
                    .frame(width: 26)
                Text(tip.title)
                    .font(.display(17, .black))
                    .foregroundStyle(.white)
            }
            Text(tip.detail)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            if step == .climb {
                HStack(spacing: 10) {
                    ProgressView(value: min(Double(score) / Double(Lesson.goal), 1))
                        .tint(.spaceCyan)
                    Text("\(min(score, Lesson.goal)) / \(Lesson.goal)")
                        .font(.display(12, .heavy))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: 340, alignment: .leading)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private var tip: (icon: String, title: String, detail: String) {
        switch step {
        case .latch:
            ("hand.tap.fill", "HOLD TO LATCH", "When a planet lights up, press and hold anywhere to latch onto it.")
        case .swing:
            ("arrow.triangle.2.circlepath", "KEEP HOLDING", "You swing around the planet for as long as you hold.")
        case .launch:
            ("arrow.up.forward", "LET GO TO LAUNCH", "You fly off the way you're moving, so let go while you're heading up.")
        case .chain:
            ("point.3.connected.trianglepath.dotted", "LATCH THE NEXT ONE", "Grab another planet before you fall. Quick latches build a combo.")
        case .walls:
            ("exclamationmark.triangle.fill", "MIND THE WALLS",
             "Flying into a side wall ends your run. Swinging through one while you're latched is safe.")
        case .climb:
            ("flag.checkered", "CLIMB TO \(Lesson.goal)", "Keep latching and launching to reach the finish line.")
        }
    }
}

private struct TutorialCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row(icon: "hand.tap.fill", action: "HOLD", detail: "to orbit a planet")
            row(icon: "arrow.up.forward", action: "RELEASE", detail: "to launch")
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }

    private func row(icon: String, action: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.spaceCyan)
                .frame(width: 26)
            Text(action)
                .font(.display(17, .black))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
