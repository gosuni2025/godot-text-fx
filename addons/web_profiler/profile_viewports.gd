extends RefCounted
## Optional viewport references, not precomputed metrics. The module reads dimensions.
var world: Viewport
var weapon: Viewport
var post: Viewport

## Explicit fixed labels for optional interval diagnostics (for example foreground).
var diagnostics: Dictionary[StringName, Viewport] = {}
