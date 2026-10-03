/* Main-thread WebGL call time only; never a GPU timer or a command trace. */
(() => {
  'use strict';
  if (window.GodotProfilerRenderProbe) return;
  const canvas = document.getElementById('canvas');
  const now = () => performance.now();
  const groups = {
    buffer_upload: ['bufferData', 'bufferSubData'],
    texture_upload: ['texImage2D', 'texSubImage2D', 'compressedTexImage2D',
      'compressedTexSubImage2D', 'texImage3D', 'texSubImage3D',
      'compressedTexImage3D', 'compressedTexSubImage3D', 'texStorage2D', 'texStorage3D', 'generateMipmap'],
    shader_compile: ['compileShader'],
    shader_link: ['linkProgram'],
    shader_query: ['getShaderParameter', 'getProgramParameter', 'getUniformLocation', 'getUniformBlockIndex'],
    state_query: ['getParameter', 'isEnabled'],
    program_bind: ['useProgram'],
    draw: ['drawArrays', 'drawElements', 'drawArraysInstanced', 'drawElementsInstanced'],
    framebuffer: ['blitFramebuffer', 'copyTexImage2D', 'copyTexSubImage2D',
      'renderbufferStorage', 'renderbufferStorageMultisample'],
    readback: ['readPixels', 'getBufferSubData'],
    sync: ['finish', 'flush', 'clientWaitSync', 'getSyncParameter'],
  };
  let enabled = false;
  let stats = Object.create(null);
  let slowest = null;
  let installed = false;
  const wrapped = [];
  const round = value => Math.round(value * 100) / 100;
  const metadataMethods = ['shaderSource', 'attachShader', 'detachShader'];
  const shaderMethods = new Set([...metadataMethods, ...groups.shader_compile,
    ...groups.shader_link, ...groups.shader_query]);
  // Flags come from Godot's GLES3 templates. Never retain source, uniform names,
  // source comments or arbitrary user-defined macros in the report.
  const variantFlags = ['MODE_UNSHADED', 'MODE_RENDER_DEPTH', 'USE_INSTANCING',
    'BASE_PASS', 'APPLY_TONEMAPPING', 'DISABLE_FOG', 'FOG_DISABLED', 'USE_DEPTH_FOG',
    'USE_SUN_SCATTER', 'DISABLE_LIGHT_DIRECTIONAL', 'DISABLE_LIGHT_OMNI',
    'DISABLE_LIGHT_SPOT', 'DISABLE_LIGHT_AREA', 'DISABLE_LIGHTMAP',
    'DISABLE_REFLECTION_PROBE', 'USE_RADIANCE_MAP', 'USE_LIGHTMAP', 'USE_SH_LIGHTMAP',
    'USE_LIGHTMAP_CAPTURE', 'USE_MULTIVIEW', 'RENDER_SHADOWS', 'RENDER_SHADOWS_LINEAR',
    'USE_ADDITIVE_LIGHTING', 'ADDITIVE_OMNI', 'ADDITIVE_SPOT', 'SHADOW_MODE_PCF_5',
    'SHADOW_MODE_PCF_13', 'LIGHT_USE_PSSM2', 'LIGHT_USE_PSSM4', 'LIGHT_USE_PSSM_BLEND',
    'SECOND_REFLECTION_PROBE', 'RENDER_MATERIAL', 'RENDER_MOTION_VECTORS'];
  const MAX_SOURCE_GROUPS = 256, TOP_SOURCE_GROUPS = 6, MAX_DEFINES_LENGTH = 256;
  const shaders = new WeakMap(), programs = new WeakMap();
  let sourceGroups = new Map(), collection = 0, metadataMs = 0, untrackedLinks = 0;
  let untrackedQueryMs = 0;
  let stateQueries = {};
  const isObject = value => value !== null && (typeof value === 'object' || typeof value === 'function');
  function reset() { stats = Object.create(null); slowest = null; }
  function resetCollection() {
    reset(); collection++; sourceGroups = new Map();
    metadataMs = 0; untrackedLinks = 0; untrackedQueryMs = 0;
    stateQueries = {};
  }
  function fingerprint(source) {
    // FNV-1a identifies sources for diagnostics, not integrity/security checks.
    let hash = 2166136261;
    for (let i = 0; i < source.length; i++) hash = Math.imul(hash ^ source.charCodeAt(i), 16777619);
    const definitions = new Set();
    // Godot emits the actual variant defines before its precision declarations;
    // conditional macros in the shader body do not describe the selected variant.
    const precision = source.search(/^\s*precision\s/m);
    const header = precision < 0 ? source : source.slice(0, precision);
    for (const match of header.matchAll(/^\s*#define\s+([A-Z][A-Z0-9_]*)\b/gm)) definitions.add(match[1]);
    return { hash: (hash >>> 0).toString(16).padStart(8, '0'),
      flags: variantFlags.filter(flag => definitions.has(flag)) };
  }
  function shaderWork(shader) {
    const data = isObject(shader) ? shaders.get(shader) : null;
    if (!data) return null;
    if (data.collection !== collection) {
      data.collection = collection; data.compileMs = 0; data.queryMs = 0; data.maxQueryMs = 0;
    }
    return data;
  }
  function programData(program) {
    if (!isObject(program)) return null;
    let data = programs.get(program);
    if (!data) { data = { shaders: [], descriptor: null }; programs.set(program, data); }
    return data;
  }
  function sourceGroup(descriptor) {
    if (!descriptor) return null;
    let entry = sourceGroups.get(descriptor.hash);
    if (!entry && sourceGroups.size < MAX_SOURCE_GROUPS) {
      entry = { ...descriptor, links: 0, compile_ms: 0, link_ms: 0, query_ms: 0, max_query_ms: 0 };
      sourceGroups.set(descriptor.hash, entry);
    }
    return entry || null;
  }
  function observeShader(name, args, elapsed, succeeded) {
    if (name === 'shaderSource') {
      if (succeeded && isObject(args[0]) && typeof args[1] === 'string') {
        shaders.set(args[0], fingerprint(args[1]));
      }
      return;
    }
    if (name === 'attachShader' || name === 'detachShader') {
      if (!succeeded || !isObject(args[1])) return;
      const program = programData(args[0]);
      if (!program) return;
      if (name === 'detachShader') program.shaders = program.shaders.filter(shader => shader !== args[1]);
      // WebGL programs can attach one vertex and one fragment shader.
      else if (program.shaders.length < 2 && !program.shaders.includes(args[1])) program.shaders.push(args[1]);
      return;
    }
    if (name === 'compileShader' || name === 'getShaderParameter') {
      const shader = shaderWork(args[0]);
      if (!shader) { if (name === 'getShaderParameter') untrackedQueryMs += elapsed; return; }
      if (name === 'compileShader') { shader.linkedDescriptor = null; shader.compileMs += elapsed; }
      else if (shader.linkedDescriptor) {
        const entry = sourceGroup(shader.linkedDescriptor);
        if (entry) { entry.query_ms += elapsed; entry.max_query_ms = Math.max(entry.max_query_ms, elapsed); }
        else untrackedQueryMs += elapsed;
      } else { shader.queryMs += elapsed; shader.maxQueryMs = Math.max(shader.maxQueryMs, elapsed); }
      return;
    }
    const program = programData(args[0]);
    if (name === 'linkProgram') {
      if (!program || !succeeded) { untrackedLinks++; return; }
      const stages = program.shaders.map(shaderWork).filter(Boolean);
      if (stages.length !== 2) { program.descriptor = null; untrackedLinks++; return; }
      const flags = variantFlags.filter(flag => stages.some(stage => stage.flags.includes(flag)));
      let defines = '', included = 0;
      for (const flag of flags) {
        const next = defines ? `${defines},${flag}` : flag;
        if (next.length > MAX_DEFINES_LENGTH) break;
        defines = next; included++;
      }
      program.descriptor = { hash: stages.map(stage => stage.hash).sort().join('/'),
        defines, more_defines: flags.length - included };
      const entry = sourceGroup(program.descriptor);
      if (entry) {
        entry.links++; entry.link_ms += elapsed;
        for (const stage of stages) {
          entry.compile_ms += stage.compileMs; entry.query_ms += stage.queryMs;
          entry.max_query_ms = Math.max(entry.max_query_ms, stage.maxQueryMs);
        }
      } else {
        untrackedLinks++; untrackedQueryMs += stages.reduce((total, stage) => total + stage.queryMs, 0);
      }
      // A shared stage's earlier work belongs to its first observed link only.
      for (const stage of stages) {
        stage.compileMs = 0; stage.queryMs = 0; stage.maxQueryMs = 0;
        stage.linkedDescriptor = program.descriptor;
      }
      return;
    }
    const entry = sourceGroup(program && program.descriptor);
    if (entry) { entry.query_ms += elapsed; entry.max_query_ms = Math.max(entry.max_query_ms, elapsed); }
    else untrackedQueryMs += elapsed;
  }
  function programSummary() {
    const top = [...sourceGroups.values()].sort((a, b) =>
      (b.compile_ms + b.link_ms + b.query_ms) - (a.compile_ms + a.link_ms + a.query_ms)
    ).slice(0, TOP_SOURCE_GROUPS).map(entry => ({ ...entry,
      compile_ms: round(entry.compile_ms), link_ms: round(entry.link_ms),
      query_ms: round(entry.query_ms), max_query_ms: round(entry.max_query_ms) }));
    return { scope: 'since_collection_reset', hash_algorithm: 'fnv1a32_stage_pair',
      source_groups: sourceGroups.size, source_group_limit: MAX_SOURCE_GROUPS,
      untracked_links: untrackedLinks, untracked_query_ms: round(untrackedQueryMs),
      metadata_ms: round(metadataMs), top };
  }
  function stateQuerySummary() {
    const calls = Object.fromEntries(Object.entries(stateQueries).map(([key, value]) =>
      [key, [value[0], round(value[1]), round(value[2])]]));
    // Preserve the old getParameter-only name. This alias is not another call.
    if (calls.scissor_test_get_parameter) calls.scissor_test = calls.scissor_test_get_parameter;
    return { scope: 'since_collection_reset', calls };
  }
  function attach(gl) {
    if (!gl || installed) return;
    installed = true;
    for (const [group, names] of [...Object.entries(groups), [null, metadataMethods]]) {
      for (const name of names) {
        const original = gl[name];
        if (typeof original !== 'function') continue;
        // Only this game's context is changed, never WebGL prototypes or other canvases.
        const wrapper = function () {
          if (!enabled) return original.apply(this, arguments);
          const start = now(), currentCollection = collection;
          let succeeded = false;
          try { const result = original.apply(this, arguments); succeeded = true; return result; }
          finally {
            // Optional diagnostics must never replace the driver's return/exception.
            try {
              if (enabled && collection === currentCollection) {
                const end = now(), elapsed = Math.max(0, end - start);
                if (group) {
                  const entry = stats[group] || (stats[group] = [0, 0, 0]);
                  entry[0]++; entry[1] += elapsed; entry[2] = Math.max(entry[2], elapsed);
                  if (!slowest || elapsed > slowest[1]) slowest = [name, elapsed];
                }
                if (group === 'state_query') {
                  const parameter = arguments[0] === 3089
                    ? (name === 'isEnabled' ? 'scissor_test_is_enabled' : 'scissor_test_get_parameter')
                    : (name === 'getParameter' && arguments[0] === 36006 ? 'framebuffer_binding' : null);
                  if (parameter) {
                    const entry = stateQueries[parameter] || (stateQueries[parameter] = [0, 0, 0]);
                    entry[0]++; entry[1] += elapsed; entry[2] = Math.max(entry[2], elapsed);
                  }
                }
                if (shaderMethods.has(name)) {
                  observeShader(name, arguments, elapsed, succeeded);
                  metadataMs += Math.max(0, now() - end);
                }
              }
            } catch (_) { /* Best-effort metadata, never a rendering dependency. */ }
          }
        };
        try {
          gl[name] = wrapper;
          if (gl[name] === wrapper) wrapped.push(name);
        } catch (_) { /* Optional diagnostics must not prevent rendering. */ }
      }
    }
  }
  if (canvas && typeof canvas.getContext === 'function') {
    const getContext = canvas.getContext;
    canvas.getContext = function (type) {
      const context = getContext.apply(this, arguments);
      if (this === canvas && (type === 'webgl2' || type === 'webgl')) attach(context);
      return context;
    };
  }
  window.GodotProfilerRenderProbe = {
    setEnabled(value) { enabled = !!value && !document.hidden; resetCollection(); },
    snapshotJSON() {
      const calls = {};
      for (const [name, entry] of Object.entries(stats)) {
        calls[name] = [entry[0], round(entry[1]), round(entry[2])];
      }
      const result = { calls };
      if (slowest) result.slowest = [slowest[0], round(slowest[1])];
      reset();
      return JSON.stringify(result);
    },
    capabilities() { return { installed, enabled, wrapped_methods: wrapped.slice(),
      shader_programs: programSummary(), state_queries: stateQuerySummary() }; },
  };
  document.addEventListener('visibilitychange', () => {
    // The engine explicitly enables collection again after resetting its window.
    if (document.hidden) { enabled = false; resetCollection(); }
  });
})();
