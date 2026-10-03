// 시간은 evaluator가 전달한다. TIME·프레임 누적값 없이 되감기와 캡처를 재현한다.
uniform int cine_mode = 0;
uniform float cine_hidden = 0.0;
uniform float cine_progress = 0.0;
uniform float cine_seed = 0.0;
uniform float cine_intensity = 1.0;
uniform float cine_detail = 8.0;
uniform float cine_distance = 1.2;
uniform vec4 cine_color : source_color = vec4(1.0);
uniform vec4 glyph_rect = vec4(0.0, 0.0, 1.0, 1.0);

float cine_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + cine_seed * 17.1) * 43758.5453);
}

float cine_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cine_hash(cell), cine_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(cine_hash(cell + vec2(0.0, 1.0)), cine_hash(cell + vec2(1.0)), f.x), f.y);
}

vec2 cine_local(vec2 uv) {
	return (uv - glyph_rect.xy) / max(vec2(0.00001), glyph_rect.zw - glyph_rect.xy);
}

vec2 cine_uv(vec2 uv) {
	vec2 q = cine_local(uv);
	vec2 span = glyph_rect.zw - glyph_rect.xy;
	float k = cine_hidden;
	if (cine_mode == 4) {
		// 모인 방울의 표면장력: 가로/세로가 다른 위상으로 출렁인다.
		vec2 wave = vec2(sin(q.y * 12.0 + cine_progress * 10.0 + cine_seed),
			cos(q.x * 11.0 - cine_progress * 8.0 + cine_seed));
		uv += wave * span * k * (1.0 - k * 0.5) * 0.09 * cine_intensity;
	} else if (cine_mode == 7) {
		// 글자 중심에서 막을 밀어내는 방사형 굴절과 감쇠하는 잔물결.
		vec2 p = q - vec2(0.5);
		float r = length(p);
		float pressure = sin((1.0 - k) * 3.14159265);
		float wave = sin(r * 23.0 - cine_progress * 9.0) * 0.025 * k;
		uv += p * span * (exp(-r * r * 5.0) * pressure * 0.28 + wave) * cine_intensity;
	} else if (cine_mode == 3) {
		uv.x += sin(q.y * cine_detail * 3.6 + cine_seed) * span.x * k * 0.028 * cine_intensity;
	}
	return uv;
}

vec4 cine_surface(vec4 c, vec2 uv) {
	if (cine_mode == 0 || cine_hidden <= 0.00001) {
		return c;
	}
	vec2 q = cine_local(uv);
	float k = cine_hidden;
	float p = 1.0 - k;
	float noise = cine_noise(q * max(2.0, cine_detail));
	float alpha = 1.0;
	float edge = 0.0;
	float amount = max(0.1, cine_intensity);
	if (cine_mode == 1) {
		// 여러 잉크 핵에서 섬유를 타고 스며드는 불규칙한 농담.
		float fibers = cine_noise(q * vec2(38.0, 11.0)) * 0.13 * amount;
		float field = clamp(length((q - vec2(0.46, 0.56)) * vec2(0.9, 0.7)) / (0.7 + cine_distance * 0.3) + noise * 0.3 + fibers, 0.0, 1.0);
		float boundary = p * 1.45;
		alpha = 1.0 - smoothstep(boundary - 0.06, boundary + 0.035, field);
		edge = (1.0 - smoothstep(0.0, 0.14, abs(field - boundary))) * k;
		c.rgb = mix(c.rgb, cine_color.rgb * c.a, edge * 0.8);
	} else if (cine_mode == 2) {
		float field = clamp((1.0 - q.y) * 0.65 + noise * 0.35, 0.0, 1.0);
		alpha = smoothstep(k - 0.045, k + 0.025, field);
		edge = (1.0 - smoothstep(0.0, 0.1, abs(field - k))) * sin(p * 3.14159265);
		c.rgb = mix(c.rgb, cine_color.rgb * c.a, edge);
		c.rgb = mix(c.rgb, vec3(c.a), edge * edge * 0.6);
	} else if (cine_mode == 3) {
		float jagged = sin(q.y * cine_detail * 3.6 + cine_seed) * 0.027 * amount;
		float field = abs(q.x - 0.5 - jagged) * 2.0;
		alpha = 1.0 - smoothstep(p * 1.12 - 0.025, p * 1.12 + 0.015, field);
		edge = (1.0 - smoothstep(0.0, 0.09, abs(field - p * 1.12))) * sin(p * 3.14159265);
		c.rgb = mix(c.rgb, cine_color.rgb * c.a, edge);
	} else if (cine_mode == 4) {
		vec2 cell = floor(q * 3.0);
		vec2 center = vec2(cine_hash(cell), cine_hash(cell + vec2(9.0))) * 0.5 + 0.25;
		float drops = length(fract(q * 3.0) - center);
		alpha = 1.0 - smoothstep(p * 1.3 - 0.06, p * 1.3 + 0.03, drops + noise * 0.15);
		float highlight = pow(max(0.0, 1.0 - drops * 2.0), 6.0) * k;
		c.rgb = mix(c.rgb, cine_color.rgb * c.a, k * 0.45);
		c.rgb = mix(c.rgb, vec3(c.a), highlight * 0.5);
	} else if (cine_mode == 5) {
		vec2 crystal = q * max(2.0, cine_detail * 0.65);
		float facets = min(abs(fract(crystal.x + crystal.y * 0.577) - 0.5),
			abs(fract(crystal.x - crystal.y * 0.577) - 0.5));
		float field = clamp(q.y * 0.5 + noise * 0.3 + facets * 0.4, 0.0, 1.0);
		alpha = 1.0 - smoothstep(p * 1.2 - 0.045, p * 1.2 + 0.035, field);
		edge = (1.0 - smoothstep(0.015, 0.07, facets)) * sin(p * 3.14159265);
		c.rgb = mix(c.rgb, cine_color.rgb * c.a, k * 0.55 + edge * 0.4);
	} else if (cine_mode == 6) {
		float column = floor(q.x * cine_detail);
		float vertical = mod(column, 2.0) < 1.0 ? q.y : 1.0 - q.y;
		float field = (column + clamp(vertical, 0.0, 1.0)) / cine_detail;
		alpha = 1.0 - smoothstep(p - 0.025, p + 0.025, field);
		float seam = 1.0 - smoothstep(0.02, 0.1, abs(fract(q.x * cine_detail) - 0.5));
		edge = seam * (1.0 - smoothstep(0.0, 0.12, abs(field - p))) * k;
		c.rgb = mix(c.rgb, cine_color.rgb * c.a, edge);
	} else if (cine_mode == 7) {
		alpha = smoothstep(0.0, 0.75, p);
		float relief = sin((q.x + q.y) * 9.0 + cine_seed) * 0.5 + 0.5;
		c.rgb = mix(c.rgb, cine_color.rgb * c.a, k * 0.6);
		c.rgb = mix(c.rgb, vec3(c.a), relief * sin(p * 3.14159265) * 0.35);
	}
	return c * clamp(alpha, 0.0, 1.0);
}
