class_name TextFxHash
extends RefCounted
## 결정적 해시 난수. 전역 난수(randf 등)를 쓰지 않고 시드·글자 번호·시간 단계에서 값을 만든다.
## 32비트 정수 혼합(murmur3 fmix32 계열)을 사용한다.

const MASK32 := 0xFFFFFFFF
const INV_2_32 := 1.0 / 4294967296.0


static func mix(h: int) -> int:
	h &= MASK32
	h ^= h >> 16
	h = (h * 0x85EBCA6B) & MASK32
	h ^= h >> 13
	h = (h * 0xC2B2AE35) & MASK32
	h ^= h >> 16
	return h


## (seed, a, b) → 32비트 부호 없는 정수.
static func hash3(seed: int, a: int, b: int = 0) -> int:
	var h := mix((seed & MASK32) ^ 0x9E3779B9)
	h = mix(h ^ ((a * 0x27D4EB2F) & MASK32))
	h = mix(h ^ ((b * 0x165667B1) & MASK32) ^ 0x7F4A7C15)
	return h


## [0, 1) 실수.
static func f(seed: int, a: int, b: int = 0) -> float:
	return float(hash3(seed, a, b)) * INV_2_32


## [-1, 1) 실수.
static func signed(seed: int, a: int, b: int = 0) -> float:
	return f(seed, a, b) * 2.0 - 1.0


static func range_f(seed: int, a: int, b: int, lo: float, hi: float) -> float:
	return lerpf(lo, hi, f(seed, a, b))


## 1차원 값 노이즈 [-1, 1]. x의 정수 격자마다 해시 값을 두고 smoothstep으로 잇는다.
static func noise1(seed: int, a: int, x: float) -> float:
	var i := int(floor(x))
	var u := x - float(i)
	u = u * u * (3.0 - 2.0 * u)
	return lerpf(signed(seed, a, i), signed(seed, a, i + 1), u)


## 0..n-1 의 결정적 순열.
static func permutation(seed: int, n: int, salt: int = 0) -> PackedInt32Array:
	var keys: Array = []
	for i in n:
		keys.append([hash3(seed, i, salt), i])
	keys.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var out := PackedInt32Array()
	for k in keys:
		out.append(k[1])
	return out
