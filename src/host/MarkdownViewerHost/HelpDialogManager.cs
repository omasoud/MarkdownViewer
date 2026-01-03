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
        // --- 1. RAW MARKDOWN (Source View) ---
        private const string MarkdownContent =
@"# MarkView
### Markdown Viewer for Windows

![Icon](icon.png)

MarkView renders local `.md` files in your browser — fast, clean, and safe.

## Use it like this
* Right-click a `.md` → **Open with…** → **MarkView**
* Or set MarkView as the default app for `.md` files, then double-click

## Highlights
* Dark mode + themes
* Code highlighting
* Secure by default (CSP + sanitization; network blocked; optional remote images)

> MarkView is the official Windows app for the open-source **MarkdownViewer** project.
---
**Open source (GitHub):** github.com/omasoud/MarkdownViewer";

        // --- 2. HTML TEMPLATE (Rendered View) ---
        // We use a format placeholder {0} to inject the Icon Base64 string later
        private const string HtmlTemplate = @"
<html>
<head>
    <style>
        body {{ font-family: 'Segoe UI', Helvetica, sans-serif; color: #333; padding: 10px; font-size: 14px; line-height: 1.3; overflow: hidden; }}
        h1 {{ font-size: 26px; margin-bottom: 5px; color: #000; margin-top: 0; }}
        h3 {{ font-size: 16px; font-weight: normal; color: #666; margin-top: 0; margin-bottom: 15px; border-bottom: 1px solid #eee; padding-bottom: 0px;}}
        h2 {{ font-size: 18px; margin-top: 20px; margin-bottom: 8px; border-bottom: 1px solid #eee; padding-bottom: 5px; color: #333; }}
        ul {{ padding-left: 20px; margin-top: 5px; }}
        li {{ margin-bottom: 4px; }}
        strong {{ font-weight: 600; }}
        code {{ background-color: #f6f8fa; padding: 2px 4px; border-radius: 3px; font-family: Consolas, monospace; font-size: 90%; color: #d63384; }}
        blockquote {{ border-left: 4px solid #dfe2e5; color: #6a737d; padding-left: 15px; margin: 10px 0; }}
        img {{ width: 64px; height: 64px; float: right; margin-left: 20px; }}
        a {{ color: #0366d6; text-decoration: none; }}
        a:hover {{ text-decoration: underline; }}
        .footer {{ margin-top: 20px; font-size: 12px; color: #666; border-top: 1px solid #eee; padding-top: 5px; }}
    </style>
</head>
<body>
    <img src='data:image/png;base64,{0}' />

    <h1>MarkView</h1>
    <h3>Markdown Viewer for Windows</h3>

    <p>MarkView renders local <code>.md</code> files in your browser — fast, clean, and safe.</p>

    <h2>Use it like this</h2>
    <ul>
        <li>Right-click a <code>.md</code> &#8594; <strong>Open with…</strong> &#8594; <strong>MarkView</strong></li>
        <li>Or set MarkView as the default app for <code>.md</code>, then double-click</li>
    </ul>

    <h2>Highlights</h2>
    <ul>
        <li>Dark mode + themes</li>
        <li>Code highlighting</li>
        <li>Secure by default (CSP + sanitization; network blocked)</li>
    </ul>

    <blockquote>MarkView is the official Windows app for the open-source <strong>MarkdownViewer</strong> project.</blockquote>

    <div class='footer'>
        <strong>Open source (GitHub):</strong> 
        github.com/omasoud/MarkdownViewer
    </div>
</body>
</html>";

        // --- COLORS FOR SOURCE VIEW (VS Code Dark Theme) ---
        private static readonly Color BgColor = Color.FromArgb(30, 30, 30);
        private static readonly Color TextColor = Color.FromArgb(212, 212, 212);
        private static readonly Color HeaderColor = Color.FromArgb(86, 156, 214); // Blue
        private static readonly Color BoldColor = Color.FromArgb(206, 145, 120); // Orange
        private static readonly Color ImageTagColor = Color.FromArgb(106, 153, 85); // Green (for image syntax)

        public static void ShowHelpDialog()
        {
            using var form = new Form();
            form.Text = "MarkView - Welcome";
            form.Size = new Size(900, 600);
            form.StartPosition = FormStartPosition.CenterScreen;
            form.FormBorderStyle = FormBorderStyle.FixedSingle;
            form.MaximizeBox = false;
            form.KeyPreview = true; // Allow form to receive key events before controls

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
            form.Controls.Add(bottomPanel);

            // // 3. SPLIT CONTAINER (The Content)
            // var split = new SplitContainer();
            // split.Dock = DockStyle.Fill; // Fills whatever space is left ABOVE the bottom panel
            // split.SplitterDistance = (int)(form.Width * 0.90); // 60% Left
            // split.IsSplitterFixed = true;
            // split.BackColor = SystemColors.ControlLight;
            // form.Controls.Add(split);

            // --- LAYOUT: SPLIT CONTAINER ---
            var split = new SplitContainer();
            split.Dock = DockStyle.Fill;
            split.SplitterDistance = (int)(85); // 90% Left
            split.Orientation = Orientation.Vertical;
            split.SplitterWidth = 1; // Thin elegant line
            split.BackColor = Color.LightGray; // Color of the divider line
            form.Controls.Add(split);

            // Ensure visual stacking order
            bottomPanel.SendToBack();
            split.BringToFront();

            // 4. LEFT PANE: RENDERED VIEW
            var browser = new WebBrowser();
            browser.Dock = DockStyle.Fill;
            browser.IsWebBrowserContextMenuEnabled = false;
            browser.AllowNavigation = false;
            // Inject the Base64 icon into the HTML template
            browser.DocumentText = string.Format(HtmlTemplate, iconBase64);

            browser.Navigating += (s, e) =>
            {
                if (e.Url.ToString() != "about:blank")
                {
                    e.Cancel = true;
                    try { Process.Start(new ProcessStartInfo(e.Url.ToString()) { UseShellExecute = true }); } catch { }
                }
            };
            // Do not show a scroll bar
            browser.ScrollBarsEnabled = false;
            split.Panel1.Controls.Add(browser);

            // 5. RIGHT PANE: SOURCE VIEW
            var rtb = new RichTextBox();
            rtb.Dock = DockStyle.Fill;
            rtb.BackColor = BgColor;
            rtb.ForeColor = TextColor;
            rtb.Font = new Font("Consolas", 10, FontStyle.Regular);
            rtb.BorderStyle = BorderStyle.None;
            rtb.ReadOnly = true;
            //rtb.ScrollBars = RichTextBoxScrollBars.Vertical; // Allow scrolling
            // Do not display a scroll bar
            rtb.ScrollBars = RichTextBoxScrollBars.None;
            rtb.WordWrap = true; // No cropping
            rtb.Text = MarkdownContent;

            // Syntax Highlighting
            ColorizeSource(rtb);

            split.Panel2.Controls.Add(rtb);

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
    }
}