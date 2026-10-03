class_name TextFxSpriteBlur
extends RefCounted
## 블러에 쓰는 글자만 별도 투명 여백과 mipmap을 갖는다.
## 아틀라스 전체 mipmap은 작은 레벨에서 이웃 글자를 섞으므로 셀을 분리한 뒤 생성한다.


static func isolate(sprite: Dictionary, images: Dictionary, radius: float) -> Dictionary:
	var region: Rect2 = sprite["region"]
	var padding := ceili(radius * 2.0) + 4
	var extent := Vector2i(region.size) + Vector2i.ONE * padding * 2
	var result := {
		"region": Rect2(Vector2.ZERO, Vector2(extent)),
		"center": (sprite["center"] as Vector2) - region.position + Vector2.ONE * padding,
		"inner": sprite["inner"], "scale": sprite["scale"],
	}
	for key in ["texture", "texture_front", "texture_glow"]:
		var source: Image = images.get(key)
		if source == null:
			result[key] = null
			continue
		var isolated := padded_cell(source, Rect2i(region), padding)
		result[key] = ImageTexture.create_from_image(isolated)
	return result


static func padded_cell(source: Image, region: Rect2i, padding: int) -> Image:
	var extent := region.size + Vector2i.ONE * padding * 2
	var isolated := Image.create(extent.x, extent.y, false, source.get_format())
	isolated.fill(Color(0, 0, 0, 0))
	isolated.blit_rect(source, region, Vector2i(padding, padding))
	isolated.generate_mipmaps()
	return isolated
