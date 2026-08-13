# Math typesetting test

This document exercises Markdown Viewer's offline KaTeX integration. All
expressions should render without a network connection.

## Inline math

Einstein's relation is $E = mc^2$, a quadratic can be written as
$f(x) = ax^2 + bx + c$, and a Greek-letter example is
$\alpha + \beta = \gamma$.

Inline math should remain in the sentence before and after $x_1 + x_2 = 10$
without changing the line height excessively.

Unicode symbols should render in $x ∈ ℝ,\; x ≥ 0$, and math can sit beside a
[fragment link](#display-math) without changing that link.

## Display math

The quadratic formula:

$$
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
$$

A finite sum:

$$
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
$$

A long equation should remain horizontally accessible at narrow widths:

$$
\left(\sum_{k=1}^{n} a_k b_k\right)^2
\leq
\left(\sum_{k=1}^{n} a_k^2\right)
\left(\sum_{k=1}^{n} b_k^2\right)
$$

A matrix:

$$
\begin{bmatrix}
1 & 2 \\
3 & 4
\end{bmatrix}
\begin{bmatrix}
x \\
y
\end{bmatrix}
=
\begin{bmatrix}
5 \\
6
\end{bmatrix}
$$

## Text that must not become math

- Currency remains ordinary text when escaped: \$12.50 and \$1,249.00.
- A dollar sign in `inline code` remains literal: `$not_math$`.
- A fenced code block is never typeset:

```powershell
$total = 12.50
Write-Output '$x^2$'
```

## Malformed and large-source fallback

The following deliberately malformed expression should remain readable and
must not prevent the rest of the page from working:

$\frac{1}{$

## Interaction checks

[Jump to the display-math section](#display-math)

After using the link above, theme switching, syntax highlighting, and math
typesetting should all continue to work.
