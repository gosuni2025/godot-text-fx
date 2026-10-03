(() => {
  // Resource calls only. No extra GL queries, pixel reads, draw hooks or engine-private access.
  // Fixed numeric maxima belong to FrameProbe's existing bounded RAF ring.
  if (window.GodotProfilerNativeCallProbe || !window.GodotProfilerFrameProbe) return;
  const probe = window.GodotProfilerFrameProbe, restores = [], installed = [];
  const methods = ['texImage2D', 'texSubImage2D', 'deleteTexture', 'deleteBuffer',
    'compileShader', 'linkProgram', 'audio.createBuffer', 'audio.copyToChannel', 'wasm.Memory.grow',
    'getProgramParameter', 'getShaderParameter', 'getBufferSubData', 'readPixels'];
  const number = value => typeof value === 'number' && Number.isFinite(value) ? value : -1;
  function wrap(prototype, name, id) {
    // WebGL methods declared on a shared ancestor must never be wrapped twice.
    if (!prototype || !Object.prototype.hasOwnProperty.call(prototype, name)) return;
    const descriptor = Object.getOwnPropertyDescriptor(prototype, name), original = descriptor?.value;
    if (typeof original !== 'function' || (!descriptor.configurable && !descriptor.writable)) return;
    const replacement = function (...args) {
      const token = probe.nativeToken();
      const shaderProbe = (id === 4 || id === 5 || id === 9 || id === 10) ? window.GodotProfilerShaderProbe : null;
      if (!token && !shaderProbe) return Reflect.apply(original, this, args);
      const started = performance.now();
      let threw = true;
      try { const value = Reflect.apply(original, this, args); threw = false; return value; }
      finally {
        const ended = performance.now();
        const detail = shaderProbe?.observe(id, args, started, ended, threw, probe.nativeFrame());
        // Only primitives. Do not retain buffers, GL handles, audio, images or channel data.
        let a = -1, b = -1, c = -1;
        if (id === 0 && args.length >= 9) { a = number(args[3]); b = number(args[4]); c = number(args[2]); }
        else if (id === 1 && args.length >= 9) { a = number(args[4]); b = number(args[5]); c = number(args[6]); }
        else if (id === 6) { a = number(args[0]); b = number(args[1]); c = number(args[2]); }
        else if (id === 7) { a = ArrayBuffer.isView(args[0]) ? args[0].byteLength : -1; b = number(args[1]); c = number(args[2] ?? 0); }
        else if (id === 8) a = number(args[0]);
        else if (id === 9 || id === 10) a = number(args[1]);
        // Record the requested element count (0 means remainder), never the
        // destination heap's capacity or contents. Godot passes a Uint8Array.
        else if (id === 11) { a = number(args[0]); b = number(args[1]); c = number(args[4] ?? 0); }
        else if (id === 12) { a = number(args[2]); b = number(args[3]); c = number(args[4]); }
        probe.recordNative(token, id, started, ended, a, b, c, detail);
      }
    };
    Object.defineProperty(prototype, name, {...descriptor, value: replacement});
    installed.push(id);
    restores.push(() => {
      // Do not overwrite a later owner's wrapper.
      if (prototype[name] === replacement) Object.defineProperty(prototype, name, descriptor);
    });
  }
  for (const prototype of [window.WebGLRenderingContext?.prototype, window.WebGL2RenderingContext?.prototype]) {
    for (let id = 0; id < 6; id++) wrap(prototype, methods[id], id);
    for (let id = 9; id < methods.length; id++) wrap(prototype, methods[id], id);
  }
  wrap(window.BaseAudioContext?.prototype, 'createBuffer', 6);
  wrap(window.AudioBuffer?.prototype, 'copyToChannel', 7);
  wrap(window.WebAssembly?.Memory?.prototype, 'grow', 8);
  window.GodotProfilerNativeCallProbe = {methods, installed, dispose() { for (const restore of restores) restore(); }};
})();
