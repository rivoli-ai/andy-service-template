import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Ports are substituted by create-service.sh from the registry in docs/ports.md,
// so a scaffolded service starts on its allocated port with no manual wiring.
const CLIENT_PORT = Number(process.env.PORT ?? __PORT_CLIENT__);
const API_ORIGIN = process.env.VITE_API_ORIGIN ?? 'http://localhost:__PORT_HTTP__';

export default defineConfig({
  plugins: [react()],
  server: {
    port: CLIENT_PORT,
    // Proxying keeps the browser same-origin in development, so the API needs no
    // CORS policy for local work and the client needs no absolute URL baked in.
    // In Docker the same paths are proxied by nginx instead; see nginx.conf.
    proxy: {
      '/api': { target: API_ORIGIN, changeOrigin: true },
      '/health': { target: API_ORIGIN, changeOrigin: true },
    },
  },
});
