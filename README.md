# Yet Another Line

Hold to orbit a planet, release to launch. Climb as high as you can without hitting a planet, a wall, or falling off the bottom.

## Native iOS app (`ios/`)

A Swift rewrite of the game (SpriteKit for gameplay, SwiftUI for menus) with a deep-space look. No dependencies.

- Open `ios/YetAnotherLine.xcodeproj` in Xcode, pick your iPhone or a simulator, and press Run.
- Tests: `xcodebuild test -project ios/YetAnotherLine.xcodeproj -scheme YetAnotherLine -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
- Debug builds accept a `-autopilot` launch argument that plays runs automatically, handy for checking visuals.
- Physics (spin speed, tether effect, launch power, gravity, out-of-bounds regrab window, game speed) can be tuned in the app's Settings.
- Shipping an App Store update: see [`ios/RELEASING.md`](ios/RELEASING.md).

## Apple TV app (same project)

The `YetAnotherLineTV` scheme builds the game for Apple TV from the same code. The playfield is a column down the middle of the screen, with the score and tips either side.

- Rest your thumb on the Siri Remote's touch surface to latch onto a planet and lift it to launch; no click needed. Holding a click works too, as does a game controller's A button. Play/Pause or Back pauses. "Touch to latch" can be turned off in the app's Settings.
- Shared game code is in `ios/YetAnotherLine/`; the TV's screens, remote handling and icon are in `ios/YetAnotherLineTV/`. The iPhone's screens are wrapped in `#if os(iOS)`.
- Run it: open the project, pick the `YetAnotherLineTV` scheme and an Apple TV or Apple TV simulator.
- Tests: `xcodebuild test -project ios/YetAnotherLine.xcodeproj -scheme YetAnotherLineTV -destination 'platform=tvOS Simulator,name=Apple TV 4K (4th generation) (at 1080p)'` drives the app with the remote's buttons. The touch surface can't be scripted, so try touch-to-latch on a real Apple TV.
- Debug builds also accept `-noGameCenter` (skips the sign-in screen) and `-screen pause|settings|lesson|play` (opens that screen at launch).
- The icon and Top Shelf images are drawn by `swift Tools/TVArt.swift`, run from `ios/`.

## Web version

The original React + Vite version lives in `src/`. Run it with `npm install && npm run dev`.

# React + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react/README.md) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## Expanding the ESLint configuration

If you are developing a production application, we recommend using TypeScript and enable type-aware lint rules. Check out the [TS template](https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts) to integrate TypeScript and [`typescript-eslint`](https://typescript-eslint.io) in your project.
