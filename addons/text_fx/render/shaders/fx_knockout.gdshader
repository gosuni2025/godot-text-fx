// 뒤 레이어(글로우·그림자·테두리)에서 채우기 모양을 지운다: dst *= (1 - 채우기 커버리지).
// 앞 레이어(채우기)와 합치면 원래 합성 결과가 되고, 페이드 중에도 테두리가 채우기 아래로 비치지 않는다.
shader_type canvas_item;
render_mode blend_mul, unshaded;

void fragment() {
	COLOR = vec4(1.0 - COLOR.a);
}
