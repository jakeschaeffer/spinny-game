# One More Line

Hold to orbit a planet, release to launch. Climb as high as you can without hitting a planet, a wall, or falling off the bottom.

## Native iOS app (`ios/`)

A Swift rewrite of the game (SpriteKit for gameplay, SwiftUI for menus) with a deep-space look. No dependencies.

- Open `ios/OneMoreLine.xcodeproj` in Xcode, pick your iPhone or a simulator, and press Run.
- Tests: `xcodebuild test -project ios/OneMoreLine.xcodeproj -scheme OneMoreLine -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
- Debug builds accept a `-autopilot` launch argument that plays runs automatically, handy for checking visuals.
- Physics (spin speed, tether effect, launch power, gravity, out-of-bounds regrab window, game speed) can be tuned in the app's Settings.

## Web version

The original React + Vite version lives in `src/`. Run it with `npm install && npm run dev`.

# React + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react/README.md) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## Expanding the ESLint configuration

If you are developing a production application, we recommend using TypeScript and enable type-aware lint rules. Check out the [TS template](https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts) to integrate TypeScript and [`typescript-eslint`](https://typescript-eslint.io) in your project.
