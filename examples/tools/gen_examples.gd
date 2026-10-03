extends SceneTree
## 예시 연출 JSON 생성기. examples/fx/ 아래 파일을 편집기 로직으로 다시 만든다.
##   godot --headless --path . --script res://examples/tools/gen_examples.gd
## 같은 정의면 항상 같은 파일이 나온다(tests/example_demo.gd 가 확인).

const Specs := preload("res://examples/tools/example_specs.gd")


func _initialize() -> void:
	var r: Dictionary = Specs.build_all()
	for e in r.errors:
		push_error(e)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Specs.OUT_DIR))
	for file in r.files:
		var path: String = Specs.OUT_DIR.path_join(file)
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_error("쓸 수 없음: %s" % path)
			r.errors.append(path)
			continue
		f.store_string(r.files[file])
		f.close()
		print("wrote %s (%d bytes)" % [path, r.files[file].to_utf8_buffer().size()])
	quit(1 if not r.errors.is_empty() else 0)
