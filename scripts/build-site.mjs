// GitHub Pages keeps its existing docs/ root. Copy generated shared modules,
// not a second implementation of color math or palette data.
import { mkdir, copyFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
const root = new URL('../', import.meta.url);
await mkdir(new URL('docs/theme/', root), {recursive:true});
for (const name of ['palettes.json','theme.mjs','pride-prism.css']) {
  await copyFile(new URL('tokens/' + name, root), new URL('docs/theme/' + name, root));
}
console.log('GitHub Pages shared theme assets ready: ' + fileURLToPath(new URL('docs/', root)));
