(function () {
    const k = "mdviewer_theme_mode";
    const r = document.documentElement;
    const b = document.getElementById("mvTheme");
    const m = window.matchMedia &&
        window.matchMedia("(prefers-color-scheme: dark)");
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
    function apply(mode) {
        const th = effective(mode);
        r.dataset.theme = th;
        setLabel(mode, th);
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
})();

(function () {
    const cfg = window.mdviewer_config || {};
    const docId = cfg.docId || "global";
    const imgKey = "mdviewer_remote_images_" + docId;

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
        safeSet(imgKey, nextRemote ? "1" : "0");
        window.location.href = nextRemote ? cfg.remoteUrl : cfg.localUrl;
    });
})();
