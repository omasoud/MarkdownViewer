# Vendored KaTeX Runtime

- Version: `0.18.3`
- Release: https://github.com/KaTeX/KaTeX/releases/tag/v0.18.3
- Source artifact: `katex.zip`
- Source artifact SHA-256: `cbc574abcc6471182690afbead76a27aa7c0276b523614a834aad0e0580d8e17`
- License: MIT; see `LICENSE`

## Runtime inventory

Markdown Viewer ships the official minified browser runtime without modification:

| File | SHA-256 |
|---|---|
| `katex.min.js` | `131beffe9e8d48e06ee969e298190127b230f17c656e6b6c471a705406b7d655` |
| `katex.min.css` | `7993c99e764314d0d6ee0a926c3ac0a75a89182ff58493f9d40310c5e932003f` |

The `fonts/` directory contains the 20 KaTeX font families in each of the TTF,
WOFF, and WOFF2 formats referenced by the official stylesheet. The viewer does
not ship KaTeX auto-render, contrib extensions, source maps, demos, or package
manager metadata.

## Update procedure

1. Download the release `katex.zip` from the upstream GitHub release.
2. Verify its SHA-256 against the digest published in the GitHub release asset metadata.
3. Replace `katex.min.js`, `katex.min.css`, and `fonts/` from that archive.
4. Replace `LICENSE` from the same tagged upstream source.
5. Update the version and hashes above and in `THIRD-PARTY-LICENSES.md`.
6. Run `tests/pwsh/MathSupport.Tests.ps1` and the platform packaging tests.

Do not add the auto-render extension. Markdown recognition belongs to
`ConvertFrom-Markdown`; the viewer typesets only its emitted `.math` elements.
