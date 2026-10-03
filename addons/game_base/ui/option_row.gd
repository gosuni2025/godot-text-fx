extends HBoxContainer
signal edited(id: StringName, value: Variant)
var definition: Resource

func bind(entry: Resource, value: Variant) -> void:
	definition = entry
	$Caption.text = tr(entry.category) + " · " + tr(entry.label)
	$Toggle.visible = entry.kind == 0
	$Range.visible = entry.kind == 1
	$Choice.visible = entry.kind == 2
	match entry.kind:
		0:
			$Toggle.set_pressed_no_signal(value)
			$Toggle.toggled.connect(func(v): edited.emit(entry.id, v))
		1:
			$Range/Slider.min_value = entry.minimum
			$Range/Slider.max_value = entry.maximum
			$Range/Slider.step = entry.step
			$Range/Slider.set_value_no_signal(value)
			$Range/Value.text = str(value)
			$Range/Slider.value_changed.connect(func(v):
				$Range/Value.text = str(snappedf(v, entry.step))
				edited.emit(entry.id, v))
		2:
			for label_text in entry.choice_labels: $Choice.add_item(tr(label_text))
			$Choice.select(entry.choices.find(value))
			$Choice.item_selected.connect(func(i): edited.emit(entry.id, entry.choices[i]))

func focus_control() -> Control:
	return [$Toggle, $Range/Slider, $Choice][definition.kind]
