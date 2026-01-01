# MarkdownViewer.Tests.ps1 - Pester tests for MarkdownViewer module

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

BeforeAll {
    Import-Module Pester -RequiredVersion 5.7.1 -Force
    $modulePath = Join-Path $PSScriptRoot '..\payload\MarkdownViewer.psm1'
    Import-Module $modulePath -Force -Global
}

AfterAll {
    Remove-Module MarkdownViewer -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-HtmlSanitization' {
    
    Context 'Bug fix: Content in code blocks should be preserved' {
        It 'preserves OnBootSec=5m and OnUnitActiveSec=30m in code blocks' {
            $html = @'
<pre><code class="language-ini">[Unit]
Description=Run chezmoi auto-commit periodically

[Timer]
OnBootSec=5m
OnUnitActiveSec=30m
Persistent=true

[Install]
WantedBy=default.target
</code></pre>
'@
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Match 'OnBootSec=5m'
            $result | Should -Match 'OnUnitActiveSec=30m'
            $result | Should -Match 'Persistent=true'
        }

        It 'preserves content starting with "on" in inline code' {
            $html = '<p>Use <code>onclick=handler</code> in your config.</p>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Match 'onclick=handler'
        }

        It 'preserves text content with on* patterns outside tags' {
            $html = '<p>Set onError=retry in your settings.</p>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Match 'onError=retry'
        }
    }

    Context 'Dangerous tag removal' {
        It 'removes <script> tags with content' {
            $html = '<p>Hello</p><script>alert("xss")</script><p>World</p>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<script'
            $result | Should -Not -Match 'alert'
            $result | Should -Match '<p>Hello</p>'
            $result | Should -Match '<p>World</p>'
        }

        It 'removes <script> tags with attributes' {
            $html = '<script type="text/javascript" src="evil.js"></script>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<script'
            $result | Should -Not -Match 'evil.js'
        }

        It 'removes self-closing script tags' {
            $html = '<p>Test</p><script src="evil.js" /><p>More</p>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<script'
        }

        It 'removes <iframe> tags' {
            $html = '<iframe src="https://evil.com"></iframe>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<iframe'
            $result | Should -Not -Match 'evil.com'
        }

        It 'removes <object> tags' {
            $html = '<object data="malware.swf" type="application/x-shockwave-flash"></object>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<object'
        }

        It 'removes <embed> tags' {
            $html = '<embed src="malware.swf" type="application/x-shockwave-flash">'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<embed'
        }

        It 'removes <meta> tags' {
            $html = '<meta http-equiv="refresh" content="0;url=evil.com">'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<meta'
        }

        It 'removes <base> tags' {
            $html = '<base href="https://evil.com/">'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<base'
        }

        It 'removes <link> tags' {
            $html = '<link rel="stylesheet" href="evil.css">'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<link'
        }

        It 'removes <style> tags' {
            $html = '<style>body { background: url(evil.png); }</style>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<style'
        }

        It 'removes dangerous tags case-insensitively' {
            $html = '<SCRIPT>alert(1)</SCRIPT><ScRiPt>alert(2)</ScRiPt>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '(?i)<script'
            $result | Should -Not -Match 'alert'
        }

        It 'handles nested dangerous tags' {
            $html = '<script><script>nested</script></script>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<script'
        }

        It 'removes dangerous tags with whitespace' {
            $html = '<  script  >alert(1)</  script  >'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '<\s*script'
        }
    }

    Context 'Event handler removal' {
        It 'removes onclick attribute' {
            $html = '<a href="#" onclick="alert(1)">Click</a>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onclick'
            $result | Should -Match '<a href="#">Click</a>'
        }

        It 'removes onerror attribute' {
            $html = '<img src="x" onerror="alert(1)">'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onerror'
            $result | Should -Match '<img src="x">'
        }

        It 'removes onload attribute' {
            $html = '<body onload="evil()">'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onload'
        }

        It 'removes onmouseover attribute' {
            $html = '<div onmouseover="alert(1)">Hover</div>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onmouseover'
        }

        It 'removes event handlers with single quotes' {
            $html = "<a href='#' onclick='alert(1)'>Click</a>"
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onclick'
        }

        It 'removes event handlers without quotes' {
            $html = '<a href=# onclick=alert(1)>Click</a>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onclick'
        }

        It 'removes multiple event handlers from one element' {
            $html = '<div onclick="a()" onmouseover="b()" onmouseout="c()">Text</div>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onclick'
            $result | Should -Not -Match 'onmouseover'
            $result | Should -Not -Match 'onmouseout'
            $result | Should -Match '<div>Text</div>'
        }

        It 'removes event handlers case-insensitively' {
            $html = '<a ONCLICK="alert(1)" OnClick="alert(2)">Click</a>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '(?i)onclick'
        }

        It 'preserves other attributes when removing event handlers' {
            $html = '<a href="page.html" class="link" onclick="evil()" id="mylink">Click</a>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onclick'
            $result | Should -Match 'href="page.html"'
            $result | Should -Match 'class="link"'
            $result | Should -Match 'id="mylink"'
        }

        It 'removes event handlers from custom elements (hyphenated tags)' {
            $html = '<my-component onclick="evil()" data-value="test">Content</my-component>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onclick'
            $result | Should -Match 'data-value="test"'
            $result | Should -Match '<my-component'
        }

        It 'removes event handlers from self-closing tags' {
            $html = '<img src="photo.jpg" onerror="evil()" />'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onerror'
            $result | Should -Match 'src="photo.jpg"'
            $result | Should -Match '/>'
        }

        It 'removes event handlers from SVG namespaced elements' {
            $html = '<svg:rect onclick="evil()" width="100" />'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onclick'
            $result | Should -Match 'width="100"'
        }

        It 'removes event handlers from tags with underscores' {
            $html = '<custom_element onmouseover="evil()">Text</custom_element>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'onmouseover'
        }
    }

    Context 'JavaScript URI neutralization' {
        It 'neutralizes javascript: in href' {
            $html = '<a href="javascript:alert(1)">Click</a>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'javascript:'
            $result | Should -Match 'href="#"'
        }

        It 'neutralizes javascript: in src' {
            $html = '<img src="javascript:alert(1)">'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'javascript:'
            $result | Should -Match 'src="#"'
        }

        It 'neutralizes javascript: with leading whitespace' {
            $html = '<a href="  javascript:alert(1)">Click</a>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'javascript:'
        }

        It 'neutralizes javascript: case-insensitively' {
            $html = '<a href="JAVASCRIPT:alert(1)">Click</a>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match '(?i)javascript:'
        }

        It 'neutralizes javascript: in xlink:href' {
            $html = '<a xlink:href="javascript:alert(1)">Click</a>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'javascript:'
        }

        It 'neutralizes javascript: in srcset' {
            $html = '<img srcset="javascript:alert(1)">'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Not -Match 'javascript:'
        }
    }

    Context 'Data URI handling' {
        It 'blocks data: URIs in href' {
            $html = '<a href="data:text/html,<script>alert(1)</script>">Click</a>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Match 'href="#"'
            $result | Should -Not -Match 'data:text/html'
        }

        It 'allows data: URIs in img src (for images)' {
            $html = '<img src="data:image/png;base64,iVBORw0KGgo=">'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Match 'data:image/png'
        }

        It 'blocks data: URIs in xlink:href' {
            $html = '<a xlink:href="data:text/html,evil">Click</a>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Match 'xlink:href="#"'
        }
    }

    Context 'Edge cases' {
        It 'handles empty string' {
            $result = Invoke-HtmlSanitization -Html ''
            $result | Should -Be ''
        }

        It 'handles plain text without HTML' {
            $html = 'Just some plain text with onclick=something in it.'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Be $html
        }

        It 'preserves valid HTML structure' {
            $html = '<h1>Title</h1><p>Paragraph with <strong>bold</strong> and <em>italic</em>.</p>'
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Be $html
        }

        It 'handles multiline content' {
            $html = @"
<div>
    <p>Line 1</p>
    <p>Line 2</p>
</div>
"@
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Match 'Line 1'
            $result | Should -Match 'Line 2'
        }

        It 'handles complex code block with various on* patterns' {
            $html = @'
<pre><code>
# systemd timer configuration
OnBootSec=5m
OnUnitActiveSec=30m
OnCalendar=*-*-* 06:00:00
OnStartupSec=10s
onclick_handler = function() {}
onerror_callback = None
</code></pre>
'@
            $result = Invoke-HtmlSanitization -Html $html
            
            $result | Should -Match 'OnBootSec=5m'
            $result | Should -Match 'OnUnitActiveSec=30m'
            $result | Should -Match 'OnCalendar=\*-\*-\* 06:00:00'
            $result | Should -Match 'OnStartupSec=10s'
            $result | Should -Match 'onclick_handler = function'
            $result | Should -Match 'onerror_callback = None'
        }
    }
}

