# MSIX Visual Assets

This directory should contain the following PNG files for the MSIX package:

## Required Assets

| File | Size | Description |
|------|------|-------------|
| Square44x44Logo.png | 44x44 | App icon for taskbar, Start menu |
| Square150x150Logo.png | 150x150 | Medium tile |
| Wide310x150Logo.png | 310x150 | Wide tile |
| StoreLogo.png | 50x50 | Store listing icon |

## Optional High-DPI Variants

For better quality on high-DPI displays, also include:

- Square44x44Logo.scale-125.png (55x55)
- Square44x44Logo.scale-150.png (66x66)
- Square44x44Logo.scale-200.png (88x88)
- Square150x150Logo.scale-125.png (188x188)
- Square150x150Logo.scale-150.png (225x225)
- Square150x150Logo.scale-200.png (300x300)

## Creating Assets

Use the existing `markdown.ico` from `src/core/icons/` as the source.
Convert to PNG at required sizes using an image editor or tool like ImageMagick:

```powershell
# Example with ImageMagick
magick src/core/icons/markdown.ico -resize 44x44 Assets/Square44x44Logo.png
magick src/core/icons/markdown.ico -resize 150x150 Assets/Square150x150Logo.png
magick src/core/icons/markdown.ico -resize 310x150 -gravity center -extent 310x150 Assets/Wide310x150Logo.png
magick src/core/icons/markdown.ico -resize 50x50 Assets/StoreLogo.png
```
