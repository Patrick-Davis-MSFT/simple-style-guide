import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'node:path';

const deployedAt = process.env.VITE_DEPLOYED_AT ?? new Date().toISOString();

export default defineConfig({
  envPrefix: ['VITE_', 'FUNCTION_'],
  define: {
    'globalThis.__DEPLOYED_AT__': JSON.stringify(deployedAt),
  },
  plugins: [react()],
  server: {
    port: 3000,
    host: '0.0.0.0',
  },
  build: {
    outDir: 'dist',
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        taskpane: resolve(__dirname, 'taskpane.html'),
      },
    },
  },
});
