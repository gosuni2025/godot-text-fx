extends RefCounted
## One immediate step, then timed repeats for physical keys, D-pad and left stick.
const DIRECTIONS := {"ui_up": Vector2i.UP, "ui_left": Vector2i.LEFT, "ui_down": Vector2i.DOWN, "ui_right": Vector2i.RIGHT}
const PHYSICAL_KEYS := {"ui_up": [KEY_UP, KEY_W], "ui_down": [KEY_DOWN, KEY_S], "ui_left": [KEY_LEFT, KEY_A], "ui_right": [KEY_RIGHT, KEY_D]}
const REPEAT_DELAY := 0.35
const REPEAT_INTERVAL := 0.10
var _action := ""
var _remaining := 0.0

func reset() -> void:
	_action = ""
	_remaining = 0.0

func handle_input(event: InputEvent, buttons: Array[Button], viewport: Viewport) -> bool:
	return handle_direction(event, _move.bind(buttons, viewport))

func handle_direction(event: InputEvent, move: Callable) -> bool:
	for action in DIRECTIONS:
		var physical: bool = event is InputEventKey and event.pressed and event.physical_keycode in PHYSICAL_KEYS[action]
		if not physical and not event.is_action_pressed(action, true): continue
		# OS key echoes and small stick changes must not add extra focus steps.
		if _action != action:
			_action = action
			_remaining = REPEAT_DELAY
			move.call(DIRECTIONS[action])
		return true
	if not _action.is_empty() and event.is_action_released(_action):
		# A neutral stick also reports a release for the D-pad's UI action.
		# Keep repeating while any binding still holds the aggregate action.
		if not _held(_action): reset()
		return true
	return false

func process(delta: float, buttons: Array[Button], viewport: Viewport) -> void:
	repeat_direction(delta, _move.bind(buttons, viewport))

func repeat_direction(delta: float, move: Callable) -> void:
	if _action.is_empty(): return
	if not _held(_action):
		reset()
		return
	_remaining -= delta
	if _remaining <= 0.0:
		move.call(DIRECTIONS[_action])
		_remaining = REPEAT_INTERVAL

func _move(direction: Vector2i, buttons: Array[Button], viewport: Viewport) -> void:
	if buttons.is_empty(): return
	var step := direction.x + direction.y
	var index := buttons.find(viewport.gui_get_focus_owner())
	if index < 0: index = -1 if step > 0 else 0
	buttons[posmod(index + step, buttons.size())].grab_focus()

func _held(action: String) -> bool:
	if Input.is_action_pressed(action): return true
	for key in PHYSICAL_KEYS[action]:
		if Input.is_physical_key_pressed(key): return true
	return false

## Existing adapters may supply their own action names without changing InputMap.
static func category_step(event: InputEvent, previous := &"", next := &"") -> int:
	if event.is_echo(): return 0
	if not previous.is_empty() and event.is_action_pressed(previous): return -1
	if not next.is_empty() and event.is_action_pressed(next): return 1
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER: return -1
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER: return 1
	if event is InputEventKey and event.pressed:
		if event.physical_keycode in [KEY_Q, KEY_PAGEUP]: return -1
		if event.physical_keycode in [KEY_E, KEY_PAGEDOWN]: return 1
	return 0

## Godot 4.7 leaves accept/cancel unbound on pads in a new project.
## Forward only missing accept bindings through the native GUI path.
static func forward_pad_accept(event: InputEvent, viewport: Viewport) -> bool:
	if not event is InputEventJoypadButton or event.button_index != JOY_BUTTON_A or event.is_action("ui_accept"): return false
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = event.pressed
	viewport.push_input(accept)
	viewport.set_input_as_handled()
	return true

static func cancel_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
