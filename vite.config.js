import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // Relative asset paths so the build works both at a domain root and under
  // a sub-path like GitHub Pages (/spinny-game/).
  base: './',
})
