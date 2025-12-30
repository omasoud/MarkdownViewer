<#
.SYNOPSIS
    Converts two highlight.js theme files (light + dark) into a single combined theme
    scoped to [data-theme="light"] and [data-theme="dark"] selectors.

.DESCRIPTION
    This script parses two highlight.js CSS theme files and outputs a combined CSS file
    that works with a data-theme attribute on the root element. Background colors are
    reset to transparent so they inherit from the parent theme system.

.PARAMETER LightTheme
    Path to the light theme CSS file.

.PARAMETER DarkTheme
    Path to the dark theme CSS file.

.PARAMETER OutputPath
    Path for the output combined CSS file.

.PARAMETER LightThemeName
    Optional name for the light theme (used in comments).

.PARAMETER DarkThemeName
    Optional name for the dark theme (used in comments).

.EXAMPLE
    .\Convert-HljsTheme.ps1 -LightTheme tomorrow.css -DarkTheme tomorrow-night.css -OutputPath highlight-theme.css
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LightTheme,

    [Parameter(Mandatory)]
    [string]$DarkTheme,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [string]$LightThemeName = '',
    [string]$DarkThemeName = ''
)

$ErrorActionPreference = 'Stop'

function Parse-HljsTheme {
    param([string]$CssContent)

    $rules = @{}
    
    # Remove comments but capture theme name from header if present
    $themeName = ''
    if ($CssContent -match 'Theme:\s*([^\r\n]+)') {
        $themeName = $Matches[1].Trim()
    }
    
    # Remove all comments
    $cleaned = $CssContent -replace '/\*[\s\S]*?\*/', ''
    
    # Match CSS rules: selector(s) { properties }
    $rulePattern = '(?<selectors>[^{}]+)\{(?<props>[^{}]+)\}'
    
    $matches = [regex]::Matches($cleaned, $rulePattern)
    
    foreach ($match in $matches) {
        $selectorBlock = $match.Groups['selectors'].Value.Trim()
        $propsBlock = $match.Groups['props'].Value.Trim()
        
        # Parse properties
        $props = @{}
        $propMatches = [regex]::Matches($propsBlock, '([a-z-]+)\s*:\s*([^;]+)')
        foreach ($pm in $propMatches) {
            $propName = $pm.Groups[1].Value.Trim()
            $propValue = $pm.Groups[2].Value.Trim()
            $props[$propName] = $propValue
        }
        
        if ($props.Count -eq 0) { continue }
        
        # Split selectors by comma
        $selectors = $selectorBlock -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        
        foreach ($sel in $selectors) {
            # Only process .hljs selectors
            if ($sel -match '\.hljs') {
                if (-not $rules.ContainsKey($sel)) {
                    $rules[$sel] = @{}
                }
                foreach ($p in $props.Keys) {
                    $rules[$sel][$p] = $props[$p]
                }
            }
        }
    }
    
    return @{
        Name = $themeName
        Rules = $rules
    }
}

function Format-ScopedRules {
    param(
        [string]$Scope,
        [hashtable]$Rules,
        [switch]$ResetBackground
    )
    
    $output = @()
    
    # Separate base .hljs rules from token rules
    $baseRules = @{}
    $tokenRules = @{}
    
    foreach ($sel in $Rules.Keys) {
        if ($sel -eq '.hljs' -or $sel -eq 'pre code.hljs' -or $sel -eq 'code.hljs') {
            $baseRules[$sel] = $Rules[$sel]
        }
        elseif ($sel -match '\.hljs::selection' -or $sel -match '\.hljs ::selection') {
            # Skip selection rules - let browser handle
        }
        else {
            $tokenRules[$sel] = $Rules[$sel]
        }
    }
    
    # Group token rules by their properties to combine selectors
    $propGroups = @{}
    foreach ($sel in $tokenRules.Keys) {
        $propsKey = ($tokenRules[$sel].GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key):$($_.Value)" }) -join ';'
        if (-not $propGroups.ContainsKey($propsKey)) {
            $propGroups[$propsKey] = @{
                Selectors = @()
                Props = $tokenRules[$sel]
            }
        }
        $propGroups[$propsKey].Selectors += $sel
    }
    
    # Output grouped rules
    foreach ($group in $propGroups.Values) {
        # Scope each selector
        $scopedSelectors = $group.Selectors | ForEach-Object {
            # Handle compound selectors like ".hljs-class .hljs-title"
            $sel = $_
            if ($sel -match '^\.hljs') {
                "$Scope $sel"
            }
            elseif ($sel -match '^(\S+)\s+\.hljs') {
                # e.g., ".ruby .hljs-property" -> "[scope] .ruby .hljs-property"
                "$Scope $sel"
            }
            else {
                "$Scope $sel"
            }
        }
        
        $selectorStr = $scopedSelectors -join ",`n"
        
        # Filter out background from token rules (keep only color, font-weight, font-style, opacity)
        $allowedProps = @('color', 'font-weight', 'font-style', 'opacity', 'text-decoration')
        $filteredProps = @{}
        foreach ($p in $group.Props.Keys) {
            if ($p -in $allowedProps) {
                $filteredProps[$p] = $group.Props[$p]
            }
        }
        
        if ($filteredProps.Count -gt 0) {
            $propsStr = ($filteredProps.GetEnumerator() | ForEach-Object { "    $($_.Key): $($_.Value);" }) -join "`n"
            $output += "$selectorStr {`n$propsStr`n}"
        }
    }
    
    return $output -join "`n`n"
}

# Read and parse themes
$lightContent = Get-Content -Raw -LiteralPath $LightTheme
$darkContent = Get-Content -Raw -LiteralPath $DarkTheme

$lightParsed = Parse-HljsTheme -CssContent $lightContent
$darkParsed = Parse-HljsTheme -CssContent $darkContent

if (-not $LightThemeName -and $lightParsed.Name) {
    $LightThemeName = $lightParsed.Name
}
if (-not $DarkThemeName -and $darkParsed.Name) {
    $DarkThemeName = $darkParsed.Name
}

# Build output
$header = @"
/*
 * Combined highlight.js theme for Markdown Viewer
 * Light theme: $LightThemeName
 * Dark theme: $DarkThemeName
 * 
 * Auto-generated by Convert-HljsTheme.ps1
 * Background colors reset to inherit from viewer theme.
 */

/* Reset highlight.js background - inherit from viewer theme */
pre code.hljs,
code.hljs,
.hljs {
    background: transparent;
    color: inherit;
}

"@

$lightSection = @"
/* ===== LIGHT MODE ($LightThemeName) ===== */

"@

$darkSection = @"

/* ===== DARK MODE ($DarkThemeName) ===== */

"@

$lightRules = Format-ScopedRules -Scope ':root[data-theme="light"]' -Rules $lightParsed.Rules
$darkRules = Format-ScopedRules -Scope ':root[data-theme="dark"]' -Rules $darkParsed.Rules

$finalCss = $header + $lightSection + $lightRules + $darkSection + $darkRules

# Write output
[IO.File]::WriteAllText($OutputPath, $finalCss, [Text.UTF8Encoding]::new($false))

Write-Host "Created: $OutputPath"
Write-Host "  Light theme: $LightThemeName"
Write-Host "  Dark theme: $DarkThemeName"
