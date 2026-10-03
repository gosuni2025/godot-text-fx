(() => {
  // Mark at first physics/process and post_draw; optional resource hooks report into the same RAF.
  // begin(0)/invalidate() must be called when Godot's scope guard becomes invalid.
  if (window.GodotProfilerFrameProbe) return;
  const round = value => Math.round(value * 1000) / 1000;
  const CAPACITY = 8192, HORIZON = 30000, WIDTH = 17;
  const rows = new Float64Array(CAPACITY * WIDTH);
  const shaderRows = Array(CAPACITY).fill(null);
  const originalRAF = window.requestAnimationFrame;
  const now = () => performance.now();
  let head = 0, size = 0, activeMs = 0, scope = null, active = false;
  let owner = null, current = null, pending = null, generation = 0, serial = 0, disposed = false;
  let capacityDropped = 0, invalidSpans = 0, nonEngineCallbacks = 0;
  let focused = typeof document.hasFocus !== 'function' || document.hasFocus();
  let visible = !document.hidden;
  function invalidate() {
    active = false; pending = null; generation++;
    if (current) current.invalid = true;
  }
  function reset(nextScope) {
    invalidate(); scope = nextScope; head = size = activeMs = 0;
    shaderRows.fill(null);
    capacityDropped = invalidSpans = nonEngineCallbacks = 0;
  }
  function begin(nextScope, godotFrame = -1) {
    if (!nextScope) { invalidate(); return false; }
    if (disposed || !focused || !visible || !current) return false;
    if (scope !== nextScope) {
      reset(nextScope); current.invalid = false;
    }
    if (current.invalid || current.post !== null) return false;
    if (current.first !== null) return true; // Defensive: never charge a second physics tick as a new frame.
    if (owner !== current.callback) { pending = null; owner = current.callback; }
    active = true; current.generation = generation;
    current.scope = scope; current.first = now();
    current.godotFrame = Number.isSafeInteger(godotFrame) ? godotFrame : -1;
    return true;
  }
  function end(nextScope) {
    if (!nextScope || nextScope !== scope) { invalidate(); return false; }
    if (disposed || !active || !current || current.invalid) return false;
    if (current.first === null) { current.invalid = true; return false; }
    if (current.post !== null) return true;
    current.post = now(); return true;
  }
  function storePrevious(next) {
    if (!pending) return;
    const dt = next.start - pending.start, cadence = next.timestamp - pending.timestamp;
    const outside = next.start - pending.returned;
    if (!(dt > 0 && dt <= HORIZON && cadence > 0 && outside >= 0)) { invalidSpans++; return; }
    activeMs += dt;
    while (size && rows[head * WIDTH] - rows[head * WIDTH + 1] < activeMs - HORIZON) {
      shaderRows[head] = null;
      head = (head + 1) % CAPACITY; size--;
    }
    if (size === CAPACITY) { head = (head + 1) % CAPACITY; size--; capacityDropped++; }
    const at = ((head + size++) % CAPACITY) * WIDTH, marked = pending.first !== null;
    rows[at] = activeMs; rows[at + 1] = dt;
    rows[at + 2] = pending.returned - pending.start;
    rows[at + 3] = marked ? pending.first - pending.start : NaN;
    rows[at + 4] = marked ? pending.post - pending.first : NaN;
    rows[at + 5] = marked ? pending.returned - pending.post : NaN;
    rows[at + 6] = outside; rows[at + 7] = cadence; rows[at + 8] = Number(marked);
    rows[at + 9] = pending.godotFrame;
    rows[at + 10] = pending.nativeId; rows[at + 11] = pending.nativeMax;
    rows[at + 12] = pending.nativeA; rows[at + 13] = pending.nativeB; rows[at + 14] = pending.nativeC;
    rows[at + 15] = pending.nativeCount; rows[at + 16] = pending.nativeTotal;
    const shaders = pending.shaderCalls;
    if (shaders) {
      shaders.rows.sort((a, b) => b.total - a.total);
      shaders.omitted_groups = Math.max(0, shaders.rows.length - 8);
      shaders.rows.length = Math.min(shaders.rows.length, 8);
    }
    shaderRows[at / WIDTH] = shaders;
  }
  function wrappedRAF(callback) {
    return originalRAF.call(window, timestamp => {
      const previousCurrent = current;
      const frame = {callback, timestamp, start: now(), first: null, post: null,
        returned: 0, scope, generation, token: ++serial, invalid: false, godotFrame: -1,
        nativeId: -1, nativeMax: 0, nativeA: -1, nativeB: -1, nativeC: -1, nativeCount: 0, nativeTotal: 0, shaderCalls: null};
      current = frame; let succeeded = false;
      try { const value = callback.call(window, timestamp); succeeded = true; return value; }
      finally {
        frame.returned = now(); current = previousCurrent;
        if (callback === owner && !disposed) {
          const marked = frame.first !== null;
          const ordered = !marked || (frame.post !== null && frame.start <= frame.first
            && frame.first <= frame.post && frame.post <= frame.returned);
          if (succeeded && active && focused && visible && !frame.invalid && ordered
              && frame.generation === generation && frame.scope === scope) {
            storePrevious(frame); pending = frame;
          } else { pending = null; if (active) invalidSpans++; }
        } else if (active) nonEngineCallbacks++;
      }
    });
  }
  function distribution(values) {
    if (!values.length) return {count: 0, p50: null, p95: null, max: null};
    values.sort((a, b) => a - b); const n = values.length;
    return {count: n, p50: round((values[Math.floor((n - 1) / 2)] + values[Math.floor(n / 2)]) / 2),
      p95: round(values[Math.ceil(n * 0.95) - 1]), max: round(values[n - 1])};
  }
  function nativeToken() {
    return !disposed && active && focused && visible && current && !current.invalid
      && current.first !== null && current.post === null && current.generation === generation
      && current.scope === scope ? current.token : 0;
  }
  function nativeFrame() { return nativeToken() ? current.godotFrame : -1; }
  function recordNative(token, id, started, ended, a = -1, b = -1, c = -1, detail = null) {
    if (!token || token !== nativeToken() || !Number.isInteger(id) || id < 0 || id > 12
        || !Number.isFinite(started) || !Number.isFinite(ended) || started < current.first || ended < started) return;
    const elapsed = ended - started;
    current.nativeCount++; current.nativeTotal += elapsed;
    if (detail && window.GodotProfilerShaderProbe) {
      current.shaderCalls ||= {rows: [], dropped_calls: 0, dropped_ms: 0};
      window.GodotProfilerShaderProbe.accumulate(current.shaderCalls, detail, id, elapsed, ended, a);
    }
    if (current.nativeId < 0 || elapsed > current.nativeMax) {
      current.nativeId = id; current.nativeMax = elapsed;
      current.nativeA = Number.isFinite(a) ? a : -1;
      current.nativeB = Number.isFinite(b) ? b : -1;
      current.nativeC = Number.isFinite(c) ? c : -1;
    }
  }
  function snapshot() {
    const columns = Array.from({length: 7}, () => []), bounds = [8, 10, 13, 15, 18, 25, 35, 50];
    const histogram = Array(bounds.length + 1).fill(0);
    let elapsed = 0, marked = 0, over16 = 0;
    const worst = [], nativeProbe = window.GodotProfilerNativeCallProbe;
    for (let i = 0; i < size; i++) {
      const at = ((head + i) % CAPACITY) * WIDTH;
      elapsed += rows[at + 1]; marked += rows[at + 8]; over16 += Number(rows[at + 2] > 16);
      for (let j = 0; j < columns.length; j++) if (Number.isFinite(rows[at + j + 1])) columns[j].push(rows[at + j + 1]);
      const bin = bounds.findIndex(limit => rows[at + 7] < limit);
      histogram[bin < 0 ? bounds.length : bin]++;
      if (nativeProbe && rows[at + 2] > 16 && rows[at + 8] && rows[at + 9] >= 0) {
        worst.push(at);
        worst.sort((a, b) => rows[b + 2] - rows[a + 2]);
        if (worst.length > 8) worst.pop();
      }
    }
    const names = ['callback_interval_ms', 'callback_cpu_wall_ms', 'before_first_mark_ms',
      'marked_work_ms', 'after_post_draw_ms', 'outside_engine_callback_ms', 'raf_timestamp_interval_ms'];
    const result = {version: 2, scope, active, horizon_active_ms: HORIZON, active_elapsed_ms: round(elapsed),
      callback_count: size, godot_rendered_frames: marked, unmarked_engine_callbacks: size - marked,
      godot_fps: elapsed > 0 ? round(marked * 1000 / elapsed) : null, cpu_wall_over_16ms: over16,
      phases: Object.fromEntries(names.map((name, i) => [name, distribution(columns[i])])),
      raf_cadence_histogram: {upper_exclusive_ms: bounds, counts: histogram},
      capacity: CAPACITY, capacity_dropped: capacityDropped, invalid_spans_since_scope: invalidSpans,
      non_engine_callbacks_since_scope: nonEngineCallbacks, pending_frame_excluded: !!pending,
      meaning: 'CPU wall boundaries, not GPU time or presentation; outside includes other browser work; unmarked owner callbacks are possible cap skips'};
    if (nativeProbe) result.native_calls = {version: 1, methods: nativeProbe.methods,
      installed: nativeProbe.installed, frame_limit: 8,
      frames: worst.map(at => ({frame_id: rows[at + 9], cpu_wall_ms: round(rows[at + 2]),
        tracked_calls: rows[at + 15], tracked_total_ms: round(rows[at + 16]),
        // Keep primitive arguments at depth <= 8 in the shared report schema.
        max_call_method: rows[at + 10] < 0 ? null : nativeProbe.methods[rows[at + 10]],
        max_call_ms: rows[at + 10] < 0 ? null : round(rows[at + 11]),
        max_call_args: rows[at + 10] < 0 ? null : [rows[at + 12], rows[at + 13], rows[at + 14]]})),
      meaning: 'Same completed RAF; original synchronous API wall inside first-to-post marks; not GPU time or retained allocation. Max one call, total tracked calls; no draw hooks. JS Memory.grow only.'};
    if (nativeProbe && window.GodotProfilerShaderProbe) {
      const shaderProbe = window.GodotProfilerShaderProbe, groups = [];
      let droppedCalls = 0, droppedMs = 0, omittedGroups = 0;
      for (const at of worst) {
        const calls = shaderRows[at / WIDTH];
        if (!calls) continue;
        droppedCalls += calls.dropped_calls; droppedMs += calls.dropped_ms;
        omittedGroups += calls.omitted_groups;
        for (const row of calls.rows) groups.push({row, frame: rows[at + 9]});
      }
      groups.sort((a, b) => b.row.total - a.row.total);
      Object.assign(result.native_calls, {version: 2, shader_metadata_version: shaderProbe.version,
        shader_hooks: shaderProbe.installed, shader_frames: groups.slice(0, 8).map(g => shaderProbe.describe(g.row, g.frame, nativeProbe.methods)),
        shader_groups_omitted: omittedGroups + Math.max(0, groups.length - 8), shader_calls_dropped: droppedCalls, shader_ms_dropped: round(droppedMs),
        shader_meaning: 'Observed compile/link attempts and queries, grouped per same completed RAF. Candidates are generated-identifier matches, not material instances. Header defines stop before conditionals; hashes are FNV1a32, not integrity. No source or extra GL queries.'});
    }
    return result;
  }
  // Match the reporter's visibility window. Ordinary gameplay pauses still freeze history.
  const onBlur = () => { focused = false; reset(scope); };
  const onFocus = () => { focused = true; reset(scope); };
  const onVisibility = () => { visible = !document.hidden; reset(scope); };
  window.requestAnimationFrame = wrappedRAF;
  window.addEventListener('blur', onBlur); window.addEventListener('focus', onFocus);
  document.addEventListener('visibilitychange', onVisibility);
  window.GodotProfilerFrameProbe = {begin, end, invalidate, snapshot, nativeToken, nativeFrame, recordNative, dispose() {
    invalidate(); disposed = true;
    shaderRows.fill(null);
    if (window.requestAnimationFrame === wrappedRAF) window.requestAnimationFrame = originalRAF;
    window.removeEventListener('blur', onBlur); window.removeEventListener('focus', onFocus);
    document.removeEventListener('visibilitychange', onVisibility);
  }};
})();
