import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: {
    sourcemap: true,
    chunkSizeWarningLimit: 1200,
    rollupOptions: {
      output: {
        manualChunks: {
          mui: ["@mui/material", "@mui/icons-material", "@emotion/react", "@emotion/styled"],
          three: ["three", "@react-three/fiber", "@react-three/drei"],
        },
      },
    },
  },
});
