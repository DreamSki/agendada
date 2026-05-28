import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

function wkWebViewFileURLHTMLPlugin() {
  return {
    name: "agendada-wkwebview-file-url-html",
    generateBundle(_, bundle) {
      const html = bundle["index.html"];
      if (html && html.type === "asset" && typeof html.source === "string") {
        html.source = html.source
          .replace(/\s+crossorigin/g, "")
          .replace(/<script type="module" src=/g, "<script src=")
          .replace(/<script type="module" /g, "<script ");
      }
    }
  };
}

export default defineConfig({
  base: "./",
  plugins: [react(), wkWebViewFileURLHTMLPlugin()],
  build: {
    assetsInlineLimit: 0,
    modulePreload: false,
    sourcemap: false,
    rollupOptions: {
      output: {
        format: "iife",
        inlineDynamicImports: true,
        entryFileNames: "assets/editor.js",
        assetFileNames: "assets/[name][extname]"
      }
    }
  }
});
