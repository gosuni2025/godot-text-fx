extends RefCounted
## Scroll the existing container without taking focus from buttons or inventory.
const DEADZONE := 0.25
const SPEED := 180.0
var _device := -1
var _fraction := 0.0

func reset() -> void:
	_device = -1
	_fraction = 0.0

func handle_input(event: InputEvent) -> bool:
	if not event is InputEventJoypadMotion or event.axis != JOY_AXIS_RIGHT_Y: return false
	_device = event.device
	return true

func process(delta: float, scroll: ScrollContainer, enabled: bool) -> void:
	if not enabled:
		reset()
		return
	if _device < 0: return
	var axis := Input.get_joy_axis(_device, JOY_AXIS_RIGHT_Y)
	if absf(axis) <= DEADZONE:
		_fraction = 0.0
		return
	var strength := signf(axis) * (absf(axis) - DEADZONE) / (1.0 - DEADZONE)
	_fraction += strength * SPEED * delta
	var pixels := int(_fraction)
	_fraction -= pixels
	scroll.scroll_vertical += pixels