Describe 'Test-RemoteImages' {
    
    Context 'Detects remote images' {
        It 'detects https:// in img src' {
            $html = '<img src="https://example.com/image.png">'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeTrue
        }

        It 'detects http:// in img src' {
            $html = '<img src="http://example.com/image.png">'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeTrue
        }

        It 'detects protocol-relative // in img src' {
            $html = '<img src="//example.com/image.png">'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeTrue
        }

        It 'detects remote images in srcset' {
            $html = '<img srcset="https://example.com/img-2x.png 2x">'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeTrue
        }

        It 'detects remote images in srcset with multiple sources (remote not first)' {
            $html = '<img srcset="local.png 1x, https://example.com/img-2x.png 2x">'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeTrue
        }

        It 'detects protocol-relative URL in srcset with multiple sources' {
            $html = '<img srcset="local.png 1x, //cdn.example.com/img-2x.png 2x">'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeTrue
        }

        It 'detects http in srcset with multiple sources' {
            $html = '<img srcset="small.jpg 480w, http://remote.com/large.jpg 1024w">'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeTrue
        }
    }

    Context 'Does not detect local images' {
        It 'returns false for data: URI images' {
            $html = '<img src="data:image/png;base64,abc123">'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeFalse
        }

        It 'returns false for relative path images' {
            $html = '<img src="images/photo.png">'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeFalse
        }

        It 'returns false for file:// URI images' {
            $html = '<img src="file:///C:/images/photo.png">'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeFalse
        }

        It 'returns false for HTML without images' {
            $html = '<p>No images here</p>'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeFalse
        }

        It 'returns false for empty string' {
            $result = Test-RemoteImages -Html ''
            
            $result | Should -BeFalse
        }
    }

    Context 'Edge cases' {
        It 'handles https in non-img context' {
            $html = '<a href="https://example.com">Link</a>'
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeFalse
        }

        It 'detects remote images with single quotes' {
            $html = "<img src='https://example.com/image.png'>"
            $result = Test-RemoteImages -Html $html
            
            $result | Should -BeTrue
        }
    }
}

