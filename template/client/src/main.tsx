import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';

// The neutral theme names Figtree but ships no @font-face, so the app supplies
// it. Self-hosted rather than pulled from a CDN: the template targets internal
// services, and a webfont request to a third party is a dependency and a leak.
// The static package, not @fontsource-variable: the variable build registers the
// family as "Figtree Variable", while the theme asks for "Figtree", so the name
// never matches and every heading silently falls back to a system serif.
import '@fontsource/figtree/400.css';
import '@fontsource/figtree/500.css';
import '@fontsource/figtree/600.css';
import '@fontsource/figtree/700.css';

// Astryx ships pre-built CSS, so there is no StyleX compiler step in this build.
// Order matters: reset, then the component styles, then the theme's tokens.
import '@astryxdesign/core/reset.css';
import '@astryxdesign/core/astryx.css';
import '@astryxdesign/theme-neutral/theme.css';

import { App } from './App';
import { AppAuthProvider } from './core/auth/AuthProvider';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AppAuthProvider>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </AppAuthProvider>
  </StrictMode>,
);
