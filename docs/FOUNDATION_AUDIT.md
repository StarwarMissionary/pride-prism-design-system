# Foundation audit — 5 September 2026

Baseline: public `main` at `96bf308522347045c8460e3550c7a6fd72adb867`. Three independent Astra reviews covered tokens/accessibility, rendered website UX, and native desktop integration. Existing uncommitted Steam repairs were preserved. This is a source and design audit, not a claim that every installed application has passed visual acceptance.

See the [verification record](VERIFICATION.md) for completed checks and remaining host-level acceptance gates.

## Root findings

| Priority | Foundation defect | Evidence at baseline | Required correction |
| --- | --- | --- | --- |
| P1 | Tokens are documentation, not the effective source of truth | Separate hardcoded palettes in CSS, XAML, asset generation, Steam, Discord, Chrome and desktop config | One palette catalog and resolver; deterministic generated bundles; adapter mappings consume semantic roles |
| P1 | Identity decoration and functional states are conflated | No on-accent token; warm-white on magenta is 2.73:1, on cyan 1.58:1; functional gradient buttons | Tested action/foreground pairs; independent success, warning, error and focus colors; flag colors remain decorative |
| P1 | Theme selectors can cover host content | Broad Big Picture Panel/Button matches; Store art backgrounds overwritten; Library overlay risks | Explicit real surfaces only; retain native layout, transparent overlays, art, focus geometry and meaningful status colors |
| P1 | Quiet-default promise is false | Infinite motion in website, Discord and start page; accent cycling in optional overlay | Static decoration by default; short interaction transitions; explicit finite celebration; respect reduced motion without suppressing native progress |
| P1 | Rollback does not capture actual state | Windows installer saves a theme path, not wallpaper/settings/theme contents; native editor binary patches found outside the repo | Typed, timestamped backups; preserve wallpaper/cursors/projects; native preference APIs only; never patch application resources |
| P2 | Identity choice is not a foundation capability | Shared exports offer only rainbow/progress; some other palettes exist only in optional overlay | Extensible, attributed palette catalog; reference colors/weights distinct from UI-adjusted accents; neutral and custom choices |
| P2 | Export formats disagree | Missing CSS/XAML roles; invalid implied DTCG schema; light surface gradient stays dark | Explicit project schema and parity tests; no unsupported interoperability claims |
| P2 | Website demonstrates decoration, not a usable system | No palette chooser, no actual control states; contrast metric overlaps copy at 390px; mobile navigation disappears | Working configurator, measured named color pairs, keyboard states, responsive aligned layout and truthful export controls |
| P2 | Coverage claims exceed evidence | No Unity/Blender adapter; broad claims of native/full coverage | Per-app capability and runtime verification states; supported, partial and third-party paths distinguished |
| P2 | Validation checks parsing, not design regressions | Validator only checks JSON syntax and also builds an unrelated executable | Pure token/contrast/parity checks, scoped selector checks, browser tests and separate live-app acceptance |

## Foundation contract

1. **Palette is a preference, not an identity declaration.** Public presets are reusable. Personal selections and generated local profiles are not committed. The catalog is not exhaustive and variant names matter. Progress-inspired color decoration must not be described as the complete geometric flag.
2. **Dark neutrals stay stable.** Canvas, raised surfaces and inputs use low-chroma violet neutrals. Identity accents do not tint every content surface. The selected palette controls decoration and an accessible action accent.
3. **Meaning stays stable.** Error, warning, success, presence, play, downloads, scene colors and material data are not identity colors. Use text/icons as well as color. Keep native app-specific semantics where replacing them would be misleading.
4. **Consistency is role-based.** Shared surfaces, foreground pairs, border roles, focus, spacing and finite motion; not identical app geometry. Retain pane sizing, controller focus, DPI, font metrics and window hit targets.
5. **Generated exports are the delivery unit.** `tokens/palettes.json` + `tokens/theme.mjs` resolve the theme. The generator produces CSS, JSON, XAML and adapter bundles. Editing a generated installed file is not the maintenance workflow.
6. **No default spectacle.** Decorative animation is off. Optional celebration is finite and respects reduced motion. Avoid global animation resets that break progress indicators.
7. **Installation is separate from preview.** The website can preview and export a palette; it cannot claim to apply it to native apps. App adapters must identify support limits, back up exactly what they change and avoid forced restarts.

## Acceptance gates

- Every preset and custom accent resolves to valid colors; action text meets 4.5:1; ordinary text meets 4.5:1 across supported surfaces; essential borders/focus meet 3:1 against their adjacent surfaces.
- CSS/JSON/XAML exports have role parity and reproducible output. Invalid palette/accent values fail clearly.
- No arbitrary host geometry, visibility, artwork or content-paint overrides in Steam. Library Home, game details, Store, menus, downloads, friends/chat, settings and Big Picture each require separate live inspection before claiming complete coverage.
- Website chooser updates preview, exact tokens, measured contrast and exports together. Test 320, 390, 768, 900 and 1280px, keyboard focus, 200% enlargement, error handling and reduced motion.
- Native settings installation preserves wallpaper, cursor, workspace and project preferences unless explicitly selected for change. A saved preference is not a verified live appearance.
- Publish only reusable source and public design assets. Keep local paths, account data, app screenshots, backup state and personal profile selections out of Git.

## Reference basis

- [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html). Arithmetic above uses specified sRGB colors, not a conformance certification of the whole app.
- [Design Tokens Community Group format](https://www.designtokens.org/tr/2025.10/format/).
- [UCSB's non-exhaustive Pride flag glossary](https://rcsgd.sa.ucsb.edu/resources/lgbtqia-informational-resources/pride-flags-glossary).
- [Windows theme format](https://learn.microsoft.com/en-us/windows/win32/controls/themesfileformat-overview), [Blender themes](https://docs.blender.org/manual/en/latest/editors/preferences/themes.html), [Unity theme preferences](https://docs.unity3d.com/6000.4/Documentation/Manual/preferences-general.html).