Describe 'Get-FileBaseHref' {
    
    Context 'Standard Windows paths' {
        It 'converts C:\path\file.md correctly' {
            $result = Get-FileBaseHref -FilePath 'C:\Users\test\file.md'
            
            $result | Should -Be 'file:///C:/Users/test/'
        }

        It 'converts D:\folder\subfolder\file.md correctly' {
            $result = Get-FileBaseHref -FilePath 'D:\folder\subfolder\file.md'
            
            $result | Should -Be 'file:///D:/folder/subfolder/'
        }
    }

    Context 'UNC paths' {
        It 'converts \\server\share\file.md correctly' {
            $result = Get-FileBaseHref -FilePath '\\server\share\file.md'
            
            $result | Should -Be 'file://server/share/'
        }

        It 'converts \\server\share\folder\file.md correctly' {
            $result = Get-FileBaseHref -FilePath '\\server\share\folder\file.md'
            
            $result | Should -Be 'file://server/share/folder/'
        }
    }

    Context 'Long path prefix' {
        It 'converts \\?\C:\path\file.md correctly' {
            $result = Get-FileBaseHref -FilePath '\\?\C:\Users\test\file.md'
            
            $result | Should -Be 'file:///C:/Users/test/'
        }

        It 'converts \\?\UNC\server\share\file.md correctly' {
            $result = Get-FileBaseHref -FilePath '\\?\UNC\server\share\file.md'
            
            $result | Should -Be 'file://server/share/'
        }
    }
}

