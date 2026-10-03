(() => {
  // One asynchronous render-span sample per second. Never wait for the GPU.
  if (window.GodotProfilerGPUProbe) return;
  let gl, ext, active = null, pending = null, scope = 0, last = -Infinity;
  let reason = 'not_initialized', rejected = 0, samples = [], epoch = 0;
  let focused = typeof document.hasFocus !== 'function' || document.hasFocus();
  let visible = !document.hidden;
  const round = value => Math.round(value * 1000) / 1000;
  function init() {
    if (reason !== 'not_initialized') return;
    const canvas = document.getElementById('canvas');
    gl = canvas && canvas.getContext('webgl2');
    ext = gl && gl.getExtension('EXT_disjoint_timer_query_webgl2');
    reason = ext ? 'available' : 'extension_unavailable';
    if (gl) {
      canvas.addEventListener('webglcontextlost', () => {
        active = pending = null; samples = []; epoch++; reason = 'context_lost';
      });
      canvas.addEventListener('webglcontextrestored', () => {
        ext = gl.getExtension('EXT_disjoint_timer_query_webgl2');
        reason = ext ? 'available' : 'extension_unavailable'; last = -Infinity;
      });
    }
  }
  function invalidate() {
    if (gl && !gl.isContextLost()) {
      if (active) { gl.endQuery(ext.TIME_ELAPSED_EXT); gl.deleteQuery(active.query); }
      if (pending) gl.deleteQuery(pending.query);
    }
    active = pending = null;
    epoch++;
  }
  function begin(nextScope) {
    init();
    if (!nextScope || !focused || !visible || reason !== 'available' || gl.isContextLost()) return false;
    if (scope !== nextScope) {
      invalidate(); samples = []; rejected = 0; scope = nextScope; last = -Infinity;
    }
    const now = performance.now();
    if (now - last < 1000 || active) return false;
    last = now;
    // Poll only at the next 1Hz sample, never once per draw or every frame.
    if (gl.getParameter(ext.GPU_DISJOINT_EXT)) {
      invalidate(); samples = []; rejected++; return false;
    }
    if (pending) {
      if (!gl.getQueryParameter(pending.query, gl.QUERY_RESULT_AVAILABLE)) {
        if (now - pending.at > 5000) { invalidate(); rejected++; }
        return false;
      }
      const elapsed = gl.getQueryParameter(pending.query, gl.QUERY_RESULT) / 1e6;
      if (pending.scope === scope && pending.epoch === epoch && Number.isFinite(elapsed) && elapsed >= 0) {
        samples.push({at: pending.at, ms: elapsed});
      } else rejected++;
      gl.deleteQuery(pending.query); pending = null;
    }
    samples = samples.filter(sample => now - sample.at <= 30000);
    // Do not nest a TIME_ELAPSED query owned by the engine or another tool.
    if (gl.getQuery(ext.TIME_ELAPSED_EXT, gl.CURRENT_QUERY) !== null) { rejected++; return false; }
    const query = gl.createQuery();
    if (!query) { rejected++; return false; }
    gl.beginQuery(ext.TIME_ELAPSED_EXT, query);
    active = {query, at: now, scope, epoch};
    return true;
  }
  function end(nextScope) {
    if (!active) return;
    gl.endQuery(ext.TIME_ELAPSED_EXT);
    if (nextScope === scope) pending = active;
    else { gl.deleteQuery(active.query); rejected++; }
    active = null;
  }
  function snapshot() {
    const now = performance.now();
    const values = samples.filter(sample => now - sample.at <= 30000).map(sample => sample.ms).sort((a, b) => a - b);
    const count = values.length;
    return {version: 1, reason, scope, count, rejected, sample_interval_ms: 1000, window_wall_ms: 30000,
      mean_ms: count ? round(values.reduce((a, b) => a + b, 0) / count) : null,
      p50_ms: count ? round((values[Math.floor((count - 1) / 2)] + values[Math.floor(count / 2)]) / 2) : null,
      p95_ms: count ? round(values[Math.ceil(count * 0.95) - 1]) : null,
      max_ms: count ? round(values[count - 1]) : null,
      meaning: 'Asynchronous pre_draw to post_draw GPU timeline span; includes submission gaps, excludes compositor and scanout; polling adds work on sampled frames; 30s wall window'};
  }
  function resetWindow() {
    invalidate(); samples = []; rejected = 0; last = -Infinity;
  }
  // Match reporter/CPU visibility boundaries; ordinary pause invalidate retains history.
  window.addEventListener('blur', () => { focused = false; resetWindow(); });
  window.addEventListener('focus', () => { focused = true; resetWindow(); });
  document.addEventListener('visibilitychange', () => { visible = !document.hidden; resetWindow(); });
  window.GodotProfilerGPUProbe = {init, begin, end, invalidate, snapshot};
})();
