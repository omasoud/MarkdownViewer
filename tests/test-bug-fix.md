# Test Markdown File

This file tests the bug fix for content in code blocks.

### Create a user timer

`~/.config/systemd/user/chezmoi-autocommit.timer`

```ini
[Unit]
Description=Run chezmoi auto-commit periodically

[Timer]
OnBootSec=5m
OnUnitActiveSec=30m
Persistent=true

[Install]
WantedBy=default.target
```

## Other code examples

```python
# This should also be preserved
onclick_handler = lambda: print("clicked")
onerror_callback = None
```

## Security test - these should be REMOVED (when inside HTML tags)

The following should be removed from actual HTML tags but preserved in code:

- In code: `onclick="alert(1)"` (should appear)
- Event handlers in actual tags are removed by the sanitizer