Describe 'Test-Motw' {
    
    BeforeAll {
        $testDir = Join-Path ([IO.Path]::GetTempPath()) 'MarkdownViewer_Tests'
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    }

    AfterAll {
        $testDir = Join-Path ([IO.Path]::GetTempPath()) 'MarkdownViewer_Tests'
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Files without MOTW' {
        It 'returns null for file without Zone.Identifier' {
            $testFile = Join-Path $testDir 'no_motw.txt'
            Set-Content -Path $testFile -Value 'test content'
            
            $result = Test-Motw -FilePath $testFile
            
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Files with MOTW' {
        It 'returns zone ID for file with Zone.Identifier' {
            $testFile = Join-Path $testDir 'with_motw.txt'
            Set-Content -Path $testFile -Value 'test content'
            Set-Content -Path "$testFile`:Zone.Identifier" -Value "[ZoneTransfer]`nZoneId=3"
            
            $result = Test-Motw -FilePath $testFile
            
            $result | Should -Be 3
        }

        It 'returns correct zone for Internet zone (3)' {
            $testFile = Join-Path $testDir 'internet_zone.txt'
            Set-Content -Path $testFile -Value 'test content'
            Set-Content -Path "$testFile`:Zone.Identifier" -Value "[ZoneTransfer]`nZoneId=3"
            
            $result = Test-Motw -FilePath $testFile
            
            $result | Should -Be 3
        }

        It 'returns correct zone for Restricted zone (4)' {
            $testFile = Join-Path $testDir 'restricted_zone.txt'
            Set-Content -Path $testFile -Value 'test content'
            Set-Content -Path "$testFile`:Zone.Identifier" -Value "[ZoneTransfer]`nZoneId=4"
            
            $result = Test-Motw -FilePath $testFile
            
            $result | Should -Be 4
        }

        It 'returns correct zone for Local zone (0)' {
            $testFile = Join-Path $testDir 'local_zone.txt'
            Set-Content -Path $testFile -Value 'test content'
            Set-Content -Path "$testFile`:Zone.Identifier" -Value "[ZoneTransfer]`nZoneId=0"
            
            $result = Test-Motw -FilePath $testFile
            
            $result | Should -Be 0
        }
    }

    Context 'Edge cases' {
        It 'returns null for non-existent file' {
            $result = Test-Motw -FilePath (Join-Path $testDir 'nonexistent.txt')
            
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Theme Variation Feature - CSS' {
    BeforeAll {
        $cssPath = Join-Path $PSScriptRoot '..\payload\style.css'
        $cssContent = Get-Content -Raw -LiteralPath $cssPath
    }

    Context 'Light theme variations exist' {
        It 'has Light Default (variation 0) styles' {
            $cssContent | Should -Match '\[data-theme="light"\]\[data-variation="0"\]'
        }

        It 'has Light Warm (variation 1) styles' {
            $cssContent | Should -Match '\[data-theme="light"\]\[data-variation="1"\]'
        }

        It 'has Light Cool (variation 2) styles' {
            $cssContent | Should -Match '\[data-theme="light"\]\[data-variation="2"\]'
        }

        It 'has Light Sepia (variation 3) styles' {
            $cssContent | Should -Match '\[data-theme="light"\]\[data-variation="3"\]'
        }

        It 'has Light High Contrast (variation 4) styles' {
            $cssContent | Should -Match '\[data-theme="light"\]\[data-variation="4"\]'
        }
    }

    Context 'Dark theme variations exist' {
        It 'has Dark Default (variation 0) styles' {
            $cssContent | Should -Match '\[data-theme="dark"\]\[data-variation="0"\]'
        }

        It 'has Dark Warm (variation 1) styles' {
            $cssContent | Should -Match '\[data-theme="dark"\]\[data-variation="1"\]'
        }

        It 'has Dark Cool (variation 2) styles' {
            $cssContent | Should -Match '\[data-theme="dark"\]\[data-variation="2"\]'
        }

        It 'has Dark OLED Black (variation 3) styles' {
            $cssContent | Should -Match '\[data-theme="dark"\]\[data-variation="3"\]'
        }

        It 'has Dark Dimmed (variation 4) styles' {
            $cssContent | Should -Match '\[data-theme="dark"\]\[data-variation="4"\]'
        }
    }

    Context 'CSS custom properties are defined' {
        It 'defines --bg property' {
            $cssContent | Should -Match '--bg:\s*#[0-9a-fA-F]+'
        }

        It 'defines --fg property' {
            $cssContent | Should -Match '--fg:\s*#[0-9a-fA-F]+'
        }

        It 'defines --codebg property' {
            $cssContent | Should -Match '--codebg:\s*#[0-9a-fA-F]+'
        }

        It 'defines --border property' {
            $cssContent | Should -Match '--border:\s*#[0-9a-fA-F]+'
        }

        It 'defines --link property' {
            $cssContent | Should -Match '--link:\s*#[0-9a-fA-F]+'
        }
    }

    Context 'Dropdown menu styles exist' {
        It 'has .mv-var-menu styles' {
            $cssContent | Should -Match '\.mv-var-menu\s*\{'
        }

        It 'has .mv-var-item styles' {
            $cssContent | Should -Match '\.mv-var-item\s*\{'
        }

        It 'has .mv-var-item:hover styles' {
            $cssContent | Should -Match '\.mv-var-item:hover\s*\{'
        }

        It 'has .mv-var-item.active styles' {
            $cssContent | Should -Match '\.mv-var-item\.active\s*\{'
        }
    }

    Context 'Button styles exist' {
        It 'has #mvVariation button styles' {
            $cssContent | Should -Match '#mvVariation\s*\{'
        }

        It 'has #mvImages button styles' {
            $cssContent | Should -Match '#mvImages\s*\{'
        }
    }
}

Describe 'Theme Variation Feature - JavaScript' {
    BeforeAll {
        $jsPath = Join-Path $PSScriptRoot '..\payload\script.js'
        $jsContent = Get-Content -Raw -LiteralPath $jsPath
    }

    Context 'localStorage keys are defined' {
        It 'defines mdviewer_light_variation key' {
            $jsContent | Should -Match 'mdviewer_light_variation'
        }

        It 'defines mdviewer_dark_variation key' {
            $jsContent | Should -Match 'mdviewer_dark_variation'
        }
    }

    Context 'Theme variation names are defined' {
        It 'defines light theme names array' {
            $jsContent | Should -Match 'lightNames\s*=\s*\['
        }

        It 'defines dark theme names array' {
            $jsContent | Should -Match 'darkNames\s*=\s*\['
        }

        It 'includes Default variation name' {
            $jsContent | Should -Match '"Default"'
        }

        It 'includes Warm variation name' {
            $jsContent | Should -Match '"Warm"'
        }

        It 'includes Cool variation name' {
            $jsContent | Should -Match '"Cool"'
        }

        It 'includes Sepia variation name' {
            $jsContent | Should -Match '"Sepia"'
        }

        It 'includes High Contrast variation name' {
            $jsContent | Should -Match '"High Contrast"'
        }

        It 'includes OLED Black variation name' {
            $jsContent | Should -Match '"OLED Black"'
        }

        It 'includes Dimmed variation name' {
            $jsContent | Should -Match '"Dimmed"'
        }
    }

    Context 'Core functions exist' {
        It 'defines getVariation function' {
            $jsContent | Should -Match 'function getVariation'
        }

        It 'defines setVariation function' {
            $jsContent | Should -Match 'function setVariation'
        }

        It 'defines applyVariation function' {
            $jsContent | Should -Match 'function applyVariation'
        }

        It 'defines updateVariationButton function' {
            $jsContent | Should -Match 'function updateVariationButton'
        }

        It 'defines openMenu function' {
            $jsContent | Should -Match 'function openMenu'
        }

        It 'defines closeMenu function' {
            $jsContent | Should -Match 'function closeMenu'
        }
    }

    Context 'Event handlers exist' {
        It 'handles Escape key' {
            $jsContent | Should -Match 'Escape'
        }

        It 'handles mouseenter for preview' {
            $jsContent | Should -Match 'mouseenter'
        }

        It 'creates variation button dynamically' {
            $jsContent | Should -Match 'mvVariation'
        }
    }

    Context 'Menu item structure' {
        It 'creates menu items with mv-var-item class' {
            $jsContent | Should -Match 'mv-var-item'
        }

        It 'creates menu container with mv-var-menu class' {
            $jsContent | Should -Match 'mv-var-menu'
        }

        It 'marks active item with active class' {
            $jsContent | Should -Match '"active"'
        }
    }
}

Describe 'Syntax Highlighting Feature - Asset Files' {
    BeforeAll {
        $payloadDir = Join-Path $PSScriptRoot '..\payload'
    }

    Context 'highlight.js bundle' {
        It 'highlight.min.js exists in payload directory' {
            $path = Join-Path $payloadDir 'highlight.min.js'
            Test-Path -LiteralPath $path | Should -BeTrue
        }
    }

    Context 'highlight-theme.css' {
        BeforeAll {
            $themePath = Join-Path $PSScriptRoot '..\payload\highlight-theme.css'
            $themeContent = Get-Content -Raw -LiteralPath $themePath
        }

        It 'highlight-theme.css exists in payload directory' {
            Test-Path -LiteralPath $themePath | Should -BeTrue
        }

        It 'contains .hljs background reset to transparent' {
            $themeContent | Should -Match '\.hljs\s*\{[^}]*background:\s*transparent'
        }

        It 'contains light mode scoped rules' {
            $themeContent | Should -Match ':root\[data-theme="light"\]'
        }

        It 'contains dark mode scoped rules' {
            $themeContent | Should -Match ':root\[data-theme="dark"\]'
        }

        It 'contains .hljs-keyword token rule' {
            $themeContent | Should -Match '\.hljs-keyword'
        }

        It 'contains .hljs-string token rule' {
            $themeContent | Should -Match '\.hljs-string'
        }
    }
}

Describe 'Syntax Highlighting Feature - JavaScript Module' {
    BeforeAll {
        $jsPath = Join-Path $PSScriptRoot '..\payload\script.js'
        $jsContent = Get-Content -Raw -LiteralPath $jsPath
    }

    Context 'Configuration constants' {
        It 'defines MAX_BLOCK_SIZE constant as 102400' {
            $jsContent | Should -Match 'MAX_BLOCK_SIZE\s*=\s*102400'
        }

        It 'defines MAX_BLOCKS constant as 500' {
            $jsContent | Should -Match 'MAX_BLOCKS\s*=\s*500'
        }
    }

    Context 'LANG_MAP language aliases' {
        It 'defines LANG_MAP object' {
            $jsContent | Should -Match 'LANG_MAP\s*='
        }

        It 'maps ps1 to powershell' {
            $jsContent | Should -Match "'ps1':\s*'powershell'"
        }

        It 'maps pwsh to powershell' {
            $jsContent | Should -Match "'pwsh':\s*'powershell'"
        }

        It 'maps psm1 to powershell' {
            $jsContent | Should -Match "'psm1':\s*'powershell'"
        }

        It 'maps psd1 to powershell' {
            $jsContent | Should -Match "'psd1':\s*'powershell'"
        }

        It 'maps sh to bash' {
            $jsContent | Should -Match "'sh':\s*'bash'"
        }

        It 'maps shell to bash' {
            $jsContent | Should -Match "'shell':\s*'bash'"
        }

        It 'maps zsh to bash' {
            $jsContent | Should -Match "'zsh':\s*'bash'"
        }

        It 'maps js to javascript' {
            $jsContent | Should -Match "'js':\s*'javascript'"
        }

        It 'maps ts to typescript' {
            $jsContent | Should -Match "'ts':\s*'typescript'"
        }

        It 'maps tsx to typescript' {
            $jsContent | Should -Match "'tsx':\s*'typescript'"
        }

        It 'maps jsx to javascript' {
            $jsContent | Should -Match "'jsx':\s*'javascript'"
        }

        It 'maps yml to yaml' {
            $jsContent | Should -Match "'yml':\s*'yaml'"
        }

        It 'maps py to python' {
            $jsContent | Should -Match "'py':\s*'python'"
        }

        It 'maps cs to csharp' {
            $jsContent | Should -Match "'cs':\s*'csharp'"
        }

        It 'maps text to plaintext' {
            $jsContent | Should -Match "'text':\s*'plaintext'"
        }

        It 'maps txt to plaintext' {
            $jsContent | Should -Match "'txt':\s*'plaintext'"
        }

        It 'maps plain to plaintext' {
            $jsContent | Should -Match "'plain':\s*'plaintext'"
        }

        It 'maps none to plaintext' {
            $jsContent | Should -Match "'none':\s*'plaintext'"
        }
    }

    Context 'Guard checks' {
        It 'checks if hljs is undefined' {
            $jsContent | Should -Match "typeof hljs === 'undefined'"
        }

        It 'logs warning when hljs not loaded' {
            $jsContent | Should -Match "highlight\.js not loaded"
        }

        It 'has highlighted flag to prevent re-execution' {
            $jsContent | Should -Match 'highlighted\s*=\s*false'
        }
    }

    Context 'Helper functions' {
        It 'defines getLanguageClass function' {
            $jsContent | Should -Match 'function getLanguageClass'
        }

        It 'defines normalizeLanguage function' {
            $jsContent | Should -Match 'function normalizeLanguage'
        }

        It 'defines shouldHighlight function' {
            $jsContent | Should -Match 'function shouldHighlight'
        }

        It 'defines highlightBlock function' {
            $jsContent | Should -Match 'function highlightBlock'
        }

        It 'defines runHighlighting function' {
            $jsContent | Should -Match 'function runHighlighting'
        }
    }

    Context 'Safety constraints' {
        It 'does NOT call highlightAuto' {
            $jsContent | Should -Not -Match 'highlightAuto'
        }

        It 'uses hljs.highlightElement for individual blocks' {
            $jsContent | Should -Match 'hljs\.highlightElement'
        }

        It 'wraps highlighting in try/catch' {
            $jsContent | Should -Match 'try\s*\{[^}]*highlightElement[^}]*\}\s*catch'
        }
    }

    Context 'Selector and limits' {
        It 'selects only pre code blocks with language class' {
            $jsContent | Should -Match "pre code\[class\*=.language-.\]"
        }

        It 'limits blocks to MAX_BLOCKS' {
            $jsContent | Should -Match 'Math\.min\(blocks\.length,\s*MAX_BLOCKS\)'
        }

        It 'checks block size against MAX_BLOCK_SIZE' {
            $jsContent | Should -Match 'size\s*>\s*MAX_BLOCK_SIZE'
        }
    }
}

Describe 'Syntax Highlighting Feature - CSP' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\payload\Open-Markdown.ps1'
        $scriptContent = Get-Content -Raw -LiteralPath $scriptPath
    }

    Context 'CSP includes file: source' {
        It 'style-src includes file:' {
            $scriptContent | Should -Match "style-src 'nonce-.+' file:"
        }

        It 'script-src includes file:' {
            $scriptContent | Should -Match "script-src 'nonce-.+' file:"
        }
    }

    Context 'CSP security constraints' {
        It 'does NOT add https: to script-src' {
            # Check that script-src line doesn't include https
            $scriptContent | Should -Not -Match 'script-src[^"]*https:'
        }

        It 'does NOT add unsafe-inline to script-src' {
            $scriptContent | Should -Not -Match "script-src[^`"]*'unsafe-inline'"
        }
    }

    Context 'Security documentation' {
        It 'contains security note about file: in script-src' {
            $scriptContent | Should -Match 'SECURITY NOTE'
        }

        It 'mentions sanitization requirement' {
            $scriptContent | Should -Match 'Invoke-HtmlSanitization'
        }
    }
}

