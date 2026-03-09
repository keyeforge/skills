---
name: init-react-frontend
description: Use when scaffolding a new React frontend with React, Ant Design, Ant Design X, react-router, TypeScript, Zustand, Vitest, Tailwind CSS, Axios, and Vite plus Rolldown — or when the user asks to initialize a frontend project with this stack.
---

# Init React Frontend

Scaffold a new React frontend project with a fixed tech stack: React + Ant Design + Ant Design X + react-router + TypeScript, Zustand, Vitest + jsdom, Tailwind CSS, Axios, and Vite with Rolldown. All third-party packages use latest versions unless the user pins specific versions.

## When to Use

- User wants to create a new React frontend or SPA from scratch with this stack.
- User asks to "初始化前端项目" or "scaffold React + Ant Design + Vite" with the stack below.
- Do **not** use for adding these tools to an existing non-React project, or when the user explicitly chooses a different stack (e.g. Vue, Next.js only).

## Tech Stack Summary

| Category        | Choice              | Notes                          |
|----------------|---------------------|--------------------------------|
| Framework      | React + TypeScript  | Via Vite React-TS template     |
| UI             | Ant Design          | `antd`                         |
| AI/UX          | Ant Design X        | `@ant-design/x`                |
| Routing        | react-router        | `react-router-dom`             |
| State          | Zustand             | `zustand`                      |
| Testing        | Vitest + jsdom      | `vitest`, `jsdom`              |
| Styles         | Tailwind CSS        | `tailwindcss`, PostCSS, etc.   |
| HTTP           | Axios               | `axios`                        |
| Build          | Vite + Rolldown     | `rolldown-vite` as Vite alias  |

All dependencies: install **latest** versions (e.g. `npm install <pkg>@latest` or unpinned `npm install <pkg>`). For production, consider pinning exact versions in `package.json` after verification.

## Implementation

### 1. Create project with Vite (Rolldown)

Use the official Vite scaffold; when prompted, choose **rolldown-vite** if the CLI offers it. Otherwise create with standard Vite and then switch to Rolldown.

```bash
npm create vite@latest <project-name> -- --template react-ts
cd <project-name>
```

To use Rolldown: in `package.json`, replace the `vite` devDependency with the Rolldown-powered alias (pin a specific version in production):

```json
{
  "devDependencies": {
    "vite": "npm:rolldown-vite@latest"
  }
}
```

Then run `npm install` (or pnpm/yarn). No extra Vite config is required for basic Rolldown usage.

### 2. Install runtime and UI dependencies

```bash
npm install react react-dom react-router-dom antd @ant-design/x zustand axios
npm install -D @types/react @types/react-dom
```

(If the template already includes `@types/react` / `@types/react-dom`, the `-D` install is optional.)

### 3. Install and configure Tailwind CSS

Install Tailwind and its peer deps (Vite + PostCSS):

```bash
npm install -D tailwindcss @tailwindcss/vite
```

In `vite.config.ts`, add the Tailwind plugin:

```ts
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  // ...
})
```

Create or extend your main CSS file (e.g. `src/index.css`) with Tailwind directives:

```css
@import "tailwindcss";
```

Optional: add a `tailwind.config.js` (or `.ts`) if you need theme/content customization. For default content paths, `@tailwindcss/vite` often does not require a config file.

### 4. Install and configure Vitest + jsdom

```bash
npm install -D vitest jsdom @vitest/ui
```

In `vite.config.ts`, add the Vitest config block (same file as Vite):

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  test: {
    globals: true,
    environment: 'jsdom',
  },
})
```

Add a test script in `package.json`:

```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:ui": "vitest --ui"
  }
}
```

Create a sample test (e.g. `src/App.test.tsx`) to verify the setup:

```tsx
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import App from './App'

describe('App', () => {
  it('renders', () => {
    render(<App />)
    expect(screen.getByRole('main') || document.body).toBeTruthy()
  })
})
```

Install React Testing Library if not already present:

```bash
npm install -D @testing-library/react @testing-library/jest-dom
```

Optionally in a setup file (e.g. `src/test/setup.ts`), add `import '@testing-library/jest-dom'` and reference it in `vite.config.ts` under `test.setupFiles`.

### 5. Wire React Router

In `src/main.tsx` (or entry), wrap the app with `BrowserRouter`:

```tsx
import { BrowserRouter } from 'react-router-dom'
import App from './App'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>
)
```

Define routes in `App.tsx` (or a dedicated router module) with `Routes` and `Route` from `react-router-dom`.

### 6. Optional: Ant Design and Ant Design X setup

- **Ant Design:** Import components per need (e.g. `import { Button } from 'antd'`) or wrap the app with `ConfigProvider` in `main.tsx` for theme/locale.
- **Ant Design X:** Follow [Ant Design X – Use with Vite](https://x.ant.design/docs/react/use-with-vite/). Typically you install `@ant-design/x` and use its components (e.g. for AI/chat UIs); no extra Vite plugin is required for basic usage.

### 7. Axios and Zustand

- Use **Axios** for API calls (e.g. a shared `src/api/client.ts` that exports an axios instance).
- Use **Zustand** for global state: create stores with `create()` and use them via hooks in components.

## Quick Reference

| Task              | Command / location                          |
|-------------------|---------------------------------------------|
| New project       | `npm create vite@latest <name> -- --template react-ts` |
| Rolldown          | `"vite": "npm:rolldown-vite@latest"` in package.json   |
| Run dev           | `npm run dev`                               |
| Build             | `npm run build`                             |
| Tests             | `npm run test` / `npm run test:run`         |
| Tailwind          | `@tailwindcss/vite` + `@import "tailwindcss"` in CSS  |
| Vitest            | `test: { globals: true, environment: 'jsdom' }` in vite.config |

## Common Mistakes

- **Rolldown:** Using both `vite` and `rolldown-vite` as separate packages. Use a single devDependency alias so that the project runs on Rolldown only.
- **Tailwind:** Forgetting to add `@import "tailwindcss"` (or the correct Tailwind directives) in the main CSS entry so styles apply.
- **Vitest:** Not setting `environment: 'jsdom'`, which causes DOM-related tests to fail.
- **Versions:** Leaving all packages at `@latest` in production can cause breaking changes on reinstall; pin major/minor (or exact) after validating.

## References

- [Vite – Rolldown](https://main.vite.dev/guide/rolldown)
- [Ant Design](https://ant.design/)
- [Ant Design X – React & Vite](https://x.ant.design/docs/react/use-with-vite/)
- [Tailwind CSS – Vite](https://tailwindcss.com/docs/installation/vite)
- [Vitest – Getting Started](https://vitest.dev/guide/)
- [Zustand](https://github.com/pmndrs/zustand)
- [React Router](https://reactrouter.com/)
