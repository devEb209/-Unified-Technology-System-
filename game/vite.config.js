import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    allowedHosts: true,
    hmr: { clientPort: 443 },
    proxy: {
      '/ws': { target: 'ws://127.0.0.1:8787', ws: true, changeOrigin: true }
    }
  },
  build: { target: 'es2022', chunkSizeWarningLimit: 4000 }
});
