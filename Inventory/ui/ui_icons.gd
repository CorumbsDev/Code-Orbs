class_name UiIcons
extends RefCounted
## Gerador de ícones procedurais em ImageTexture (16x16), 100% independente de fontes do SO/emojis,
## garantindo renderização idêntica no Desktop, Android e Web (HTML5/WASM).

static var _cache: Dictionary = {}


static func get_icon(kind: String) -> ImageTexture:
	if _cache.has(kind):
		return _cache[kind] as ImageTexture
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fg := Color(0.98, 0.98, 1.0, 1.0)
	var accent := Color(1.0, 0.86, 0.42, 1.0)
	var shadow := Color(0.0, 0.0, 0.0, 0.75)

	match kind:
		"copy":
			_rect_outline(img, 2, 1, 9, 11, fg, shadow)
			_rect_fill(img, 5, 4, 9, 11, Color(0.18, 0.22, 0.30, 0.95))
			_rect_outline(img, 5, 4, 9, 11, fg, shadow)
		"paste":
			_rect_outline(img, 3, 3, 10, 12, fg, shadow)
			_rect_fill(img, 5, 1, 6, 3, accent)
			_hline(img, 5, 9, 7, fg)
			_hline(img, 5, 9, 10, fg)
		"qr":
			_rect_outline(img, 1, 1, 6, 6, fg, shadow)
			_rect_fill(img, 3, 3, 2, 2, fg)
			_rect_outline(img, 9, 1, 6, 6, fg, shadow)
			_rect_fill(img, 11, 3, 2, 2, fg)
			_rect_outline(img, 1, 9, 6, 6, fg, shadow)
			_rect_fill(img, 3, 11, 2, 2, fg)
			_rect_fill(img, 9, 9, 2, 2, fg)
			_rect_fill(img, 12, 11, 3, 3, fg)
		"camera":
			_rect_outline(img, 1, 4, 14, 10, fg, shadow)
			_rect_fill(img, 5, 2, 6, 2, fg)
			_rect_outline(img, 5, 6, 6, 6, accent, shadow)
		"save":
			_rect_outline(img, 2, 1, 12, 14, fg, shadow)
			_rect_fill(img, 5, 2, 6, 4, accent)
			_rect_fill(img, 4, 9, 8, 5, fg)
		"play":
			for x in range(4, 13):
				var half: int = int((12 - x) * 0.65)
				for y in range(8 - half, 8 + half + 1):
					_px(img, x + 1, y + 1, shadow)
					_px(img, x, y, Color(0.55, 1.0, 0.62, 1.0))
		"trash":
			_hline(img, 3, 12, 3, fg)
			_rect_fill(img, 6, 1, 4, 2, fg)
			_rect_outline(img, 4, 4, 8, 11, Color(1.0, 0.65, 0.65, 1.0), shadow)
			_vline(img, 6, 6, 12, fg)
			_vline(img, 9, 6, 12, fg)
		"up":
			for dy in range(0, 6):
				_hline(img, 8 - dy, 8 + dy, 2 + dy, fg)
			_rect_fill(img, 6, 8, 5, 6, fg)
		"down":
			_rect_fill(img, 6, 2, 5, 6, fg)
			for dy in range(0, 6):
				_hline(img, 3 + dy, 13 - dy, 8 + dy, fg)
		"folder":
			_rect_fill(img, 1, 3, 6, 2, accent)
			_rect_fill(img, 1, 5, 14, 9, accent)
			_rect_outline(img, 1, 5, 14, 9, fg, shadow)
		"file":
			_rect_fill(img, 3, 1, 10, 14, Color(0.22, 0.28, 0.38, 0.95))
			_rect_outline(img, 3, 1, 10, 14, fg, shadow)
			_hline(img, 5, 10, 5, fg)
			_hline(img, 5, 10, 8, fg)
			_hline(img, 5, 8, 11, fg)
		"lock":
			_rect_outline(img, 5, 2, 6, 5, fg, shadow)
			_rect_fill(img, 3, 7, 10, 8, accent)
			_rect_outline(img, 3, 7, 10, 8, fg, shadow)

	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < 16 and y >= 0 and y < 16:
		img.set_pixel(x, y, c)


static func _hline(img: Image, x0: int, x1: int, y: int, c: Color) -> void:
	for x in range(x0, x1 + 1):
		_px(img, x, y, c)


static func _vline(img: Image, x: int, y0: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		_px(img, x, y, c)


static func _rect_fill(img: Image, rx: int, ry: int, rw: int, rh: int, c: Color) -> void:
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			_px(img, x, y, c)


static func _rect_outline(img: Image, rx: int, ry: int, rw: int, rh: int, c: Color, sh: Color) -> void:
	_hline(img, rx + 1, rx + rw, ry + rh, sh)
	_vline(img, rx + rw, ry + 1, ry + rh, sh)
	_hline(img, rx, rx + rw - 1, ry, c)
	_hline(img, rx, rx + rw - 1, ry + rh - 1, c)
	_vline(img, rx, ry, ry + rh - 1, c)
	_vline(img, rx + rw - 1, ry, ry + rh - 1, c)

