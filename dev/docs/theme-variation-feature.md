# Theme Variation Feature Specification

## Overview

Add the ability for users to choose from multiple color scheme variations for both light and dark themes. This extends the existing Theme toggle with a secondary control that allows fine-grained color customization.

## User Story

As a user viewing a Markdown file, I want to choose from different color scheme variations (e.g., different background tones, accent colors) for both light and dark modes, so that I can customize the viewing experience to my preference.

## Current Behavior

- A single "Theme" button in the top-right corner
- Toggles between "System" (follows OS preference) and "Invert" (opposite of OS preference)
- Two color schemes: light and dark (hardcoded)
- Theme mode preference stored in `localStorage` as `mdviewer_theme_mode`

## Proposed Behavior

### New UI Element

Add a second button below the existing Theme button:
- **Label format:** `"Light Theme: <N>"` or `"Dark Theme: <N>"` depending on which theme is currently active
- **Position:** Fixed, below the Theme button (approximately top: 50px or similar)
- **Style:** Matches existing button styling

### Dropdown Menu

When the theme variation button is clicked:
1. A dropdown menu appears anchored to the button
2. Shows a list of available variations (5 variations for the active theme)
3. Each variation is labeled (e.g., "Default", "Warm", "Cool", "Sepia", "High Contrast")

### Preview on Hover

- As the user hovers over each menu item, the page immediately previews that color scheme
- This provides instant visual feedback without committing to the change
- The preview is temporary and does not persist

### Selection

- **Click on a variation:** 
  - That variation becomes the active setting for the current theme (light or dark)
  - The menu closes
  - The selection is persisted to localStorage
  - The button label updates to reflect the new selection

### Dismissal (No Change)

- **Click the button again:** Menu closes, page reverts to previous setting
- **Click anywhere else on the page:** Menu closes, page reverts to previous setting
- **Press Escape key:** Menu closes, page reverts to previous setting

### Persistence

- **Separate storage for light and dark:** Each theme has its own variation preference
  - `mdviewer_light_variation` - stores the light theme variation (e.g., "0", "1", "2", "3", "4")
  - `mdviewer_dark_variation` - stores the dark theme variation (e.g., "0", "1", "2", "3", "4")
- Default variation is "0" (the current/default colors) if no preference is stored

## Theme Variations

### Light Theme Variations (5)

| Index | Name | Description |
|-------|------|-------------|
| 0 | Default | Current white background (#ffffff) |
| 1 | Warm | Cream/ivory tint for reduced eye strain |
| 2 | Cool | Slight blue tint, modern feel |
| 3 | Sepia | Paper-like warm brown tones |
| 4 | High Contrast | Pure white with darker blacks |

### Dark Theme Variations (5)

| Index | Name | Description |
|-------|------|-------------|
| 0 | Default | Current dark background (#0f1115) |
| 1 | Warm | Dark with warmer undertones |
| 2 | Cool | Dark with cooler blue undertones |
| 3 | OLED Black | True black background (#000000) |
| 4 | Dimmed | Lower contrast for nighttime reading |

## UI Mockup

```
┌──────────────────────────────────────────────────────────────────────┐
│                                          ┌─────────────────────────┐ │
│                                          │ Theme: System (Light)   │ │
│                                          └─────────────────────────┘ │
│                                          ┌─────────────────────────┐ │
│                                          │ Light Theme: Default  ▼ │ │
│                                          └─────────────────────────┘ │
│  # Markdown Content                      ┌─────────────────────────┐ │
│                                          │ ○ Default              │ │
│  Lorem ipsum dolor sit amet...           │ ○ Warm                 │ │
│                                          │ ○ Cool                 │ │
│                                          │ ● Sepia      ← hovered │ │
│                                          │ ○ High Contrast        │ │
│                                          └─────────────────────────┘ │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Technical Requirements

### CSS Changes

1. Define CSS custom properties for each variation
2. Use `data-light-var` and `data-dark-var` attributes on `<html>` to select variation
3. Support all combinations: 5 light × 5 dark = 25 possible states

### JavaScript Changes

1. Add new IIFE module for theme variation handling
2. Create dropdown menu dynamically (no HTML changes to Open-Markdown.ps1)
3. Handle hover preview with temporary CSS variable override
4. Handle click-outside and Escape key dismissal
5. Persist selection to localStorage
6. Coordinate with existing theme toggle (re-apply variation when theme changes)

### localStorage Keys

| Key | Type | Values | Description |
|-----|------|--------|-------------|
| `mdviewer_light_variation` | string | "0"-"4" | Light theme variation index |
| `mdviewer_dark_variation` | string | "0"-"4" | Dark theme variation index |

### Button HTML

The button will be dynamically created by JavaScript (similar to how the existing buttons work, but we'll add this one programmatically).

## Acceptance Criteria

1. ✅ A new button appears below the Theme button
2. ✅ Button label shows current theme and variation name
3. ✅ Clicking the button opens a dropdown menu
4. ✅ Menu shows 5 variations for the active theme
5. ✅ Hovering over a menu item previews that color scheme instantly
6. ✅ Clicking a menu item selects it and closes the menu
7. ✅ Clicking elsewhere dismisses the menu without changes
8. ✅ Pressing Escape dismisses the menu without changes
9. ✅ Selection is persisted separately for light and dark themes
10. ✅ Selection survives page reload and applies on load
11. ✅ When theme mode changes (light↔dark), the correct variation is applied
12. ✅ Works correctly with both System and Invert theme modes

## Out of Scope

- Custom user-defined colors (beyond the 5 predefined variations)
- Export/import of theme settings
- Per-document theme preferences (global only)
- Keyboard navigation within the dropdown menu (future enhancement)
