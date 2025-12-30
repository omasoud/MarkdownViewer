(function () {
    const k = "mdviewer_theme_mode";
    const kLightVar = "mdviewer_light_variation";
    const kDarkVar = "mdviewer_dark_variation";
    const r = document.documentElement;
    const b = document.getElementById("mvTheme");
    const m = window.matchMedia &&
        window.matchMedia("(prefers-color-scheme: dark)");

    const lightNames = ["Default", "Warm", "Cool", "Sepia", "High Contrast"];
    const darkNames = ["Default", "Warm", "Cool", "OLED Black", "Dimmed"];

    function sysDark() {
        return !!(m && m.matches);
    }
    function effective(mode) {
        const d = sysDark();
        const useDark = (mode === "invert") ? !d : d;
        return useDark ? "dark" : "light";
    }
    function setLabel(mode, theme) {
        const t = (theme === "dark") ? "Dark" : "Light";
        b.textContent = (mode === "invert")
            ? ("Theme: Invert (" + t + ")")
            : ("Theme: System (" + t + ")");
    }
    function getVariation(theme) {
        const key = (theme === "dark") ? kDarkVar : kLightVar;
        const v = localStorage.getItem(key);
        const n = parseInt(v, 10);
        return (n >= 0 && n <= 4) ? n : 0;
    }
    function setVariation(theme, index) {
        const key = (theme === "dark") ? kDarkVar : kLightVar;
        localStorage.setItem(key, String(index));
    }
    function applyVariation(theme) {
        const v = getVariation(theme);
        r.dataset.variation = String(v);
        updateVariationButton(theme, v);
    }
    function updateVariationButton(theme, variation) {
        const varBtn = document.getElementById("mvVariation");
        if (!varBtn) return;
        const names = (theme === "dark") ? darkNames : lightNames;
        const themeName = (theme === "dark") ? "Dark" : "Light";
        varBtn.textContent = themeName + " Theme: " + names[variation];
    }
    function apply(mode) {
        const th = effective(mode);
        r.dataset.theme = th;
        setLabel(mode, th);
        applyVariation(th);
    }

    let mode = localStorage.getItem(k) || "system";
    if (mode !== "system" && mode !== "invert") mode = "system";
    apply(mode);

    b.addEventListener("click", function () {
        mode = (mode === "system") ? "invert" : "system";
        localStorage.setItem(k, mode);
        apply(mode);
    });
    if (m) {
        const onChange = function () {
            apply(mode);
        };
        if (m.addEventListener) {
            m.addEventListener("change", onChange);
        } else m.addListener(onChange);
    }

    // Create Variation button
    const varBtn = document.createElement("button");
    varBtn.id = "mvVariation";
    varBtn.type = "button";
    document.body.appendChild(varBtn);

    const currentTheme = effective(mode);
    updateVariationButton(currentTheme, getVariation(currentTheme));

    // Dropdown menu state
    let menuOpen = false;
    let menuEl = null;
    let originalVariation = null;

    function closeMenu(revert) {
        if (!menuEl) return;
        if (revert && originalVariation !== null) {
            r.dataset.variation = String(originalVariation);
        }
        menuEl.remove();
        menuEl = null;
        menuOpen = false;
        originalVariation = null;
    }

    function openMenu() {
        if (menuOpen) {
            closeMenu(true);
            return;
        }

        const theme = r.dataset.theme || "light";
        originalVariation = getVariation(theme);
        const names = (theme === "dark") ? darkNames : lightNames;

        menuEl = document.createElement("div");
        menuEl.className = "mv-var-menu";

        // Position below the variation button
        const btnRect = varBtn.getBoundingClientRect();
        menuEl.style.top = (btnRect.bottom + 4) + "px";

        for (let i = 0; i < names.length; i++) {
            const item = document.createElement("button");
            item.className = "mv-var-item";
            if (i === originalVariation) {
                item.classList.add("active");
            }
            item.textContent = names[i];
            item.dataset.index = String(i);

            item.addEventListener("mouseenter", function () {
                r.dataset.variation = this.dataset.index;
            });

            item.addEventListener("click", function (e) {
                e.stopPropagation();
                const idx = parseInt(this.dataset.index, 10);
                setVariation(theme, idx);
                r.dataset.variation = String(idx);
                updateVariationButton(theme, idx);
                originalVariation = null; // Don't revert
                closeMenu(false);
            });

            menuEl.appendChild(item);
        }

        document.body.appendChild(menuEl);
        menuOpen = true;

        // Close on click outside
        setTimeout(function () {
            document.addEventListener("click", onClickOutside);
            document.addEventListener("keydown", onEscape);
        }, 0);
    }

    function onClickOutside(e) {
        if (menuEl && !menuEl.contains(e.target) && e.target !== varBtn) {
            closeMenu(true);
            document.removeEventListener("click", onClickOutside);
            document.removeEventListener("keydown", onEscape);
        }
    }

    function onEscape(e) {
        if (e.key === "Escape" && menuOpen) {
            closeMenu(true);
            document.removeEventListener("click", onClickOutside);
            document.removeEventListener("keydown", onEscape);
        }
    }

    varBtn.addEventListener("click", function (e) {
        e.stopPropagation();
        openMenu();
    });

    // Expose applyVariation for theme toggle coordination
    window.mdviewer_applyVariation = applyVariation;
})();

