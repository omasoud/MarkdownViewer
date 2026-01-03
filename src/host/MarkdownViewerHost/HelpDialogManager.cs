#define DEBUG

using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Windows.Forms;
using System.Diagnostics;


namespace MarkdownViewerHost
{
    public static class HelpDialogManager
    {
        // --- 1) RAW MARKDOWN (Source View) ---
        // Keep this short enough to avoid scrolling in common window sizes.
        private const string MarkdownContent =
@"# MarkView
### Markdown Viewer for Windows

MarkView renders local `.md` files in your browser — fast, clean, and safe.

> **Primary usage:** you normally *open a markdown file with MarkView* (you don’t start here).

## How to use

**Option A — Open With**
- Right-click a `.md` → **Open with…** → **MarkView**

**Option B — Make default**
- Set **MarkView** as the default app for `.md`
- Then double-click any `.md`

## Highlights

- Dark mode + themes
- Code syntax highlighting
- Linked local `.md` files supported
- Secure by default (CSP + sanitization; MOTW; network blocked; optional remote images)

**Open source (GitHub):** [github.com/omasoud/MarkdownViewer](https://github.com/omasoud/MarkdownViewer)
";

        // --- 2) HTML TEMPLATE (Rendered View) ---
        // We use a format placeholder {0} to inject the icon as Base64 later.
        private const string HtmlTemplate = @"
<html>
<head>
  <meta http-equiv='X-UA-Compatible' content='IE=edge' />
  <style>
    body {{
      font-family: 'Segoe UI', Helvetica, sans-serif;
      background: #fff;
      color: #333;
      padding: 10px;
      font-size: 14px;
      line-height: 1.35;
      margin: 0;
      overflow: hidden; /* keep it clean; prefer content that doesn't need scrolling */
    }}

    h1 {{
      font-size: 30px;
      margin: 0 0 6px 0;
      color: #000;
      font-weight: 600;
    }}

    h3 {{
      font-size: 16px;
      font-weight: 500;
      color: #666;
      margin: 0 0 14px 0;
      padding-bottom: 0px;
      border-bottom: 1px solid #2a2a2a;
    }}

    h2 {{
      font-size: 20px;
      margin: 18px 0 10px 0;
      padding-bottom: 5px;
      border-bottom: 1px solid #2a2a2a;
      color: #333;
      font-weight: 600;
    }}

    p {{ margin: 10px 0; }}

    ul {{
      padding-left: 22px;
      margin: 8px 0 0 0;
    }}

    li {{ margin: 6px 0; }}

    strong {{ font-weight: 600; }}

    code {{
      background: #def;
      color: #2d2d2d;
      padding: 2px 6px;
      border-radius: 6px;
      font-family: Consolas, monospace;
      font-size: 90%;
    }}

    blockquote {{
      border-left: 2px solid #3a3a3a;
      color: #232323;
      padding: 0px 12px;
      margin: 12px 0 0 0;
      background: #eee;
      border-radius: 6px;
    }}

    img {{
      width: 64px;
      height: 64px;
      float: right;
      margin-left: 18px;
      margin-top: 4px;
      border-radius: 10px;
    }}

    a {{
      color: #4ea1ff;
      text-decoration: none;
    }}

    a:hover {{
      text-decoration: underline;
    }}

    .footer {{
      margin-top: 18px;
      font-size: 12px;
      color: #bdbdbd;
      padding-top: 5px;
      border-top: 1px solid #2a2a2a;
    }}
  </style>
</head>
<body>
  <img src='data:image/png;base64,{0}' onerror=""this.style.display='none'"" />

  <h1>MarkView</h1>
  <h3>Markdown Viewer for Windows</h3>

  <p>MarkView renders local <code>.md</code> files in your browser — fast, clean, and safe.</p>

  <blockquote><strong>Primary usage:</strong> you normally <em>open a markdown file with MarkView</em> (you don’t start here).</blockquote>

  <h2>How to use</h2>

  <p><strong>Option A — Open With</strong></p>
  <ul>
    <li>Right-click a <code>.md</code> &#8594; <strong>Open with…</strong> &#8594; <strong>MarkView</strong></li>
  </ul>

  <p style='margin-top:14px;'><strong>Option B — Make default</strong></p>
  <ul>
    <li>Set <strong>MarkView</strong> as the default app for <code>.md</code></li>
    <li>Then double-click any <code>.md</code> file</li>
  </ul>

  <h2>Highlights</h2>
  <ul>
    <li>Dark mode + themes</li>
    <li>Code syntax highlighting</li>
    <li>Linked local <code>.md</code> files supported</li>
    <li>Secure by default (CSP + sanitization; MOTW; network blocked; optional remote images)</li>
  </ul>

  <div class='footer'>
    <strong>Open source (GitHub):</strong>
    <a href='https://github.com/omasoud/MarkdownViewer'>github.com/omasoud/MarkdownViewer</a>
  </div>
</body>
</html>";

        // --- COLORS FOR SOURCE VIEW (VS Code Dark Theme) ---
        private static readonly Color BgColor = Color.FromArgb(30, 30, 30);
        private static readonly Color TextColor = Color.FromArgb(212, 212, 212);
        private static readonly Color HeaderColor = Color.FromArgb(86, 156, 214);      // blue
        private static readonly Color ListColor = Color.FromArgb(206, 145, 120);        // orange
        private static readonly Color QuoteColor = Color.FromArgb(181, 206, 168);       // green-ish
        private static readonly Color LinkColor = Color.FromArgb(78, 161, 255);         // link blue
        private static readonly Color BoldColor = Color.FromArgb(206, 145, 120); // Orange
        private static readonly Color ImageTagColor = Color.FromArgb(106, 153, 85); // Green 
        public static void ShowHelpDialog()
        {
            using var form = new Form
            {
                Text = "MarkView - Welcome",
                StartPosition = FormStartPosition.CenterScreen,
                FormBorderStyle = FormBorderStyle.FixedSingle,
                MaximizeBox = false,
                MinimizeBox = false,
                ClientSize = new Size(920, 660),
                BackColor = Color.White,
                KeyPreview = true
            };

            // Handle Escape key to close the dialog
            form.KeyDown += (s, e) =>
            {
                if (e.KeyCode == Keys.Escape)
                {
                    form.Close();
                }
            };

            // 1. PREPARE THE ICON (Convert to Base64 for HTML)
            var assembly = Assembly.GetExecutingAssembly();
            using var stream = assembly.GetManifestResourceStream("AppIconResource");
            string iconBase64 = "";

            if (stream != null)
            {
                // Set Window Icon
                form.Icon = new Icon(stream);

                // Convert high-res version to Base64 for the WebBrowser
                using var highRes = IconHelper.GetIconBySize(stream, 256);
                if (highRes != null)
                {
                    using var ms = new MemoryStream();
                    highRes.Save(ms, ImageFormat.Png);
                    iconBase64 = Convert.ToBase64String(ms.ToArray());
                }
            }


            // // 3. SPLIT CONTAINER (The Content)
            // var split = new SplitContainer();
            // split.Dock = DockStyle.Fill; // Fills whatever space is left ABOVE the bottom panel
            // split.SplitterDistance = (int)(form.Width * 0.90); // 60% Left
            // split.IsSplitterFixed = true;
            // split.BackColor = SystemColors.ControlLight;
            // form.Controls.Add(split);

            // --- LAYOUT: SPLIT CONTAINER ---
            // var split = new SplitContainer();
            // split.Dock = DockStyle.Fill;
            // split.SplitterDistance = (int)(85); // 90% Left
            // split.Orientation = Orientation.Vertical;
            // split.SplitterWidth = 1; // Thin elegant line
            // split.BackColor = Color.LightGray; // Color of the divider line
            var split = new SplitContainer
            {
                Dock = DockStyle.Fill,
                Orientation = Orientation.Vertical,
                SplitterWidth = 1,
                BackColor = Color.FromArgb(42, 42, 42),
                IsSplitterFixed = true
            };

            void SetSplit()
            {
                // 60% left, 40% right
                split.SplitterDistance = (int)(split.ClientSize.Width * 0.57);
            }

            form.Shown += (_, __) =>
            {
                // ensure it runs after first layout/paint
                form.BeginInvoke(new Action(SetSplit));
            };

            // write a lot of noise to debug console to test that output is visible
            Debug.WriteLine("--------------------------------------------------");
            Debug.WriteLine("DEBUG NOISE START");
            Debug.WriteLine("--------------------------------------------------");
            // print form.ClientSize.Width and split.Width
            Debug.WriteLine($"Form ClientSize Width: {form.ClientSize.Width}");
            Debug.WriteLine($"Split Width: {split.Width}");


            // Set split ratio AFTER ClientSize is known (use ClientSize, not Width)
            //split.SplitterDistance = (int)(form.ClientSize.Width * 0.092);


            // Ensure visual stacking order
            // bottomPanel.SendToBack();
            // split.BringToFront();

            // 4. LEFT PANE: RENDERED VIEW
            var browser = new WebBrowser
            {
                Dock = DockStyle.Fill,
                ScriptErrorsSuppressed = true,
                AllowNavigation = true, // we intercept external links and open them in default browser
                IsWebBrowserContextMenuEnabled = false,
                WebBrowserShortcutsEnabled = false,
                ScrollBarsEnabled = false
            };

            browser.Navigating += (_, e) =>
            {
                if (e?.Url == null) return;

                // WebBrowser always starts at about:blank for DocumentText.
                if (!e.Url.ToString().Equals("about:blank", StringComparison.OrdinalIgnoreCase))
                {
                    e.Cancel = true;
                    TryOpenExternal(e.Url.ToString());
                }
            };

            browser.DocumentText = string.Format(HtmlTemplate, iconBase64);
            split.Panel1.Controls.Add(browser);

            // --- RIGHT PANE: Source view ---
            var rtb = new RichTextBox
            {
                Dock = DockStyle.Fill,
                BackColor = BgColor,
                ForeColor = TextColor,
                Font = new Font("Consolas", 10, FontStyle.Regular),
                BorderStyle = BorderStyle.None,
                ReadOnly = true,
                WordWrap = true,
                ScrollBars = RichTextBoxScrollBars.None,
                DetectUrls = false,
                Text = MarkdownContent
            };

            rtb.LinkClicked += (_, e) =>
            {
                if (!string.IsNullOrWhiteSpace(e?.LinkText))
                {
                    TryOpenExternal(e.LinkText);
                }
            };
            ColorizeSource(rtb);

            split.Panel2.Controls.Add(rtb);

            // --- BOTTOM PANEL (buttons) ---
            var bottomPanel = new Panel
            {
                Dock = DockStyle.Bottom,
                Height = 58,
                BackColor = SystemColors.Control,
            };

            var divider = new Panel
            {
                Dock = DockStyle.Top,
                Height = 1,
                BackColor = Color.LightGray
            };
            bottomPanel.Controls.Add(divider);

            var buttons = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                FlowDirection = FlowDirection.LeftToRight,
                WrapContents = false,
                BackColor = SystemColors.Control
            };

            var btnDefault = CreateButton("Open Default Apps Settings", new Size(220, 32), Color.FromArgb(0, 120, 215), Color.White);
            btnDefault.Click += (_, __) => OpenDefaultAppsSettings();

            var btnClose = CreateButton("Close", new Size(110, 32), Color.FromArgb(220, 220, 220), Color.Black);
            btnClose.Click += (_, __) => form.Close();

            // Order matters (RightToLeft flow): add Close first so it ends up far right.
            buttons.Controls.Add(btnDefault);
            buttons.Controls.Add(btnClose);

            bottomPanel.Controls.Add(buttons);

            // Add controls: Fill first, then Bottom (no z-order hacks needed)
            form.Controls.Add(split);
            form.Controls.Add(bottomPanel);

            form.ShowDialog();
        }