Describe 'Syntax Highlighting Feature - HTML Template' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\payload\Open-Markdown.ps1'
        $scriptContent = Get-Content -Raw -LiteralPath $scriptPath
    }

    Context 'Asset path handling' {
        It 'defines HighlightJsPath parameter' {
            $scriptContent | Should -Match '\$HighlightJsPath\s*='
        }

        It 'defines HighlightThemePath parameter' {
            $scriptContent | Should -Match '\$HighlightThemePath\s*='
        }

        It 'checks if highlight assets exist' {
            $scriptContent | Should -Match 'Test-Path.*HighlightJsPath'
        }
    }

    Context 'HTML includes highlight assets' {
        It 'includes link to highlight-theme.css' {
            $scriptContent | Should -Match 'highlightThemeLink.*<link rel='
        }

        It 'includes script tag with defer for highlight.min.js' {
            $scriptContent | Should -Match 'highlightScript.*<script src=.*defer>'
        }
    }
}

Describe 'Syntax Highlighting Feature - Installer' {
    BeforeAll {
        $installerPath = Join-Path $PSScriptRoot '..\install.ps1'
        $installerContent = Get-Content -Raw -LiteralPath $installerPath
    }

    Context 'Copy-Payload includes highlight assets' {
        It 'copies highlight.min.js' {
            $installerContent | Should -Match 'Copy-Item.*highlight\.min\.js'
        }

        It 'copies highlight-theme.css' {
            $installerContent | Should -Match 'Copy-Item.*highlight-theme\.css'
        }
    }

    Context 'Set-ReadOnlyAcl includes highlight assets' {
        It 'includes highlight.min.js in files array' {
            $installerContent | Should -Match '"highlight\.min\.js"'
        }

        It 'includes highlight-theme.css in files array' {
            $installerContent | Should -Match '"highlight-theme\.css"'
        }
    }
}

