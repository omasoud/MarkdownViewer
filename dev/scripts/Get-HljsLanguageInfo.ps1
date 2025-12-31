param (
    [string]$File
)

# 1. Handle missing parameter (Default to Temp Download)
if ([string]::IsNullOrWhiteSpace($File)) {
    $v = "11.11.1"
    $File = Join-Path $env:TEMP "highlight.$v.min.js"
    
    if (-not (Test-Path $File)) {
        Write-Host "Downloading highlight.js v$v..." -ForegroundColor Cyan
        Invoke-WebRequest "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@$v/highlight.min.js" -OutFile $File
    }
}

# 2. Normalize path to absolute (looks better in output)
$File = (Resolve-Path $File).Path

# 3. Output the Source file path
Write-Host "Source: $File" -ForegroundColor Green

# 4. Run Node.js extraction
# We pass $File as an argument so process.argv[1] can read it
node -e "const fs=require('fs'),vm=require('vm');
try {
    const c=fs.readFileSync(process.argv[1],'utf8');
    const x={};
    vm.createContext(x);
    vm.runInContext(c,x);
    
    // Handle different export styles (browser global vs commonjs)
    const h=x.hljs||x.module?.exports||x.exports;
    
    if(!h || !h.listLanguages){ throw new Error('Could not find hljs instance'); }
    
    const l=h.listLanguages().sort();
    console.log(l.length);
    console.log(l.join('\n'));
} catch(e) {
    console.error('Error parsing file:', e.message);
    process.exit(1);
}" "$File"