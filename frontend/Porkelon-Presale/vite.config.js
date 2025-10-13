import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react-swc';
import { NodeGlobalsPolyfillPlugin } from '@esbuild-plugins/node-globals-polyfill';
import { NodeModulesPolyfillPlugin } from '@esbuild-plugins/node-modules-polyfill';

export default defineConfig(({ command, mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  return {
    plugins: [
      react(),
      NodeGlobalsPolyfillPlugin({
        buffer: true,
        process: true,
      }),
      NodeModulesPolyfillPlugin(),
    ],
    define: {
      __APP_VERSION__: JSON.stringify(env.APP_VERSION || '1.0.0'),
      global: 'globalThis',
    },
    resolve: {
      alias: {
        '@': '/src',
        'buffer': 'rollup-plugin-node-polyfills/polyfills/buffer-es6',
      },
    },
    server: {
      port: 3000,
      open: true,
      proxy: {
        '/api': {
          target: 'https://polygon-rpc.com', // Or your backend/Polygon endpoint
          changeOrigin: true,
          secure: false,
        },
      },
      cors: true,
    },
    build: {
      outDir: 'dist',
      sourcemap: true,
      rollupOptions: {
        output: {
          manualChunks: {
            vendor: ['react', 'react-dom', 'ethers'], // Chunk heavy deps
          },
        },
      },
    },
    base: '/', // Adjust if deploying to subpath, e.g., '/porkelon-presale/'
    preview: {
      port: 4173,
    },
  };
});
