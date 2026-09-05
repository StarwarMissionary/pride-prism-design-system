# Pride Prism design contract

## Foundations

Use `tokens/palettes.json` and `tokens/theme.mjs`. Generated exports are the delivery format; adapters map roles onto supported app surfaces. Never maintain a second palette by hand.

- Canvas / raised / muted: stable dark, low-chroma neutrals.
- Foreground / secondary foreground: readable text on all three surfaces.
- Accent / onAccent / hover / pressed: tested solid action pairs. Accent alone is not a text or universal state-indicator token.
- Selection / selectionText: distinct dark fill and readable text. Add a visible check, native selection outline or focus-colored rail when an arbitrary custom accent is too dark.
- Border: essential control boundary. BorderSubtle: decorative separation only.
- Focus / link: independent of identity. Use an offset ring or contrasting separator next to bright controls.
- Positive / warning / negative: stable functional meaning, supplemented with text/icons. Preserve native presence, Play, commerce, charts, material and scene colors.
- Identity gradient: decorative hard-stop rail using reference colors and weights. It is not a functional button fill. Progress-inspired is a palette, not a rendering of the geometric flag.

## Rhythm and symmetry

Use the shared 4/8/12/16/24/32 px spacing scale and 6/12/18 px corner roles in owned UI. Align peer controls and card edges; let cards grow with text. Use 16px body copy on the website and readable label sizes.

Native applications retain their pane widths, window controls, fonts, DPI, controller focus geometry, and layout. Shared roles should make different apps feel related without forcing identical structures. Never paint full-window transparent overlays, wildcard containers or artwork.

## Motion

Default decorative motion is off. Interactions may use 160–280 ms color/border transitions. Explicit celebrations finish within 1.5 seconds. Honor reduced motion and do not run global animation resets that suppress native loading/progress.

The legacy optional overlay is not the foundation configuration system. It is excluded from normal validation builds and native coverage claims.

## Choice and privacy

Palette names are preferences, not required identity labels. Reference colors and proportions are attributed, variants explicit, catalog non-exhaustive. Keep custom accents separate from reference colors. No telemetry or public personal profile; browser preferences stay local.

## Acceptance

Run token/contrast/parity tests, then renderer-specific checks. Ordinary text target: 4.5:1. Essential boundary/focus target: 3:1 against adjacent surfaces. Static contrast arithmetic is not an application-wide WCAG certification. Check keyboard focus, 200% enlargement, 320px width, reduced motion, input/error/disabled/selected states and rollback. See [foundation audit](FOUNDATION_AUDIT.md) for the full release gates.
