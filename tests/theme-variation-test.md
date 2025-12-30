# Theme Variation Test Document

This document is used to test the theme variation feature.

## Text Elements

Regular paragraph text. **Bold text** and *italic text* and `inline code`.

### Links

[This is a link](#) that should change color with the theme.

### Code Block

```javascript
function hello() {
    console.log("Hello, World!");
    return 42;
}
```

### Blockquote

> This is a blockquote that should use the muted color.
> It can span multiple lines.

### Table

| Header 1 | Header 2 | Header 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |

### Lists

1. First ordered item
2. Second ordered item
3. Third ordered item

- Unordered item one
- Unordered item two
- Unordered item three

## Color Reference

Use this section to verify the theme variations are applying correctly:

- **Background** (`--bg`): The page background color
- **Foreground** (`--fg`): This main text color
- **Muted** (`--muted`): The blockquote text above
- **Code Background** (`--codebg`): The code block background
- **Border** (`--border`): Table borders and blockquote border
- **Link** (`--link`): The link color above

## Testing Instructions

1. Click the "Theme" button to switch between System/Invert
2. Click the theme variation button (e.g., "Light Theme: Default")
3. Hover over each variation in the dropdown - the page should preview immediately
4. Click a variation to select it
5. Refresh the page - your selection should persist
6. Switch themes and verify the other theme's variation is independent
