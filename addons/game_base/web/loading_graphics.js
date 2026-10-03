// Startup-only observations. No extra GL queries, buffer/source retention or telemetry.
window.createGodotBaseLoadingGraphics = function (canvas) {
    const restores = [], recent = [], calls = {};
    const start = performance.now();
    let live = true, slowest = null;
    const round = value => Math.round(value * 100) / 100;
    for (const prototype of [window.WebGLRenderingContext?.prototype, window.WebGL2RenderingContext?.prototype]) {
        for (const name of ['compileShader', 'linkProgram', 'getProgramParameter', 'getShaderParameter', 'texImage2D', 'bufferData']) {
            if (!prototype || !Object.prototype.hasOwnProperty.call(prototype, name)) continue;
            const descriptor = Object.getOwnPropertyDescriptor(prototype, name), original = descriptor?.value;
            if (typeof original !== 'function' || (!descriptor.configurable && !descriptor.writable)) continue;
            const replacement = function (...args) {
                if (!live) return Reflect.apply(original, this, args);
                const began = performance.now();
                let threw = true;
                try { const result = Reflect.apply(original, this, args); threw = false; return result; }
                finally {
                    const ended = performance.now(), elapsed = ended - began;
                    calls[name] = (calls[name] || 0) + 1;
                    if (elapsed >= 8 || name === 'compileShader' || name === 'linkProgram') {
                        const row = {method: name, at_ms: round(began - start), duration_ms: round(elapsed), threw};
                        const id = ['compileShader', 'getShaderParameter'].includes(name) ? 10
                            : ['linkProgram', 'getProgramParameter'].includes(name) ? 9 : -1;
                        // Read already captured shader provenance; query IDs never add a link/compile.
                        const probe = window.GodotProfilerShaderProbe;
                        const detail = id >= 0 ? probe?.observe(id, args, began, ended, threw, -1) : null;
                        if (detail) {
                            const source = detail.fragment || detail.source || detail.vertex;
                            row.shader = source?.candidates || '';
                            row.defines = source?.defines || '';
                            row.hash = source?.hash || '';
                        }
                        recent.push(row);
                        if (recent.length > 32) recent.shift();
                        if (!slowest || row.duration_ms > slowest.duration_ms) slowest = row;
                    }
                }
            };
            Object.defineProperty(prototype, name, {...descriptor, value: replacement});
            restores.push(() => { if (prototype[name] === replacement) Object.defineProperty(prototype, name, descriptor); });
        }
    }
    return {
        snapshot() {
            const rect = canvas.getBoundingClientRect?.();
            return {
                platform: String(navigator.platform || '').slice(0, 64), touch_points: Number(navigator.maxTouchPoints) || 0,
                dpr: Number(window.devicePixelRatio) || 1, canvas_px: [canvas.width || 0, canvas.height || 0],
                canvas_css_px: rect ? [round(rect.width), round(rect.height)] : [],
                visibility: document.visibilityState || 'unknown',
                // JS heap is not GPU/total process memory, and is unavailable on Safari.
                js_heap_used_bytes: performance.memory?.usedJSHeapSize ?? null,
                calls: {...calls}, recent: recent.slice(), slowest,
            };
        },
        stop() { live = false; restores.forEach(restore => restore()); },
    };
};
