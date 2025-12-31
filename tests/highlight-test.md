# Syntax Highlighting Test Document

This document contains various fenced code blocks to test the highlight.js integration.

## PowerShell Examples

### Standard PowerShell

```powershell
# This is a PowerShell script
function Get-Data {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [int]$Count = 10
    )
    
    $results = Get-ChildItem -Path "C:\Users\$Name" -Recurse | 
        Where-Object { $_.Length -gt 1MB } |
        Select-Object -First $Count
    
    return $results
}

$data = Get-Data -Name "Admin" -Count 5
$data | ForEach-Object { Write-Host $_.FullName -ForegroundColor Green }
```

### PS1 Alias

```ps1
# Using ps1 alias
$ErrorActionPreference = 'Stop'
try {
    Import-Module MyModule -Force
} catch {
    Write-Error "Failed: $_"
}
```

### PWSH Alias

```pwsh
# Using pwsh alias
[CmdletBinding()]
param([switch]$Force)

if ($Force) {
    Remove-Item .\temp -Recurse -Force
}
```

## JavaScript/TypeScript

### JavaScript

```javascript
// ES6 JavaScript
const fetchData = async (url) => {
    const response = await fetch(url, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' }
    });
    
    if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
    }
    
    return response.json();
};

document.addEventListener('DOMContentLoaded', () => {
    console.log('Page loaded!');
});
```

### JS Alias

```js
// Using js alias
const sum = (a, b) => a + b;
console.log(sum(1, 2));
```

### TypeScript

```typescript
interface User {
    id: number;
    name: string;
    email?: string;
}

function greetUser(user: User): string {
    return `Hello, ${user.name}!`;
}

const users: User[] = [
    { id: 1, name: 'Alice' },
    { id: 2, name: 'Bob', email: 'bob@example.com' }
];
```

### TSX/JSX

```tsx
import React, { useState } from 'react';

interface Props {
    title: string;
}

const Counter: React.FC<Props> = ({ title }) => {
    const [count, setCount] = useState(0);
    
    return (
        <div className="counter">
            <h1>{title}</h1>
            <p>Count: {count}</p>
            <button onClick={() => setCount(c => c + 1)}>Increment</button>
        </div>
    );
};
```

## Web Technologies

### HTML

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Page</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <header>
        <nav>
            <a href="#home">Home</a>
            <a href="#about">About</a>
        </nav>
    </header>
    <main id="content">
        <h1>Welcome</h1>
    </main>
    <script src="main.js"></script>
</body>
</html>
```

### CSS

```css
:root {
    --primary-color: #3498db;
    --secondary-color: #2ecc71;
}

