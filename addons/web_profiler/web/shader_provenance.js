(() => {
  // Observe arguments already submitted by Godot. No GL queries, retained GL handles,
  // shader edits, draw/useProgram hooks, source uploads or per-frame source parsing.
  if (window.GodotProfilerShaderProbe) return;
  const shaders = new WeakMap(), programs = new WeakMap(), restores = [], installed = [];
  const catalog = window.GodotProfilerShaderCatalog || {};
  const variants = new Map();
  let variantsEvicted = 0;
  let serial = 0;
  const object = value => value !== null && (typeof value === 'object' || typeof value === 'function');
  const round = value => Math.round(value * 1000) / 1000;
  function shader(handle) {
    if (!object(handle)) return null;
    if (!shaders.has(handle)) shaders.set(handle, {id: ++serial, type: 0, source: null, compiled: null});
    return shaders.get(handle);
  }
  function program(handle) {
    if (!object(handle)) return null;
    if (!programs.has(handle)) programs.set(handle, {id: ++serial, attached: new Map(), links: 0, linked: null});
    return programs.get(handle);
  }
  function sourceInfo(source) {
    // A non-cryptographic identity, paired with character count. Never an integrity proof.
    let hash = 2166136261;
    for (let i = 0; i < source.length; i++) hash = Math.imul(hash ^ source.charCodeAt(i), 16777619);
    const symbols = [...new Set(source.match(/\bm_[A-Za-z_0-9]+\b/g) || [])].sort();
    const votes = new Map();
    for (const symbol of symbols) for (const path of catalog[symbol] || []) {
      votes.set(path, (votes.get(path) || 0) + 1 / catalog[symbol].length);
    }
    const ranked = [...votes].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
    const candidates = ranked.filter(row => row[1] === ranked[0]?.[1]).map(row => row[0]);
    // Only the unconditional header preceding the first conditional or precision line.
    // Do not mistake #defines in inactive engine branches for active variants.
    const header = source.split(/^\s*(?:#\s*(?:if|ifdef|ifndef)\b|precision\b)/m, 1)[0];
    const defines = [...header.matchAll(/^\s*#define\s+([^\n]+)/gm)].map(m => m[1].trim()).join(';');
    return Object.freeze({hash: (hash >>> 0).toString(16).padStart(8, '0'), chars: source.length,
      candidates: candidates.join('|').slice(0, 240), symbols: symbols.join(' ').slice(0, 320),
      defines: defines.slice(0, 600), truncated: symbols.join(' ').length > 320 || defines.length > 600 || candidates.join('|').length > 240});
  }
  function wrap(prototype, name, observe) {
    if (!prototype || !Object.prototype.hasOwnProperty.call(prototype, name)) return;
    const descriptor = Object.getOwnPropertyDescriptor(prototype, name), original = descriptor?.value;
    if (typeof original !== 'function' || (!descriptor.configurable && !descriptor.writable)) return;
    const replacement = function (...args) {
      const value = Reflect.apply(original, this, args);
      observe(args, value); return value;
    };
    Object.defineProperty(prototype, name, {...descriptor, value: replacement});
    installed.push(name);
    restores.push(() => { if (prototype[name] === replacement) Object.defineProperty(prototype, name, descriptor); });
  }
  for (const prototype of [window.WebGLRenderingContext?.prototype, window.WebGL2RenderingContext?.prototype]) {
    wrap(prototype, 'createShader', (args, result) => { const s = shader(result); if (s) s.type = args[0]; });
    wrap(prototype, 'shaderSource', args => {
      const s = shader(args[0]);
      if (s && typeof args[1] === 'string') s.source = sourceInfo(args[1]);
    });
    wrap(prototype, 'attachShader', args => {
      const p = program(args[0]), s = shader(args[1]);
      if (p && s && p.attached.size < 8) p.attached.set(s.id, s);
    });
    wrap(prototype, 'detachShader', args => {
      const p = programs.get(args[0]), s = shaders.get(args[1]);
      if (p && s) p.attached.delete(s.id);
    });
  }
  function observe(id, args, started, ended, threw, frame) {
    if (id === 4 || id === 10) {
      const s = shader(args[0]); if (!s) return null;
      if (id === 4 && !threw) s.compiled = s.source;
      return {key: 's' + s.id + ':' + (s.compiled?.hash || '?'), shader_id: s.id,
        stage: s.type === 35633 ? 'vertex' : s.type === 35632 ? 'fragment' : 'unknown',
        source: s.compiled, at: null, link_frame_id: -1, link_during_collection: false};
    }
    if (id !== 5 && id !== 9) return null;
    const p = program(args[0]); if (!p) return null;
    if (id === 5 && !threw) {
      let vertex = null, fragment = null;
      for (const s of p.attached.values()) {
        if (s.type === 35633) vertex = s.compiled;
        if (s.type === 35632) fragment = s.compiled;
      }
      const variantKey = vertex && fragment ? vertex.hash + ':' + fragment.hash + ':' + vertex.chars + ':' + fragment.chars : null;
      const history = variantKey ? variants.get(variantKey) : null;
      p.linked = {key: 'p' + p.id + ':' + ++p.links, program_id: p.id, link_serial: p.links,
        at: started, vertex, fragment, link_frame_id: frame, link_during_collection: frame >= 0,
        prior_variant_links: history?.links || 0, prior_uncollected_links: history?.uncollected || 0,
        variant_history_complete: variantKey !== null && variantsEvicted === 0};
      if (variantKey) {
        if (!history && variants.size === 512) { variants.delete(variants.keys().next().value); variantsEvicted++; p.linked.variant_history_complete = false; }
        variants.set(variantKey, {links: (history?.links || 0) + 1, uncollected: (history?.uncollected || 0) + Number(frame < 0)});
      }
    }
    return p.linked || {key: 'p' + p.id + ':?', program_id: p.id, at: null,
      link_frame_id: -1, link_during_collection: false};
  }
  function accumulate(groups, detail, id, elapsed, ended, argument) {
    let row = groups.rows.find(row => row.detail.key === detail.key);
    if (!row) {
      if (groups.rows.length === 64) { groups.dropped_calls++; groups.dropped_ms += elapsed; return; }
      row = {detail, count: 0, total: 0, max: -1, method: -1, ended, methods: [0, 0, 0, 0]};
      groups.rows.push(row);
    }
    row.count++; row.total += elapsed; row.methods[[4, 5, 9, 10].indexOf(id)]++;
    if (elapsed > row.max) { row.max = elapsed; row.method = id; row.ended = ended; row.argument = argument; }
  }
  function describe(row, frame, methods) {
    const d = row.detail, v = d.vertex, f = d.fragment, s = d.source;
    const candidates = [...new Set([v?.candidates, f?.candidates, s?.candidates].filter(Boolean))].join('|');
    // Flat scalar fields: shared server depth limit is eight, including report wrappers.
    return {frame_id: frame, program_id: d.program_id || 0, shader_id: d.shader_id || 0,
      link_serial: d.link_serial || 0, link_observed: d.at !== null, link_frame_id: d.link_frame_id,
      link_during_collection: d.link_during_collection, link_age_ms: d.at === null ? null : round(row.ended - d.at),
      prior_variant_links: d.prior_variant_links || 0, prior_uncollected_links: d.prior_uncollected_links || 0,
      variant_history_complete: !!d.variant_history_complete,
      calls: row.count, total_ms: round(row.total), max_ms: round(row.max), max_method: methods[row.method],
      max_query_pname: row.method === 9 || row.method === 10 ? row.argument : null,
      compile_calls: row.methods[0], link_calls: row.methods[1], program_queries: row.methods[2], shader_queries: row.methods[3],
      vertex_hash: v?.hash || '', fragment_hash: f?.hash || '', shader_hash: s?.hash || '', stage: d.stage || 'program',
      source_chars: (v?.chars || 0) + (f?.chars || 0) + (s?.chars || 0),
      candidates: candidates.slice(0, 240), vertex_header_defines: v?.defines || '',
      header_defines: (f || s || v)?.defines || '', material_symbols: (f || s || v)?.symbols || '',
      metadata_truncated: candidates.length > 240 || !!(v?.truncated || f?.truncated || s?.truncated)};
  }
  window.GodotProfilerShaderProbe = {observe, accumulate, describe, installed, version: 1,
    dispose() { for (const restore of restores) restore(); }};
})();
