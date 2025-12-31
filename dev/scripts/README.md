# Notes Regarding Highlight.js 

## Highlight.js

Highlight.js is downloaded from https://highlightjs.org/download
with "all languages" selected (192 total)

The payload bundled js is `.\highlight.min.js` (~1MB) from the downloaded package (~10MB zipped).


## Code Highlight Theme

The dark+light code highlight theme payload bundled (`highlight-theme.css`) is from `tomorrow.css` and `tomorrow-night.css` generated via:

```powershell
.\Convert-HljsTheme.ps1 `
  -LightTheme "styles\base16\tomorrow.css" `
  -DarkTheme "styles\base16\tomorrow-night.css" `
  -OutputPath "highlight-theme.css"
```
  
It would be possible to replace that with another one (or potentially make a selectable "code highlight theme"). For example, here's the one based on github:

```powershell
.\Convert-HljsTheme.ps1 `
   -LightTheme "styles\github.css" `
   -DarkTheme "styles\github-dark.css" `
   -OutputPath "highlight-theme-github.css
```

## Languages

Given a `highlight.js` or `highlight.min.js` file, supported languages can be seen by running 

```powershell
.\dev\scripts\Get-HljsLanguageInfo.ps1 .\dev\scripts\highlight.min.js
```

Without parameters, it uses the default minified web build (online).