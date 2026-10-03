class_name TextFxGlyphBaker
extends Node
## 스타일을 모두 입힌 글자 스프라이트를 SubViewport 아틀라스에 굽는다(DESIGN §4).
##   1) 실루엣 뷰포트: 가장 바깥 테두리까지의 흰 실루엣
##   2) 가로 블러 뷰포트: R = 그림자 반경, G = 글로우 반경으로 흐린 값
##   3) 합성: 뒤 아틀라스 = 세로 블러 글로우 → 그림자 → 2차 테두리 → 테두리, 그 위에서 채우기 모양을 지움(knockout)
##            앞 아틀라스 = 채우기(단색 또는 그라데이션 셰이더)
##      플레이어는 모든 글자의 뒤 레이어를 먼저, 앞 레이어를 나중에 그린다. 이웃 글자의 테두리가 채우기를 가리지 않고,
##      한 글자 안에서는 테두리가 채우기 아래에서 지워져 있어 페이드 중에도 비치지 않는다.
## 단계마다 UPDATE_ONCE 한 프레임씩 렌더한 뒤 이미지로 읽어 ImageTexture로 바꾸고 뷰포트는 해제한다.
## 결과 텍스처는 투명 렌더 타깃이라 프리멀티플라이드 알파다(플레이어는 PREMULT_ALPHA 블렌드로 그린다).
##
## bake(jobs) (await) → { key: { texture(뒤), texture_front(앞), region(Rect2), center(Vector2), inner(Rect2, center 기준), scale } }
## job = { id, font: Font, style: Dictionary(정규화 스타일, 캔버스 px), scale: float(스타일 px 배율),
##         gradient: bool, entries: [{ key, char, size_px, grad_a: Vector2, grad_b: float }] }
## 헤드리스(더미 렌더러)에서는 빈 결과를 돌려준다.

const Doc := preload("res://addons/text_fx/core/fx_doc.gd")
const BLUR_H := preload("res://addons/text_fx/render/shaders/fx_blur_h.gdshader")
const BLUR_V := preload("res://addons/text_fx/render/shaders/fx_blur_v.gdshader")
const GRADIENT := preload("res://addons/text_fx/render/shaders/fx_gradient_fill.gdshader")
const KNOCKOUT := preload("res://addons/text_fx/render/shaders/fx_knockout.gdshader")

const MAX_ATLAS := 4096
const ATLAS_WIDTH := 2048
const GUTTER := 2
## draw_char_outline의 size는 실측상 바깥 두께의 약 4배다(size 32 → 한쪽 약 8px). 문서의 size(px)에 이 배율을 곱해 넘긴다.
const OUTLINE_FACTOR := 4.0
const MAX_BLUR := 64.0


static func can_bake() -> bool:
	return DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_driver_name() != "dummy"


