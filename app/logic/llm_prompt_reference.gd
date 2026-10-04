extends RefCounted
## LLM 프롬프트 내보내기용 효과·순서·이징 참조 문장(영어). 런타임 구현(addons/text_fx/core)과 같은 동작을 엔진 비의존 용어로 설명한다.
## 기호: k = 숨김 정도(0 = 제자리, 1 = 완전히 숨김), kc = clamp(k, 0, 1), em = 글자 크기(px), H(a, b) = §해시의 [0,1) 값, S(a, b) = 2H - 1.

## 등장·퇴장 효과. 등장은 k = 1 - ease(p), 퇴장은 k = ease(p), p = 글자 구간 경과 / duration.
const ENTER := {
	"fade": "alpha *= 1 - kc.",
	"slide": "Moves along `dir` (up/down/left/right = direction of motion). pos += dirVec * distance*em * k * (enter: -1, exit: +1) so the glyph arrives moving in `dir` and leaves continuing in `dir`. alpha *= 1 - kc.",
	"zoom": "scale *= max(0, lerp(1, from_scale, k)); alpha *= 1 - kc.",
	"pop": "scale *= max(0, lerp(1, from_scale, k)); alpha *= clamp((1-k)*3, 0, 1). Meant for back_out easing (overshoot).",
	"drop": "Falls from above: pos.y += (enter: -distance*em, exit: +distance*em) * k; alpha *= clamp((1-k)*4, 0, 1). Meant for bounce_out easing.",
	"bounce": "Same motion as drop (falls from above and bounces with bounce_out easing).",
	"rise": "Rises from below: pos.y += (enter: +distance*em, exit: -distance*em) * k; vertical directional blur of radius blur*em*kc; alpha *= 1 - kc.",
	"blur": "Real (gaussian) blur of radius radius*em*kc; scale *= 1 + 0.1*kc; alpha *= 1 - kc.",
	"spin": "rotation += radians(angle) * k; scale *= lerp(1, 0.4, kc); alpha *= 1 - kc.",
	"converge": "Glyphs come together vertically: side = (mode alternate: even column -> -1 (from above), odd -> +1 (from below); mode role: main text -1, sub text +1). Horizontal text: pos.y += side*distance*em*k (vertical text: pos.x -= same). alpha *= 1 - kc.",
	"tracking": "Letter spacing collapses: pos.x += (pos.x - lineCenter.x) * spread * k (vertical text uses y). alpha *= 1 - kc.",
	"center_split": "Each glyph starts stacked near its line center: hidden = lineCenter + (S(i,202), S(i,203)) * jitter*em; pos = lerp(pos, hidden, k). alpha *= clamp((1-kc)*3, 0, 1). If overlap_hold > 0 (enter only) the stacked glyphs fade in over min(0.2, overlap_hold) s with scale 1.2 -> 1, wait, then spread out.",
	"scatter": "Glyph flies in from a seeded direction: ang = H(i,101)*2pi, r = distance*em*(0.6 + 0.4*H(i,102)); pos += (cos ang, sin ang) * r * k; rotation += radians(angle) * S(i,103) * k; alpha *= 1 - kc.",
	"wipe": "Per-glyph clip reveal: visible fraction = 1 - kc revealed from one side toward `dir` (exit wipes away continuing the same direction).",
	"typewriter": "Glyph is fully hidden until its moment, then appears instantly with a short pop: scale *= 1 + pop*kc. Usually duration 0 with a stagger.",
	"glitch": "Per-glyph digital noise at 24 steps/s (step = floor(local*24)): position jitter up to intensity*0.45*em*kc, RGB split (color_a / color_b offset copies) of intensity*0.08*em*kc, 3 horizontal slices shifted up to intensity*0.3*em*kc, random dropouts with probability kc*0.6.",
	"center_stamp": "Sequence (enter only): each main glyph is shown one at a time, large (big_scale x, or viewport_scale x the canvas short side when > 0), at the block anchor (canvas center when viewport_scale > 0) for hold_each s (space_pause extra per word gap); then pause s; then the whole sentence slams down from slam_scale x to 1x over the enter duration with the enter easing. impact_duration/impact_brightness/impact_shake(px) add a decaying flash and shake at landing. As an exit it scales up to slam_scale while fading.",
	"flip": "Card flip on one axis: axis horizontal (or auto on vertical text) -> scale.x *= max(0, 1-k), otherwise scale.y *= max(0, 1-k). alpha *= clamp((1-kc)*3, 0, 1).",
	"flicker": "Irregular blinking: step = floor(local*rate); visible when H(i+4101, step) >= kc; alpha *= visible ? 1 : min_alpha (0 when kc >= 0.999).",
	"erase": "Instant on/off at the glyph's moment (enter: shown when k <= 0.5, exit: hidden when k >= 0.5). Used with stagger to type or delete.",
	"slam": "BLOCK effect. Enter: for p < impact: q = p/impact, the whole block scales around the block center from from_scale to 1 with q^2, alpha ramps in (q*3), blur blur*em*(1-q). After impact: q = (p-impact)/(1-impact), decay = (1-q)^2, shared shake of shake*em*decay (32 steps/s), scale wobble 1 + sin(q*2pi*1.5)*0.04*decay, white brightness brightness*decay. Exit: block grows to from_scale with blur while fading.",
	"block_zoom": "BLOCK effect: the whole block scales around its center by max(0, lerp(1, from_scale, k)) (glyph positions scale too), alpha *= 1 - kc, blur blur*em*kc.",
	"emerge": "BLOCK effect: like block_zoom with from_scale < 1 (small and far away -> full size), no blur.",
	"shutter": "BLOCK effect: the whole block is squashed on one axis around its center: factor (1-k) on y (axis vertical) or x (axis horizontal). alpha *= clamp((1-kc)*2, 0, 1).",
	"flash": "BLOCK effect: alpha *= clamp((1-kc)*3, 0, 1); mix glyph color toward white by brightness*kc; multiply glow strength by 1 + glow*kc.",
	"block_wipe": "BLOCK effect: one canvas-space mask over the block rect (grown by 0.5em) reveals 1-kc of it from the side opposite to `dir` (left/right/up/down), with a soft edge feather*em. dir center: reveal from the center outward; on exit the center is erased first (inverted mask).",
	"block_glitch": "BLOCK effect: horizontal bands shared by all glyphs (slices bands over the block height), each band shifted by up to 0.25*em*strength at 24 steps/s, shared x jitter 0.06*em*strength, RGB split 0.065*em*strength, block-wide dropouts (alpha 0.1) with probability kc*0.8. strength = kc*intensity.",
	"text_morph": "Enter only. The segment's params.from_text is shown first in its own layout for readable_ratio of the enter time, then glyphs distort (intensity) and swap/move into the final text's layout. Final page count follows the final text.",
	"fragment_assemble": "Glyph surface is cut into `detail` shards that fly in from different directions (up to distance*em) and assemble; shards are tinted toward `color`. intensity scales the strength.",
	"ink_bleed": "An irregular ink edge (noise threshold) floods the strokes until the glyph is filled; slight scale 1 + 0.055*intensity*k; edge tinted `color`.",
	"ember_dissolve": "A burning edge consumes/reveals the glyph with `detail` embers floating upward (distance*em); edge glow `color`.",
	"dimensional_rift": "A glowing crack (color) opens across the glyph and widens to reveal it; distance*em offsets the halves.",
	"afterimage_overtake": "`detail` translucent after-images (color) overtake the glyph from distance*em and merge into the body.",
	"liquid_merge": "Droplets (detail) gather and merge into the glyph; the surface wobbles like liquid while k > 0; tint `color`.",
	"frost_crystal": "Angular crystals (detail) grow along the strokes revealing the glyph; frost tint `color`.",
	"thread_stitch": "A glowing thread with a needle tip (color) stitches the strokes; the glyph appears along the thread path.",
	"surface_pressure": "The glyph pushes out from under a membrane: refraction/bulge that settles; tint `color`.",
}