body {
    font-family: 'Segoe UI', sans-serif;
    margin: 0;
    padding: 0;
    background: var(--primary-color);
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

@media (max-width: 768px) {
    .container {
        padding: 10px;
    }
}
```

### JSON

```json
{
    "name": "markdown-viewer",
    "version": "1.0.0",
    "description": "A tool for viewing markdown files",
    "scripts": {
        "build": "npm run compile",
        "test": "jest"
    },
    "dependencies": {
        "highlight.js": "^11.9.0"
    },
    "devDependencies": {
        "typescript": "^5.0.0"
    }
}
```

### YAML

```yaml
name: Build and Test
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test
```

### YML Alias

```yml
# Using yml alias
server:
  host: localhost
  port: 8080
  ssl: true
```

### XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <appSettings>
        <add key="ApiEndpoint" value="https://api.example.com" />
        <add key="Timeout" value="30" />
    </appSettings>
    <connectionStrings>
        <add name="DefaultConnection" 
             connectionString="Server=localhost;Database=MyDb;Trusted_Connection=True;" />
    </connectionStrings>
</configuration>
```

## Other Languages

### Python

```python
from typing import List, Optional
import asyncio

class DataProcessor:
    def __init__(self, name: str):
        self.name = name
        self._cache: dict = {}
    
    async def process(self, items: List[str]) -> Optional[str]:
        """Process a list of items asynchronously."""
        results = []
        for item in items:
            if item in self._cache:
                results.append(self._cache[item])
            else:
                processed = await self._fetch(item)
                self._cache[item] = processed
                results.append(processed)
        return '\n'.join(results) if results else None
    
    async def _fetch(self, item: str) -> str:
        await asyncio.sleep(0.1)
        return f"Processed: {item}"

# Main execution
if __name__ == "__main__":
    processor = DataProcessor("example")
    result = asyncio.run(processor.process(["a", "b", "c"]))
    print(result)
```

### Bash

```bash
#!/bin/bash
set -euo pipefail

# Configuration
readonly LOG_FILE="/var/log/script.log"
readonly BACKUP_DIR="/backup"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

backup_files() {
    local source_dir="$1"
    local dest_dir="$BACKUP_DIR/$(date '+%Y%m%d')"
    
    mkdir -p "$dest_dir"
    
    find "$source_dir" -type f -name "*.conf" | while read -r file; do
        cp "$file" "$dest_dir/"
        log "Backed up: $file"
    done
}

# Main
backup_files "/etc"
log "Backup complete!"
```

### Shell Alias

```sh
# Using sh alias
echo "Hello, World!"
for i in 1 2 3; do
    echo "Number: $i"
done
```

### SQL

```sql
-- Create tables
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Query with join
SELECT u.username, COUNT(p.id) as post_count
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
GROUP BY u.id, u.username
HAVING post_count > 5
ORDER BY post_count DESC
LIMIT 10;
```

### C#

```csharp
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace MyApp
{
    public class UserService
    {
        private readonly IRepository<User> _repository;
        
        public UserService(IRepository<User> repository)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        }
        
        public async Task<User?> GetUserAsync(int id)
        {
            var user = await _repository.GetByIdAsync(id);
            return user?.IsActive == true ? user : null;
        }
        
        public async Task<IEnumerable<User>> SearchUsersAsync(string query)
        {
            return await _repository.FindAsync(u => 
                u.Name.Contains(query, StringComparison.OrdinalIgnoreCase));
        }
    }
}
```

### Go

```go
package main

import (
    "context"
    "fmt"
    "log"
    "net/http"
    "time"
)

type Server struct {
    addr   string
    router *http.ServeMux
}

func NewServer(addr string) *Server {
    return &Server{
        addr:   addr,
        router: http.NewServeMux(),
    }
}

func (s *Server) Start(ctx context.Context) error {
    s.router.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        fmt.Fprintf(w, "OK")
    })
    
    server := &http.Server{
        Addr:         s.addr,
        Handler:      s.router,
        ReadTimeout:  5 * time.Second,
        WriteTimeout: 10 * time.Second,
    }
    
    log.Printf("Starting server on %s", s.addr)
    return server.ListenAndServe()
}

func main() {
    srv := NewServer(":8080")
    if err := srv.Start(context.Background()); err != nil {
        log.Fatal(err)
    }
}
```

### Rust

```rust
use std::collections::HashMap;
use std::error::Error;

#[derive(Debug, Clone)]
struct Config {
    name: String,
    settings: HashMap<String, String>,
}

impl Config {
    fn new(name: &str) -> Self {
        Config {
            name: name.to_string(),
            settings: HashMap::new(),
        }
    }
    
    fn get(&self, key: &str) -> Option<&String> {
        self.settings.get(key)
    }
    
    fn set(&mut self, key: &str, value: &str) -> &mut Self {
        self.settings.insert(key.to_string(), value.to_string());
        self
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    let mut config = Config::new("my-app");
    config
        .set("debug", "true")
        .set("port", "8080");
    
    println!("Config: {:?}", config);
    Ok(())
}
```

### Dockerfile

```dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 appuser

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules

USER appuser

EXPOSE 3000

CMD ["node", "dist/index.js"]
```

### Diff

```diff
--- a/config.json
+++ b/config.json
@@ -1,5 +1,6 @@
 {
   "name": "my-app",
-  "version": "1.0.0",
+  "version": "1.1.0",
+  "description": "Updated application",
   "main": "index.js"
 }
```

## Edge Cases

### Code Block Without Language Tag

```
This code block has no language tag.
It should NOT be highlighted (no auto-detection).
function test() { return 42; }
```

### Plaintext Variations

```text
This is explicitly marked as plaintext.
No highlighting should occur.
```

```txt
This uses the txt alias.
Also should not be highlighted.
```

```plain
Plain text block.
```

### Unknown Language

```unknownlang
This has an unknown language tag.
highlight.js may not recognize it.
It should still be displayed but may not highlight.
```

### Empty Code Block

```javascript
```

### Very Short Code

```python
x = 1
```

### Inline Code (Should NOT be block-highlighted)

This is some inline code: `const x = 42;` and this `function test()` should not have syntax highlighting applied via highlight.js block processing.

## Performance Test Section

Below are multiple code blocks to test performance with many blocks:

```js
// Block 1
console.log(1);
```

```js
// Block 2
console.log(2);
```

```js
// Block 3
console.log(3);
```

```js
// Block 4
console.log(4);
```

```js
// Block 5
console.log(5);
```

```js
// Block 6
console.log(6);
```

```js
// Block 7
console.log(7);
```

```js
// Block 8
console.log(8);
```

```js
// Block 9
console.log(9);
```

```js
// Block 10
console.log(10);
```

---

## Test Checklist

When viewing this document in Markdown Viewer, verify:

- [ ] PowerShell blocks (powershell, ps1, pwsh) highlight with correct colors
- [ ] JavaScript/TypeScript blocks highlight correctly
- [ ] HTML, CSS, JSON, YAML blocks highlight correctly
- [ ] Python, Bash, SQL blocks highlight correctly
- [ ] C#, Go, Rust blocks highlight correctly
- [ ] Dockerfile and Diff blocks highlight correctly
- [ ] Code blocks without language tag are NOT highlighted
- [ ] Plaintext blocks (text, txt, plain) are NOT highlighted
- [ ] Inline code spans are NOT affected by block highlighting
- [ ] Theme toggle changes code colors appropriately (light/dark)
- [ ] Theme variations maintain readable code colors
- [ ] Console shows no errors
- [ ] Console shows debug message about highlighted blocks count
