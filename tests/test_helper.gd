extends RefCounted
## 테스트 단언 도우미. run_all.gd가 테스트 파일마다 하나씩 만들어 `run(t)`에 넘긴다.
##
##   t.ok(cond, msg)            조건이 참이어야 함
##   t.eq(actual, expected, msg) 값이 같아야 함(Dictionary/Array는 깊은 비교)
##   t.ne(a, b, msg)            값이 달라야 함
##   t.near(a, b, eps, msg)     수치(float/Vector2/Color)가 eps 안에서 같아야 함
##   t.fail(msg)                즉시 실패 기록
##   t.log(msg)                 정보 출력(실패 아님)
## 단언은 실패해도 테스트를 멈추지 않고 기록만 한다.

var test_name := ""
var tree: SceneTree = null
var checks := 0
var failures: PackedStringArray = PackedStringArray()


func ok(cond: bool, msg: String = "") -> bool:
	checks += 1
	if not cond:
		failures.append(msg if msg != "" else "ok() failed")
	return cond


func eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	checks += 1
	if not _same(actual, expected):
		failures.append("%s: expected <%s> got <%s>" % [msg if msg != "" else "eq", str(expected), str(actual)])
		return false
	return true


func ne(a: Variant, b: Variant, msg: String = "") -> bool:
	checks += 1
	if _same(a, b):
		failures.append("%s: values should differ <%s>" % [msg if msg != "" else "ne", str(a)])
		return false
	return true


func near(a: Variant, b: Variant, eps: float = 0.001, msg: String = "") -> bool:
	checks += 1
	var good := false
	if (a is float or a is int) and (b is float or b is int):
		good = absf(float(a) - float(b)) <= eps
	elif a is Vector2 and b is Vector2:
		good = (a as Vector2).distance_to(b) <= eps
	elif a is Color and b is Color:
		var ca: Color = a
		var cb: Color = b
		good = absf(ca.r - cb.r) <= eps and absf(ca.g - cb.g) <= eps and absf(ca.b - cb.b) <= eps and absf(ca.a - cb.a) <= eps
	if not good:
		failures.append("%s: <%s> not within %s of <%s>" % [msg if msg != "" else "near", str(a), str(eps), str(b)])
	return good


func fail(msg: String) -> void:
	checks += 1
	failures.append(msg)


func log(msg: String) -> void:
	print("    [%s] %s" % [test_name, msg])


func passed() -> bool:
	return failures.is_empty()


static func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return float(a) == float(b)
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k in da:
			if not db.has(k) or not _same(da[k], db[k]):
				return false
		return true
	if a is Array and b is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i in aa.size():
			if not _same(aa[i], ab[i]):
				return false
		return true
	if typeof(a) != typeof(b):
		if (a is String or a is StringName) and (b is String or b is StringName):
			return str(a) == str(b)
		return false
	return a == b