const CINEMATIC_IDS: PackedStringArray = ["fragment_assemble", "ink_bleed", "ember_dissolve", "dimensional_rift",
	"afterimage_overtake", "liquid_merge", "frost_crystal", "thread_stitch", "surface_pressure"]

const CINEMATIC_NOTE := "Special (material) effect: params intensity 0..3, detail 2..16, distance 0..5 em, color RGBA. Reproduce the look with a shader/particles; it must be a pure function of (seed, glyph index, time) so seeking backwards gives the same frame. alpha is 0 at k = 1 and multiplied by 1 - 0.12*k otherwise."

const BLOCK_NOTE := "BLOCK effects ignore order/stagger: every glyph of the page shares one clock and one transform around the page block center."

## 유지 효과. ht = 유지 구간 시작 후 경과 초(scope visible이면 페이지 시작 후). 목록 순서대로 중첩.
const HOLD := {
	"blink": "ph = fmod(ht, period)/period; hard ? alpha *= (ph < 0.5 ? 1 : min_alpha) : alpha *= lerp(min_alpha, 1, 0.5 + 0.5*cos(ph*2pi)).",
	"flicker": "step = floor(ht*rate); if H(step,1100) < 0.35: alpha *= lerp(min_alpha, 1, H(step,1101)*0.6). Same for all glyphs.",
	"shake": "pos += (noise1(i*2+1200, ht*frequency), noise1(i*2+1201, ht*frequency)) * amplitude px; noise1 = smoothstep-interpolated value noise of S() on integer lattice. Per glyph.",
	"wave": "ph = ht*speed - column/wavelength; off = amplitude*sin(ph*2pi); horizontal: pos.y -= off; vertical: pos.x += off.",
	"float": "pos.y += amplitude*sin(ht/period*2pi) for every glyph.",
	"pulse": "scale *= 1 + (scale-1)*(0.5 - 0.5*cos(ht/period*2pi)) per glyph.",
	"glitch": "In every `interval` window a burst of `duration` starts at a seeded offset (window*interval + H(window,1300)*(interval-duration)). During the burst: `slices` horizontal strips per glyph shifted up to intensity*0.22*em (45% of strips), RGB split ~intensity*0.05*em (color_a/color_b), small x jitter.",
	"color_cycle": "hue = fract(ht/period + column*spread); tint *= HSV(hue, saturation, 1).",
	"heartbeat": "Whole block scales around its center: ph = fract(ht/period); beat = b(ph, 0.12, 0.12) + 0.65*b(ph, 0.36, 0.13) with b = (d >= 1 ? 0 : (0.5+0.5*cos(d*pi))^2), d = |ph-c|/w; factor = 1 + (scale-1)*beat.",
	"glow_pulse": "Only the glow layer: glow strength *= lerp(min_strength, 1, 0.5 + 0.5*cos(ht/period*2pi)).",
	"block_shake": "step = floor(ht*frequency); every glyph moves by (S(step,4701), S(step,4702)) * amplitude px (shared).",
	"block_glitch": "Like glitch but bursts use H(window,4801) and the strips are canvas-space bands shared by all glyphs (see block_glitch enter effect).",
}