func bake(jobs: Array) -> Dictionary:
	var result := {}
	if not can_bake() or not is_inside_tree():
		return result
	var pages: Array = []
	for job in jobs:
		pages.append_array(_layout_job(job))
	if pages.is_empty():
		return result
	for pg in pages:
		_build_page(pg)
	# 1) 실루엣
	var any_blur := false
	for pg in pages:
		if pg["sil"] != null:
			any_blur = true
			(pg["sil"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	if any_blur:
		await RenderingServer.frame_post_draw
		# 2) 가로 블러
		for pg in pages:
			if pg["bh"] != null:
				(pg["bh"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	# 3) 합성
	for pg in pages:
		(pg["comp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		(pg["front"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	for pg in pages:
		var tex: Texture2D = null
		if pg["has_back"]:
			var img: Image = (pg["comp"] as SubViewport).get_texture().get_image()
			tex = ImageTexture.create_from_image(img) if img else null
		var img_f: Image = (pg["front"] as SubViewport).get_texture().get_image()
		var tex_f: Texture2D = ImageTexture.create_from_image(img_f) if img_f else null
		for cell in pg["cells"]:
			result[cell["key"]] = {
				"texture": tex, "texture_front": tex_f, "region": cell["region"], "center": cell["center"],
				"inner": cell["inner"], "scale": pg["scale"],
			}
		for k in ["sil", "bh", "comp", "front"]:
			if pg[k] != null:
				(pg[k] as Node).queue_free()
	return result


## 셀 배치(선반 방식). 아틀라스가 MAX_ATLAS를 넘으면 페이지를 나눈다.
func _layout_job(job: Dictionary) -> Array:
	var font: Font = job["font"]
	var style: Dictionary = job["style"]
	var sc := float(job["scale"])
	var ol := _px(style["outline"], "size", sc)
	var ol2 := _px(style["outline2"], "size", sc)
	var glow_r := minf(MAX_BLUR, _px(style["glow"], "size", sc))
	var sh: Dictionary = style["shadow"]
	var sh_on: bool = sh["enabled"]
	var sh_off := Vector2(float(sh["offset"][0]), float(sh["offset"][1])) * sc if sh_on else Vector2.ZERO
	var sh_r := minf(MAX_BLUR, float(sh["blur"]) * sc) if sh_on else 0.0
	var ext := 0.0
	if glow_r > 0.0:
		ext = maxf(ext, glow_r * 1.2)
	if sh_on:
		ext = maxf(ext, maxf(absf(sh_off.x), absf(sh_off.y)) + sh_r * 1.2)
	var pad := int(ceil(ol + ol2 + ext)) + 3
	var pages: Array = []
	var page := _new_page(job, ol, ol2, glow_r, sh_on, sh_off, sh_r)
	var x := GUTTER
	var y := GUTTER
	var row_h := 0
	var seen := {}
	for e in job["entries"]:
		var key: String = e["key"]
		if seen.has(key):
			continue
		seen[key] = true
		var size := maxi(1, int(e["size_px"]))
		var c := _code(str(e["char"]))
		var box := Vector2(font.get_char_size(c, size).x, font.get_ascent(size) + font.get_descent(size))
		var cw := int(ceil(box.x)) + pad * 2
		var chh := int(ceil(box.y)) + pad * 2
		if x + cw + GUTTER > ATLAS_WIDTH and x > GUTTER:
			x = GUTTER
			y += row_h + GUTTER
			row_h = 0
		if y + chh + GUTTER > MAX_ATLAS and not page["cells"].is_empty():
			page["size"] = Vector2i(ATLAS_WIDTH, y + row_h + GUTTER)
			pages.append(page)
			page = _new_page(job, ol, ol2, glow_r, sh_on, sh_off, sh_r)
			x = GUTTER
			y = GUTTER
			row_h = 0
		var origin := Vector2(x, y)
		var center := origin + Vector2(pad, pad) + box * 0.5
		var olt := ol + ol2
		page["cells"].append({
			"key": key, "char": str(e["char"]), "size": size, "box": box, "ascent": font.get_ascent(size),
			"region": Rect2(origin, Vector2(cw, chh)), "center": center,
			"inner": Rect2(-box * 0.5 - Vector2(olt, olt), box + Vector2(olt, olt) * 2.0),
			"grad_a": e.get("grad_a", Vector2.ZERO), "grad_b": float(e.get("grad_b", 0.0)),
		})
		x += cw + GUTTER
		row_h = maxi(row_h, chh)
	if not page["cells"].is_empty():
		var w := ATLAS_WIDTH
		if y == GUTTER:
			w = x + GUTTER
		page["size"] = Vector2i(mini(w, MAX_ATLAS), mini(y + row_h + GUTTER, MAX_ATLAS))
		pages.append(page)
	return pages


static func _code(c: String) -> int:
	return c.unicode_at(0) if c.length() > 0 else 32


func _new_page(job: Dictionary, ol: float, ol2: float, glow_r: float, sh_on: bool, sh_off: Vector2, sh_r: float) -> Dictionary:
	return {"job": job, "cells": [], "ol": ol, "ol2": ol2, "glow_r": glow_r, "sh_on": sh_on, "sh_off": sh_off, "sh_r": sh_r,
		"scale": float(job["scale"]), "sil": null, "bh": null, "comp": null, "front": null, "has_back": false}


static func _px(d: Dictionary, k: String, sc: float) -> float:
	return float(d[k]) * sc if bool(d.get("enabled", true)) else 0.0


func _make_vp(size: Vector2i, transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.disable_3d = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(vp)
	return vp


func _build_page(pg: Dictionary) -> void:
	var job: Dictionary = pg["job"]
	var style: Dictionary = job["style"]
	var font: Font = job["font"]
	var size: Vector2i = pg["size"]
	var glow_on: bool = bool(style["glow"]["enabled"]) and float(style["glow"]["strength"]) > 0.0
	var need_blur: bool = glow_on or bool(pg["sh_on"])
	var outer := float(pg["ol"]) + float(pg["ol2"])
	var bh_tex: Texture2D = null
	if need_blur:
		var sil := _make_vp(size, true)
		var sil_draw := Node2D.new()
		sil.add_child(sil_draw)
		sil_draw.draw.connect(func() -> void:
			for cell in pg["cells"]:
				var base := _baseline(cell)
				if outer > 0.0:
					sil_draw.draw_char_outline(font, base, cell["char"], cell["size"], int(round(outer * OUTLINE_FACTOR)), Color.WHITE)
				sil_draw.draw_char(font, base, cell["char"], cell["size"], Color.WHITE))
		var bh := _make_vp(size, false)
		var bh_rect := TextureRect.new()
		bh_rect.texture = sil.get_texture()
		bh_rect.size = Vector2(size)
		bh_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mh := ShaderMaterial.new()
		mh.shader = BLUR_H
		mh.set_shader_parameter("r_r", float(pg["sh_r"]))
		mh.set_shader_parameter("r_g", float(pg["glow_r"]))
		bh_rect.material = mh
		bh.add_child(bh_rect)
		pg["sil"] = sil
		pg["bh"] = bh
		bh_tex = bh.get_texture()
	var comp := _make_vp(size, true)
	pg["comp"] = comp
	if glow_on:
		var gl: Dictionary = style["glow"]
		comp.add_child(_blur_layer(bh_tex, size, 1, float(pg["glow_r"]), Doc.parse_color(gl["color"]), float(gl["strength"]), Vector2.ZERO))
	if pg["sh_on"]:
		comp.add_child(_blur_layer(bh_tex, size, 0, float(pg["sh_r"]), Doc.parse_color(style["shadow"]["color"]), 1.0, pg["sh_off"]))
	var ol_draw := Node2D.new()
	comp.add_child(ol_draw)
	var ol := float(pg["ol"])
	var ol2 := float(pg["ol2"])
	var ol_col := Doc.parse_color(style["outline"]["color"])
	var ol2_col := Doc.parse_color(style["outline2"]["color"])
	ol_draw.draw.connect(func() -> void:
		for cell in pg["cells"]:
			var base := _baseline(cell)
			if ol2 > 0.0:
				ol_draw.draw_char_outline(font, base, cell["char"], cell["size"], int(round((ol + ol2) * OUTLINE_FACTOR)), ol2_col)
			if ol > 0.0:
				ol_draw.draw_char_outline(font, base, cell["char"], cell["size"], int(round(ol * OUTLINE_FACTOR)), ol_col))
	var ko := Node2D.new()
	var ko_mat := ShaderMaterial.new()
	ko_mat.shader = KNOCKOUT
	ko.material = ko_mat
	comp.add_child(ko)
	ko.draw.connect(func() -> void:
		for cell in pg["cells"]:
			ko.draw_char(font, _baseline(cell), cell["char"], cell["size"], Color.WHITE))
	pg["has_back"] = glow_on or bool(pg["sh_on"]) or ol > 0.0 or ol2 > 0.0
	var front := _make_vp(size, true)
	pg["front"] = front
	var fill: Dictionary = style["fill"]
	if fill["type"] == "gradient" and bool(job.get("gradient", false)):
		var stops := _stops_texture(fill["gradient"]["stops"])
		for cell in pg["cells"]:
			var n := Node2D.new()
			n.position = cell["center"]
			var m := ShaderMaterial.new()
			m.shader = GRADIENT
			m.set_shader_parameter("stops", stops)
			m.set_shader_parameter("g_a", cell["grad_a"])
			m.set_shader_parameter("g_b", cell["grad_b"])
			n.material = m
			var box: Vector2 = cell["box"]
			var local_base := Vector2(-box.x * 0.5, -box.y * 0.5 + float(cell["ascent"]))
			n.draw.connect(func() -> void: n.draw_char(font, local_base, cell["char"], cell["size"], Color.WHITE))
			front.add_child(n)
	else:
		var fill_col := Doc.parse_color(fill["color"])
		var fill_draw := Node2D.new()
		front.add_child(fill_draw)
		fill_draw.draw.connect(func() -> void:
			for cell in pg["cells"]:
				fill_draw.draw_char(font, _baseline(cell), cell["char"], cell["size"], fill_col))


static func _baseline(cell: Dictionary) -> Vector2:
	var box: Vector2 = cell["box"]
	var c: Vector2 = cell["center"]
	return Vector2(c.x - box.x * 0.5, c.y - box.y * 0.5 + float(cell["ascent"]))


func _blur_layer(tex: Texture2D, size: Vector2i, channel: int, radius: float, color: Color, strength: float, offset: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.size = Vector2(size)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = BLUR_V
	m.set_shader_parameter("channel", channel)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("offset_px", offset)
	r.material = m
	return r


static func _stops_texture(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	var sorted := stops.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for s in sorted:
		offsets.append(float(s[0]))
		colors.append(Doc.parse_color(s[1]))
	if offsets.is_empty():
		offsets = PackedFloat32Array([0.0, 1.0])
		colors = PackedColorArray([Color.WHITE, Color.WHITE])
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t
