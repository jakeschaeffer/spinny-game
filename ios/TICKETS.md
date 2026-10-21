# Gameplay feedback tickets

Feedback from Oct 21, 2026, split into tickets. Each lands as its own commit on `claude/gameplay-feedback`, in the order below. Modes come before learning mode because learning mode reuses the per-mode tuning, and best combo comes before the leaderboard.

| # | Ticket | Status |
|---|---|---|
| 1 | Ramp up the planet count | Done |
| 2 | Easy and Astro (Hard) modes, each with its own scores | Done |
| 3 | Track best combo | Done |
| 4 | Learning mode | Done |
| 5 | Game Center leaderboard | Done (needs App Store Connect setup) |
| 6 | Path trace toggle | Done |
| 7 | Height easter eggs | In progress |

## 1. Ramp up the planet count

Start each run with fewer planets and add more as you climb, until the field reaches today's density.

- Planets near the start are spaced further apart than today, so the first screen is less crowded.
- Spacing tightens smoothly with altitude and matches today's spacing from score 500 on.
- The launch lane and the minimum gap between planets still hold, and the autopilot still climbs past 500 (unit tests).

## 2. Easy and Astro (Hard) modes

A mode picker in Settings: "Easy" and "Astro (Hard)". Astro is today's game.

- Easy has even fewer planets than Astro at every height, runs a bit slower, and forgives a wall hit for 300 ms: latch onto a planet within that time and the run goes on.
- Each mode keeps its own best score. Existing players' best carries over as their Astro best.
- The menu and HUD show which mode you're playing. A mode change applies from the next run.

## 3. Track best combo

- Keep each mode's all-time best combo next to its best score.
- Show it on the menu and the game-over card, with a "new best combo" marker when you beat it.
- "Reset best scores" in Settings clears it too.

## 4. Learning mode

- Start it from the menu at any time. A brand-new player's first LAUNCH goes there automatically.
- Half speed, fewer and bigger planets.
- Step-by-step coaching: hold to latch, keep holding to swing, let go to launch, latch the next planet. It warns that flying into a wall ends a run, but swinging through a wall while latched is safe.
- A crash explains what happened and restarts the lesson instead of ending in a game-over card.
- It finishes once you pass 100, marks the lesson as done, and offers to start a real run. Learning runs don't count toward best scores or the leaderboard.

## 5. Game Center leaderboard

- Sign in to Game Center at launch and submit each finished run to its mode's leaderboard.
- A leaderboard button on the menu and the game-over card opens the mode's leaderboard. If you're not signed in, it says how to sign in.
- Leaderboards have to exist in App Store Connect before scores show up. `RELEASING.md` has the IDs and the setup steps.
- Verified in the simulator: sign-in is attempted at launch, and the signed-out prompt works. Posting scores and opening the leaderboard need a phone signed in to Game Center and the leaderboards created in App Store Connect.

## 6. Path trace toggle

- A "Trace path" toggle in Settings, on by default.
- While it's on, the comet's whole path stays drawn as you play, instead of only the short fading tail.
- When the run ends, the game-over card sits low and the camera pulls back to fit the whole path in the space above it.
- Tapping the shown trace opens the iPhone share sheet with a 1080×1920 picture of it: the line on a starfield with the score, mode, and best combo (added Oct 21). The only extra UI is a quiet "Tap your line to share" hint.

## 7. Height easter eggs

Decorative sights at set heights, with no hitbox, once per run:

- 250: a satellite drifts past
- 500: a UFO zips across the screen
- 1000: an astronaut floats by, waving
- 1500: a rocket streaks up past you
- 2000: a meteor shower