(function () {
    const cfg = window.mdviewer_config || {};
    const docId = cfg.docId || "global";
    const imgKey = "mdviewer_remote_images_" + docId;
    const ackKey = "mdviewer_remote_images_ack_" + docId;

    const btn = document.getElementById("mvImages");

    function safeGet(k) {
        try {
            return localStorage.getItem(k);
        } catch {
            return null;
        }
    }
    function safeSet(k, v) {
        try {
            localStorage.setItem(k, v);
        } catch {}
    }

    const wantRemote = safeGet(imgKey) === "1";
    const hasRemote = !!cfg.remoteUrl;
    const isRemotePage = !!cfg.remoteEnabled;

    // If the remote variant exists, enforce the user preference by switching pages.
    if (hasRemote && wantRemote !== isRemotePage) {
        window.location.replace(wantRemote ? cfg.remoteUrl : cfg.localUrl);
        return;
    }

    // Only show/enable the button if remote images exist for this doc
    if (!btn || !hasRemote) return;

    btn.textContent = isRemotePage ? "Images: Remote" : "Images: Local";

    btn.addEventListener("click", function () {
        const nextRemote = !isRemotePage;

        // Only prompt on first enable of Remote for this document
        if (nextRemote) {
            const alreadyAcked = safeGet(ackKey) === "1";
            if (!alreadyAcked) {
                const ok = window.confirm(
                    "Enable remote images for this document?\n\n" +
                        "This will allow the page to load images from the internet (e.g., badges), " +
                        "which can reveal your IP address and that you opened this file.\n\n" +
                        "Click OK to enable remote images, or Cancel to keep local-only.",
                );
                if (!ok) return;
                safeSet(ackKey, "1");
            }
        }

        safeSet(imgKey, nextRemote ? "1" : "0");
        window.location.href = nextRemote ? cfg.remoteUrl : cfg.localUrl;
    });
})();

(function () {
    function rewriteInPageAnchors() {
        const page = window.location.href.split("#")[0];

        document.querySelectorAll('a[href^="#"], a[href^="./#"]').forEach(
            (a) => {
                let href = a.getAttribute("href");
                if (!href) return;

                // Normalize "./#id" -> "#id"
                if (href.startsWith("./#")) href = href.slice(1);

                // Skip plain "#"
                if (href === "#" || href === "") return;

                if (!href.startsWith("#")) return;

                a.setAttribute("href", page + href);
            },
        );
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", rewriteInPageAnchors);
    } else {
        rewriteInPageAnchors();
    }
})();

(function () {
    const cfg = window.mdviewer_config || {};
    const base = cfg.mdDirBase;
    if (!base) return;

    function isMarkdownHref(href) {
        return /\.(md|markdown)(\?.*)?(#.*)?$/i.test(href);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", rewriteMarkdownLinks);
    } else {
        rewriteMarkdownLinks();
    }

    function rewriteMarkdownLinks() {
        document.querySelectorAll("a[href]").forEach((a) => {
            const href = a.getAttribute("href");
            if (!href) return;

            const h = href.trim();

            // Skip in-page anchors and already-custom protocol
            if (h.startsWith("#") || h.toLowerCase().startsWith("mdview:")) {
                return;
            }

            let abs;
            try {
                abs = new URL(h, base).href; // resolves against the markdown dir base
            } catch {
                return;
            }

            // Only rewrite local markdown targets
            if (abs.toLowerCase().startsWith("file:") && isMarkdownHref(abs)) {
                a.setAttribute("href", "mdview:" + abs);
            }
        });
    }
})();
