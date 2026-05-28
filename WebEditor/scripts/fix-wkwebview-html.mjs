import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const htmlPath = resolve(
  import.meta.dirname,
  "../../Sources/Agendada/Resources/BlockNoteEditor/index.html"
);

const html = readFileSync(htmlPath, "utf8")
  .replace(/\s+crossorigin/g, "")
  .replace(/<script type="module" src=/g, "<script src=")
  .replace(/<script type="module" /g, "<script ")
  .replace(/<script src=/g, "<script defer src=");

writeFileSync(htmlPath, html);