        private static Button CreateButton(string text, Size size, Color backColor, Color foreColor)
        {
            var btn = new Button
            {
                Text = text,
                Size = size,
                BackColor = backColor,
                ForeColor = foreColor,
                FlatStyle = FlatStyle.Flat,
                Cursor = Cursors.Hand,
                Margin = new Padding(10, 15, 0, 0)
            };
            btn.FlatAppearance.BorderSize = 0;
            return btn;
        }

        private static void ColorizeSource(RichTextBox rtb)
        {
            // Important: use line indices + GetFirstCharIndexFromLine() to avoid CRLF offset drift.
            var lines = rtb.Lines;

            // Reset
            rtb.SelectAll();
            rtb.SelectionColor = TextColor;

            // rtb.Select(0, 5);
            // rtb.SelectionColor = Color.Pink;

            //     rtb.WordWrap = false;
            // for (int i = 0; i < lines.Length; i++)
            // {
            //     Debug.WriteLine($"Line {i}: {lines[i]}");
            //     var line = lines[i] ?? string.Empty;
            //     int start = rtb.GetFirstCharIndexFromLine(i);
            //     int len = line.Length;
            //     Debug.WriteLine($"Start index: {start}, Length: {len}");
            //     if (i==4)
            //     {
            //         rtb.Select(start, 5);
            //         rtb.SelectionColor = Color.Pink;
            //     }
            // }            
            //     rtb.WordWrap = true;
            for (int i = 0; i < lines.Length; i++)
            {
                Debug.WriteLine($"Line {i}: {lines[i]}");
                var line = lines[i] ?? string.Empty;
            rtb.WordWrap = false;
                int start = rtb.GetFirstCharIndexFromLine(i);
            rtb.WordWrap = true;
                Debug.WriteLine($"Start index: {start}");
                if (start < 0) continue;

                int len = line.Length;
                if (len <= 0) continue;

                //string trimmed = line.TrimStart();
                string trimmed = line;

                if (trimmed.StartsWith("#", StringComparison.Ordinal))
                {
                    rtb.Select(start, len);
                    rtb.SelectionColor = HeaderColor;
                }
                else if (trimmed.StartsWith("-", StringComparison.Ordinal) ||
                         trimmed.StartsWith("*", StringComparison.Ordinal) ||
                         trimmed.StartsWith("•", StringComparison.Ordinal))
                {
                    rtb.Select(start, len);
                    rtb.SelectionColor = ListColor;
                }
                else if (trimmed.StartsWith(">", StringComparison.Ordinal))
                {
                    rtb.Select(start, len);
                    rtb.SelectionColor = QuoteColor;
                }

                // Color bare URLs as links (DetectUrls will also underline; this helps visibility on dark bg).
                if (line.Contains("http://", StringComparison.OrdinalIgnoreCase) ||
                    line.Contains("https://", StringComparison.OrdinalIgnoreCase))
                {
                    rtb.Select(start, len);
                    // Keep quote/list/header colors if already applied; only override if it's plain text.
                    //if (rtb.SelectionColor == TextColor)
                        rtb.SelectionColor = LinkColor;
                }
            }

            rtb.Select(0, 0);
        }

        private static void OpenDefaultAppsSettings()
        {
            TryOpenExternal("ms-settings:defaultapps");
        }
        private static void TryOpenExternal(string target)
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = target,
                    UseShellExecute = true
                });
            }
            catch
            {
                // intentionally ignore (help dialog should never crash)
            }
        }

    }
}