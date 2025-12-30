# Theme Variation Feature - Implementation Plan

## Overview

This document outlines the implementation plan for the Theme Variation feature as specified in [theme-variation-feature.md](theme-variation-feature.md).

## Phase 1: CSS Theme Variations

### 1.1 Define Light Theme Variations

- [x] 1.1.1 Add CSS custom properties for Light Default (variation 0) - existing colors
- [x] 1.1.2 Add CSS custom properties for Light Warm (variation 1)
- [x] 1.1.3 Add CSS custom properties for Light Cool (variation 2)
- [x] 1.1.4 Add CSS custom properties for Light Sepia (variation 3)
- [x] 1.1.5 Add CSS custom properties for Light High Contrast (variation 4)

### 1.2 Define Dark Theme Variations

- [x] 1.2.1 Add CSS custom properties for Dark Default (variation 0) - existing colors
- [x] 1.2.2 Add CSS custom properties for Dark Warm (variation 1)
- [x] 1.2.3 Add CSS custom properties for Dark Cool (variation 2)
- [x] 1.2.4 Add CSS custom properties for Dark OLED Black (variation 3)
- [x] 1.2.5 Add CSS custom properties for Dark Dimmed (variation 4)

### 1.3 CSS Selectors for Variations

- [x] 1.3.1 Use `[data-theme="light"][data-variation="N"]` selectors
- [x] 1.3.2 Use `[data-theme="dark"][data-variation="N"]` selectors
- [x] 1.3.3 Ensure default (variation 0) works without data-variation attribute

### 1.4 Dropdown Menu Styling

- [x] 1.4.1 Add `.mv-var-menu` styles for dropdown container
- [x] 1.4.2 Add `.mv-var-item` styles for menu items
- [x] 1.4.3 Add `.mv-var-item:hover` styles for hover state
- [x] 1.4.4 Add `.mv-var-item.active` styles for current selection

## Phase 2: JavaScript Theme Variation Logic

### 2.1 Theme Variation State Management

- [x] 2.1.1 Add localStorage keys: `mdviewer_light_variation`, `mdviewer_dark_variation`
- [x] 2.1.2 Create `getVariation(theme)` function to read from localStorage
- [x] 2.1.3 Create `setVariation(theme, index)` function to save to localStorage
- [x] 2.1.4 Define variation names array: `["Default", "Warm", "Cool", "Sepia/OLED", "High Contrast/Dimmed"]`

### 2.2 Apply Variation on Page Load

- [x] 2.2.1 Read variation for current theme from localStorage
- [x] 2.2.2 Set `data-variation` attribute on `<html>` element
- [x] 2.2.3 Coordinate with existing theme toggle (when theme changes, re-apply correct variation)

### 2.3 Create Variation Button

- [x] 2.3.1 Create button element dynamically after Theme button
- [x] 2.3.2 Set button ID to `mvVariation`
- [x] 2.3.3 Update button label to show current theme and variation name

### 2.4 Dropdown Menu

- [x] 2.4.1 Create menu container dynamically on button click
- [x] 2.4.2 Populate menu with 5 items for current theme
- [x] 2.4.3 Position menu below button (or above if not enough space)
- [x] 2.4.4 Mark current variation as active

### 2.5 Preview on Hover

- [x] 2.5.1 On mouseenter of menu item, set `data-variation` attribute temporarily
- [x] 2.5.2 Store original variation before preview
- [x] 2.5.3 On mouseleave of menu (without selection), restore original variation

### 2.6 Selection and Dismissal

- [x] 2.6.1 On click of menu item, save selection and close menu
- [x] 2.6.2 On click outside menu, close menu and restore original
- [x] 2.6.3 On Escape key, close menu and restore original
- [x] 2.6.4 On button re-click (while menu open), close menu and restore original

### 2.7 Integration with Theme Toggle

- [x] 2.7.1 When theme changes via Theme button, apply the correct variation for new theme
- [x] 2.7.2 Update Variation button label when theme changes

## Phase 3: Unit Tests

### 3.1 CSS Tests (Visual/Manual)

- [x] 3.1.1 Create test markdown file with various elements to verify all variations render correctly

### 3.2 JavaScript Logic Tests

Since the JS runs in the browser, we'll create a test HTML file that can be used to verify behavior:

