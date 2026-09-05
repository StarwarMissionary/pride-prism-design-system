import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createTheme, themeCss } from '../tokens/theme.mjs';
const root = new URL('../', import.meta.url);
const read = p => readFile(new URL(p,root),'utf8');
const catalog = JSON.parse(await read('tokens/palettes.json'));
const defined = new Set([...themeCss(createTheme(catalog)).matchAll(/(--prism-[\w-]+)\s*:/g)].map(m=>m[1]));
const steam = ['libraryroot.custom.css','friends.custom.css','webkit.css','bigpicture.custom.css'];
test('adapter templates consume existing shared tokens without independent palettes',async()=>{
  for(const file of [...steam.map(n=>'adapters/steam/PridePrism/'+n),'adapters/discord/PridePrism.theme.css','adapters/chrome-start-page/styles.css']) {
    const css=await read(file);
    for(const [,name]of css.matchAll(/var\((--prism-[\w-]+)/g)) assert.ok(defined.has(name),`${file}: undefined ${name}`);
    assert.doesNotMatch(css,/#[0-9a-f]{6}\b/i,`${file}: independent opaque hex palette`);
    assert.doesNotMatch(css,/\binfinite\b/,`${file}: continuous decoration`);
  }
});
test('Steam templates preserve native layout and avoid hashed-class wildcard painting',async()=>{
  for(const name of steam) {
    const css=(await read('adapters/steam/PridePrism/'+name)).replace(/\/\*[\s\S]*?\*\//g,'');
    assert.doesNotMatch(css,/\[class\s*[*^$]=/);
    assert.doesNotMatch(css,/(?:^|[;{}])\s*(?:position|display|(?:min-|max-)?(?:width|height)|inset(?:-[\w-]+)?|top|right|bottom|left|overflow(?:-[xy])?|visibility|z-index|transform|clip(?:-path)?)\s*:/m,`${name}: native geometry override`);
    assert.doesNotMatch(css,/(?:^|[;{}])\s*color:\s*var\(--pp-accent\)/m,`${name}: unpaired accent text`);
    for (const [,selector,body] of css.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
      if (/\.AppDetailsOverlayTransitionGroup\b/.test(selector)) assert.match(body,/^\s*background:\s*transparent\s*!important;\s*$/, 'Library transition overlay must remain transparent');
      assert.doesNotMatch(selector,/\.chatTitleBar\b/, 'Friends title hit-area must not be painted');
      assert.doesNotMatch(selector,/\.MainNavMenuAnchor\b/, 'Zero-width controller menu anchor is not a paint surface');
      if (/\.MainMenuEmbedded\b/.test(selector)) assert.match(selector,/\.MainMenuEmbedded\s+\.Menu:not\(\.VR\)/, 'Style the real non-VR menu panel, not its full-window overlay');
    }
  }
});
test('website receives identical shared modules and no independent color resolver',async()=>{
  for(const name of ['palettes.json','theme.mjs','pride-prism.css']) assert.equal(await read('docs/theme/'+name),await read('tokens/'+name));
  assert.match(await read('docs/app.js'),/import \{ createTheme, themeCss, contrast \} from "\.\/theme\/theme\.mjs"/);
  assert.doesNotMatch(await read('docs/styles.css'),/\binfinite\b/);
});