## 순서. 글자 지연 = rank * stagger(+ 구두점·행 쉼). 공백은 rank를 차지하지 않는다.
const ORDER := {
	"all": "every glyph at once (rank 0)",
	"forward": "reading order",
	"reverse": "reverse reading order",
	"line": "by line (stagger = time between lines)",
	"word": "by word",
	"center_out": "by distance from the line center, nearest first",
	"edges_in": "by distance from the line center, farthest first",
	"random": "seeded shuffle",
	"center_index": "from the middle index of the page outward",
	"edges_index": "from both ends of the page inward",
	"sweep": "each line starts line_stagger s after the previous; inside a line delay = (glyph center position ratio) * sweep_duration",
}

const EASING := """ease_in(kind, p): sine 1-cos(p*pi/2); quad p^2; cubic p^3; quart p^4; quint p^5; expo (p<=0 ? 0 : 2^(10p-10)); circ 1-sqrt(1-p^2);
  back (c+1)p^3 - c p^2 with c = 1.70158; elastic (p in (0,1)) -2^(10p-10)*sin((10p-10.75)*2pi/3); bounce 1 - bounce_out(1-p).
<kind>_in = ease_in(p); <kind>_out = 1 - ease_in(1-p); <kind>_in_out = p < 0.5 ? ease_in(2p)/2 : 1 - ease_in(2(1-p))/2. linear = p. p is clamped to 0..1 first.
bounce_out(p): n = 7.5625, d = 2.75; p < 1/d: n p^2; p < 2/d: n (p-1.5/d)^2 + 0.75; p < 2.5/d: n (p-2.25/d)^2 + 0.9375; else n (p-2.625/d)^2 + 0.984375."""

const HASH := """All randomness is a hash of integers (never a global RNG), so any frame can be evaluated directly:
  mix(h): h ^= h>>16; h = (h*0x85EBCA6B) & 0xFFFFFFFF; h ^= h>>13; h = (h*0xC2B2AE35) & 0xFFFFFFFF; h ^= h>>16
  hash3(seed, a, b) = mix(mix(mix(seed ^ 0x9E3779B9) ^ (a*0x27D4EB2F & 0xFFFFFFFF)) ^ (b*0x165667B1 & 0xFFFFFFFF) ^ 0x7F4A7C15)
  H(a, b) = hash3(seed, a, b) / 2^32  (0..1);  S(a, b) = 2*H(a, b) - 1  (-1..1)
Use 64-bit (or unsigned 32-bit) integer math. Exact bit-compatibility is optional; determinism is required."""

const DECORATION := {
	"underline": "line under the main text block (vertical text: left side)",
	"overline": "line above the main text block (vertical text: right side)",
	"band": "horizontal band behind the text",
	"side_lines": "two lines extending left and right of the block (vertical text: above/below)",
	"frame": "rectangle framing the main text",
	"brackets": "corner brackets around the block",
	"tape": "two striped tapes flowing in opposite directions",
	"box": "rounded filled box behind main + sub text",
	"bar": "short bar in front of the text",
	"lines": "parallel lines above and below",
}