- [x] 3.2.1 Create `tests/theme-variation-test.md` for manual testing
- [x] 3.2.2 Test variation persistence across page reload
- [x] 3.2.3 Test preview-on-hover behavior
- [x] 3.2.4 Test dismissal scenarios (click outside, Escape, re-click button)
- [x] 3.2.5 Test theme toggle coordination

### 3.3 Integration Tests

- [x] 3.3.1 Test that generated HTML includes the new CSS
- [x] 3.3.2 Test that generated HTML includes the new JS
- [x] 3.3.3 Verify button appears in rendered output

## Phase 4: Documentation Updates

- [x] 4.1 Update README.md with theme variation feature description
- [x] 4.2 Update architecture document

## Implementation Details

### CSS Color Values

#### Light Theme Variations

```css
/* Light Default (0) - existing */
--bg: #ffffff; --fg: #111111; --muted: #444; --codebg: #f4f4f4; --border: #dddddd; --link: #0b57d0;

/* Light Warm (1) */
--bg: #fdfbf7; --fg: #1a1815; --muted: #5c5347; --codebg: #f5f0e8; --border: #e5ddd0; --link: #8b5c2a;

/* Light Cool (2) */
--bg: #f8fafc; --fg: #0f172a; --muted: #475569; --codebg: #f1f5f9; --border: #e2e8f0; --link: #2563eb;

/* Light Sepia (3) */
--bg: #f4ecd8; --fg: #2c2416; --muted: #5c5040; --codebg: #ebe3cf; --border: #d4c9b0; --link: #7c4d12;

/* Light High Contrast (4) */
--bg: #ffffff; --fg: #000000; --muted: #333333; --codebg: #f0f0f0; --border: #000000; --link: #0000cc;
```

#### Dark Theme Variations

```css
/* Dark Default (0) - existing */
--bg: #0f1115; --fg: #e7e7e7; --muted: #b8b8b8; --codebg: #1b1f2a; --border: #2a2f3a; --link: #7ab7ff;

/* Dark Warm (1) */
--bg: #1a1614; --fg: #e8e2dc; --muted: #b5a899; --codebg: #252019; --border: #3a332a; --link: #e0a870;

/* Dark Cool (2) */
--bg: #0c1222; --fg: #e2e8f0; --muted: #94a3b8; --codebg: #1e293b; --border: #334155; --link: #60a5fa;

/* Dark OLED Black (3) */
--bg: #000000; --fg: #ffffff; --muted: #a0a0a0; --codebg: #0a0a0a; --border: #222222; --link: #6db3f2;

/* Dark Dimmed (4) */
--bg: #161b22; --fg: #c9d1d9; --muted: #8b949e; --codebg: #21262d; --border: #30363d; --link: #58a6ff;
```

### Variation Names

```javascript
const lightNames = ["Default", "Warm", "Cool", "Sepia", "High Contrast"];
const darkNames = ["Default", "Warm", "Cool", "OLED Black", "Dimmed"];
```

### Button Position

```css
#mvVariation {
    position: fixed;
    top: 50px;  /* Below Theme button (14px) + button height (~30px) + gap */
    right: 14px;
    /* Same styling as other buttons */
}

/* If Images button exists, it moves down */
#mvImages {
    top: 86px;  /* Below Variation button */
}
```

## Execution Order

1. **Phase 1.1-1.3:** Add all CSS variations to `style.css`
2. **Phase 1.4:** Add dropdown menu CSS
3. **Phase 2.1-2.7:** Implement JavaScript in `script.js`
4. **Phase 3:** Create test files and verify behavior
5. **Phase 4:** Update documentation

## Testing Checklist

- [x] Variation button appears below Theme button
- [x] Button label shows correct theme (Light/Dark) and variation name
- [x] Clicking button opens dropdown menu
- [x] Menu shows 5 items with correct names for current theme
- [x] Current variation is visually marked in menu
- [x] Hovering over item previews that color scheme
- [x] Clicking item saves selection and closes menu
- [x] Clicking elsewhere closes menu without saving
- [x] Pressing Escape closes menu without saving
- [x] Re-clicking button closes menu without saving
- [x] Selection persists after page reload
- [x] Switching theme mode applies correct variation for new theme
- [x] All 5 light variations render correctly
- [x] All 5 dark variations render correctly
- [x] Images button (if present) positions correctly below Variation button
