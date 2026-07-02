# Security Policy

## Supported Versions

Security fixes are supported for the latest released version of MarkView across
the currently published distribution channels:

- Microsoft Store for Windows
- GitHub Releases for macOS
- Snap Store for Linux

Older releases may receive fixes at the maintainer's discretion, but users
should expect to upgrade to the latest release for security updates.

## Reporting a Vulnerability

Please do not report suspected security vulnerabilities in public GitHub issues.

Use GitHub private vulnerability reporting from the repository Security tab when
available. If private vulnerability reporting is unavailable, open a public issue
asking for a private contact method, but do not include vulnerability details.

When reporting, include:

- the affected MarkView version;
- the operating system and install channel;
- steps to reproduce the issue;
- the impact you believe the issue has;
- any relevant sample Markdown files, logs, screenshots, or generated HTML with
  personal information removed.

Please do not include real credentials, private documents, access tokens, or
other secrets in the report.

The maintainer will make a best effort to acknowledge reports within 7 days and
provide an initial assessment within 14 days. Confirmed vulnerabilities will be
handled privately until a fix, release, and advisory are ready when appropriate.

## Security-Sensitive Areas

Reports are especially useful for issues involving:

- script execution or HTML sanitization bypasses in rendered Markdown;
- Content Security Policy bypasses;
- unsafe handling of `mdview:` protocol links;
- local-file path traversal, unexpected file access, or linked-file navigation
  outside the intended document workflow;
- remote image loading behavior or unexpected network access;
- unsafe generated HTML, temporary-file, or cache handling;
- Windows MSIX, macOS DMG, Snap, bundled PowerShell, signing, notarization, or
  release-process weaknesses.

## Scope and Non-Goals

MarkView is a local desktop Markdown viewer that renders user-selected Markdown
files in the user's browser. General support questions, formatting differences,
theme issues, or expected behavior from user-provided Markdown should use the
normal issue tracker.

This project does not currently offer a paid vulnerability bounty program.
