# Project Aurora

A modern CLI tool for cloud deployment automation.

![Aurora Banner](https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=800&h=200&fit=crop)

## Quick Start

Install Aurora globally via npm:

```bash
npm install -g aurora-cli
aurora init my-project
cd my-project
aurora deploy --env production
```

## Configuration

Create an `aurora.config.ts` file in your project root:

```typescript
import { defineConfig } from 'aurora-cli';

export default defineConfig({
  name: 'my-app',
  region: 'us-west-2',
  scaling: {
    minInstances: 2,
    maxInstances: 10,
    targetCPU: 70
  },
  env: {
    DATABASE_URL: process.env.DATABASE_URL,
    API_KEY: process.env.API_KEY
  }
});
```

## Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| AWS | ✅ Stable | Full support including Lambda |
| Azure | ✅ Stable | App Service & Functions |
| GCP | 🔶 Beta | Cloud Run only |

## Features

- **Zero-config deployments** — sensible defaults for most projects
- **Instant rollbacks** — one command to revert any deployment
- **Built-in monitoring** — real-time logs and metrics dashboard
- **Secret management** — encrypted environment variables

> **Note:** Aurora requires Node.js 18+ and a valid cloud provider account.

## Example: Python Worker

```python
from aurora import Worker, task

class DataProcessor(Worker):
    @task(retry=3, timeout=300)
    async def process_batch(self, items: list[dict]) -> dict:
        results = []
        for item in items:
            result = await self.transform(item)
            results.append(result)
        return {"processed": len(results), "status": "complete"}
```

## Links

- [Documentation](docs/getting-started.md)
- [API Reference](docs/api.md)
- [Changelog](CHANGELOG.md)

---

MIT License © 2025 Aurora Contributors
