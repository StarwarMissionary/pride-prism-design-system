# Pride Prism usage guide

## Principles

1. Pride is unmistakable through color order and Progress Pride accents, not visual noise.
2. Text contrast and task legibility take priority over decoration.
3. Native theming is preferred over client patching or process injection.
4. Motion is opt-in, slow, and disabled for reduced-motion users.
5. A celebration action may temporarily increase energy; the resting state remains calm.

## Color usage

- Use deep violet as the dark surface and warm white for primary text.
- Use magenta for focus and selected states.
- Use the full rainbow for borders, headers, illustrations, and non-text decoration.
- Keep yellow away from small white text; use dark text on yellow.
- Preserve semantic meaning: green is positive, red is destructive/error, yellow is caution.

## Motion usage

- Standard UI transitions: 160–280 ms.
- Decorative gradient travel: at least 1.2 seconds per step.
- Accent cycling: at least 5 seconds per color.
- Do not run continuous confetti, strobe, or full-screen flashes.
- Celebration bursts should end automatically within six seconds.

## Accessibility

- Target WCAG AA contrast for body text.
- Respect `prefers-reduced-motion` and Windows reduced-motion settings.
- Never use color as the only status indicator.
- Keep click targets and content unobstructed.
