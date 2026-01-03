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

**Open source (GitHub):** https://github.com/omasoud/MarkdownViewer
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
                BackColor = BgColor,
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
                DetectUrls = true,
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

            // 2. BOTTOM PANEL (Buttons)
            var bottomPanel = new Panel();
            bottomPanel.Height = 60;
            bottomPanel.Dock = DockStyle.Bottom;
            bottomPanel.BackColor = SystemColors.Control;

            // FIX: Force panel to match form width immediately so coordinate math works
            bottomPanel.Width = form.ClientSize.Width;

            var line = new Label { Height = 1, Dock = DockStyle.Top, BackColor = Color.LightGray };
            bottomPanel.Controls.Add(line);

            var btnDefault = new Button { Text = "Open Default Apps Settings", Size = new Size(200, 30) };
            // FIX: Position relative to the PANEL
            btnDefault.BackColor = Color.FromArgb(0, 120, 215);
            btnDefault.ForeColor = Color.White;
            btnDefault.FlatStyle = FlatStyle.Flat;
            btnDefault.FlatAppearance.BorderSize = 0;
            btnDefault.Cursor = Cursors.Hand;
            //btnDefault.Location = new Point(bottomPanel.Width - 330, 15);
            btnDefault.Location = new Point(20, 15);
            btnDefault.Anchor = AnchorStyles.Right | AnchorStyles.Top;
            btnDefault.Click += (s, e) => OpenDefaultAppsSettings();

            var btnClose = new Button { Text = "Close", Size = new Size(100, 30) };
            // FIX: Position relative to the PANEL, not the FORM
            //btnClose.Location = new Point(bottomPanel.Width - 120, 15);
            btnClose.Location = new Point(btnDefault.Right + 10, 15);
            btnClose.BackColor = Color.FromArgb(220, 220, 220);
            btnClose.ForeColor = Color.Black;
            btnClose.FlatStyle = FlatStyle.Flat;
            btnClose.FlatAppearance.BorderSize = 0;
            btnClose.Cursor = Cursors.Hand;
            btnClose.Anchor = AnchorStyles.Right | AnchorStyles.Top;
            btnClose.Click += (s, e) => form.Close();




            bottomPanel.Controls.Add(btnClose);
            bottomPanel.Controls.Add(btnDefault);

            // Add to form
            form.Controls.Add(split);

            form.Controls.Add(bottomPanel);

            form.ShowDialog();
        }

        private static void ColorizeSource(RichTextBox rtb)
        {
            string[] lines = rtb.Text.Split('\n');
            int currentPos = 0;

            foreach (var line in lines)
            {
                // We must select the actual range in the RTB
                // Note: RichTextBox "lines" can vary with word wrap, so simpler to regex 
                // or iterate text, but for this static content, line-by-line works if we track length.

                int len = line.Length;

                // Headers
                if (line.Trim().StartsWith("#"))
                {
                    rtb.Select(currentPos, len);
                    rtb.SelectionColor = HeaderColor;
                }
                // Bullets
                else if (line.Trim().StartsWith("*") || line.Trim().StartsWith("-"))
                {
                    rtb.Select(currentPos, len);
                    rtb.SelectionColor = BoldColor;
                }
                // Image Syntax ![...]
                else if (line.Trim().StartsWith("!["))
                {
                    rtb.Select(currentPos, len);
                    rtb.SelectionColor = ImageTagColor;
                }

                currentPos += len + 1; // +1 for the newline char we split on
            }
            rtb.Select(0, 0);
        }

        private static void OpenDefaultAppsSettings()
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "ms-settings:defaultapps",
                UseShellExecute = true
            });
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