Describe 'ConvertFrom-Markdown Anchor ID Mismatch' {
    # ConvertFrom-Markdown generates mismatched anchor IDs:
    # - TOC links: href="#3-design-goals"
    # - Heading IDs: id="design-goals" (number prefix stripped)
    # Our script.js must fix this mismatch for TOC navigation to work

    Context 'ConvertFrom-Markdown produces mismatched IDs' {
        It 'produces TOC link with number prefix' {
            $md = @"
- [Design Goals](#3-design-goals)

## 3. Design Goals
"@
            $html = (ConvertFrom-Markdown -InputObject $md).Html
            $html | Should -Match 'href="#3-design-goals"'
        }

        It 'produces heading ID without number prefix' {
            $md = @"
- [Design Goals](#3-design-goals)

## 3. Design Goals
"@
            $html = (ConvertFrom-Markdown -InputObject $md).Html
            $html | Should -Match 'id="design-goals"'
            $html | Should -Not -Match 'id="3-design-goals"'
        }
    }

    Context 'script.js includes anchor fixup code' {
        BeforeAll {
            $jsPath = Join-Path $PSScriptRoot '..\payload\script.js'
            $jsContent = Get-Content -Raw -LiteralPath $jsPath
        }

        It 'defines fixMismatchedAnchors function' {
            $jsContent | Should -Match 'function fixMismatchedAnchors'
        }

        It 'queries elements with id attribute' {
            $jsContent | Should -Match 'querySelectorAll\(\s*["''].*\[id\]'
        }

        It 'handles mismatched anchor hrefs' {
            # Should look for anchor links and try to find matching IDs
            $jsContent | Should -Match 'getElementById|querySelector.*id'
        }
    }
}
