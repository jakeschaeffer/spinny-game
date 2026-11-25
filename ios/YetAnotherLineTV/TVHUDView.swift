import SwiftUI

/// The in-run display: the score beside the playfield's left wall, tips beside its right.
struct TVHUDView: View {
    let model: GameModel

    var body: some View {
        Gutters {
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(model.score)")
                    .font(.display(120, .black))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
                    .shadow(color: .spaceCyan.opacity(0.5), radius: 20)
                bestLine
                ZStack {
                    if model.combo > 1 {
                        ComboBadge(combo: model.combo)
                            .id(model.combo)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .frame(height: 60)
                .padding(.top, 16)
                // Scoped to the badge so the constantly changing score never cross-fades.
                .animation(.spring(duration: 0.3, bounce: 0.4), value: model.combo)
                Spacer()
                Label("PAUSE", systemImage: "playpause.fill")
                    .font(.display(18, .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } right: {
            VStack(alignment: .leading) {
                Spacer()
                ZStack(alignment: .leading) {
                    if let lesson = model.lesson {
                        TipCard(tip: lessonTip(lesson.step), progress: lesson.step == .climb ? model.score : nil)
                            .id(lesson.step)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if model.showTutorial {
                        TutorialCard(howTo: RemoteHowTo(touch: model.touchToLatch))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeOut(duration: 0.4), value: model.showTutorial)
                .animation(.easeOut(duration: 0.35), value: model.lesson?.step)
                Spacer()
                    .frame(height: 120)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var bestLine: some View {
        if model.lesson != nil {
            Text("LESSON · GOAL \(Lesson.goal)")
                .font(.display(22, .bold))
                .tracking(2.5)
                .foregroundStyle(Color.spaceCyan.opacity(0.8))
        } else if model.passedBest {
            Label("NEW BEST", systemImage: "star.fill")
                .font(.display(22, .heavy))
                .tracking(2.5)
                .foregroundStyle(Color.spaceGold)
        } else {
            Text(model.best > 0 ? "\(model.runDifficulty.badge) · BEST \(model.best)" : model.runDifficulty.badge)
                .font(.display(22, .bold))
                .tracking(2.5)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func lessonTip(_ step: Lesson.Step) -> Tip {
        let touch = model.touchToLatch
        let danger = Color(uiColor: Theme.danger)
        switch step {
        case .latch:
            return touch
                ? Tip(icon: "hand.point.up.left.fill", title: "TOUCH TO LATCH",
                      detail: "When a planet lights up, rest your thumb on the remote's touch surface to latch onto it. No need to click.")
                : Tip(icon: "hand.tap.fill", title: "HOLD TO LATCH",
                      detail: "When a planet lights up, press and hold the remote's centre button to latch onto it.")
        case .swing:
            return Tip(icon: "arrow.triangle.2.circlepath", title: touch ? "KEEP TOUCHING" : "KEEP HOLDING",
                       detail: touch ? "You swing around the planet for as long as your thumb stays on the remote."
                                     : "You swing around the planet for as long as you hold.")
        case .launch:
            return Tip(icon: "arrow.up.forward", title: touch ? "LIFT TO LAUNCH" : "LET GO TO LAUNCH",
                       detail: touch ? "You fly off the way you're moving, so lift your thumb while you're heading up."
                                     : "You fly off the way you're moving, so let go while you're heading up.")
        case .chain:
            return Tip(icon: "point.3.connected.trianglepath.dotted", title: "LATCH THE NEXT ONE",
                       detail: "Grab another planet before you fall. Quick latches build a combo.")
        case .walls where model.lessonBumpers:
            return Tip(icon: "shield.fill", accent: .spaceGold, title: "BUMPERS ARE ON",
                       detail: "The side walls bounce you back while you learn. In a real run, flying into one ends it. Swinging through one while latched is always safe.")
        case .walls:
            return Tip(icon: "exclamationmark.triangle.fill", accent: danger, title: "MIND THE WALLS",
                       detail: "Flying into a side wall ends your run. Swinging through one while you're latched is safe.")
        case .climb:
            return Tip(icon: "flag.checkered", title: "CLIMB TO \(Lesson.goal)",
                       detail: "Keep latching and launching to reach the finish line.")
        }
    }
}

private struct Tip {
    let icon: String
    var accent: Color = .spaceCyan
    let title: String
    let detail: String
}

private struct ComboBadge: View {
    let combo: Int

    var body: some View {
        Text("×\(combo) COMBO")
            .font(.display(24, .black))
            .tracking(2.5)
            .foregroundStyle(Color(white: 0.08))
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(LinearGradient(colors: [.spaceGold, Color(uiColor: UIColor(hex: 0xFB923C))],
                                       startPoint: .leading, endPoint: .trailing), in: Capsule())
            .shadow(color: .spaceGold.opacity(0.5), radius: 16)
    }
}

/// The learning mode's current tip.
private struct TipCard: View {
    let tip: Tip
    /// The score so far, shown as progress to the lesson's goal.
    let progress: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                Image(systemName: tip.icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(tip.accent)
                    .frame(width: 44)
                Text(tip.title)
                    .font(.display(28, .black))
                    .foregroundStyle(.white)
            }
            Text(tip.detail)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            if let progress {
                HStack(spacing: 16) {
                    ProgressView(value: min(Double(progress) / Double(Lesson.goal), 1))
                        .tint(.spaceCyan)
                    Text("\(min(progress, Lesson.goal)) / \(Lesson.goal)")
                        .font(.display(22, .heavy))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(34)
        .frame(maxWidth: 500, alignment: .leading)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 2))
    }
}

private struct TutorialCard: View {
    let howTo: RemoteHowTo

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            row(icon: howTo.touch ? "hand.point.up.left.fill" : "hand.tap.fill", howTo.hold)
            row(icon: "arrow.up.forward", howTo.release)
        }
        .padding(34)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 2))
    }

    private func row(icon: String, _ step: (action: String, detail: String)) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.spaceCyan)
                .frame(width: 44)
            Text(step.action)
                .font(.display(28, .black))
                .foregroundStyle(.white)
            Text(step.detail)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
