class_name DoubleCylinderVisual
extends Node2D
## Cilindro representação visual
## Node2D (não Control): desenha de forma confiável como filho do Item.

var base_color := Color(1.0, 0.28, 0.82, 1.0)
var num_bytes: int = 8
var draw_size: Vector2 = Vector2(116, 40)

func _ready() -> void:
	z_index = 0
	queue_redraw()

func set_visual_props(color: Color, bytes: int, new_size: Vector2) -> void:
	base_color = color
	num_bytes = bytes
	draw_size = new_size
	queue_redraw()

func set_draw_size(new_size: Vector2) -> void:
	draw_size = new_size
	queue_redraw()

func _draw() -> void:
	var w := draw_size.x
	var h := draw_size.y
	if w < 8.0 or h < 8.0:
		return

	var is_white := base_color.r > 0.85 and base_color.g > 0.85 and base_color.b > 0.85
	var short_side := minf(w, h)

	var outer_glow: Color
	var rim_color: Color
	var inner_ring_color: Color
	var shadow_color: Color
	var mid_color: Color
	var core_color: Color

	if is_white:
		outer_glow = Color(0.90, 0.96, 1.0, 0.24)
		rim_color = Color(0.96, 0.98, 1.0, 1.0)
		inner_ring_color = Color(1.0, 1.0, 1.0, 0.92)
		shadow_color = Color(0.68, 0.75, 0.86, 0.98)
		mid_color = Color(0.88, 0.92, 0.98, 1.0)
		core_color = Color(1.0, 1.0, 1.0, 1.0)
	else:
		outer_glow = Color(base_color.r, base_color.g, base_color.b, 0.22)
		rim_color = base_color.lightened(0.18)
		rim_color.a = 1.0
		inner_ring_color = base_color.lightened(0.62)
		inner_ring_color.a = 0.82
		shadow_color = base_color.darkened(0.48)
		shadow_color.a = 0.96
		mid_color = base_color
		mid_color.a = 1.0
		core_color = base_color.lightened(0.45)
		core_color.a = 1.0

	# 1. Halo externo suave do orbe
	_draw_filled_stadium(Vector2.ZERO, Vector2(w + 4.0, h + 4.0), outer_glow)

	# 2. Borda externa e anel interno luminoso (estilo orb_int / orb_float)
	_draw_filled_stadium(Vector2.ZERO, Vector2(w, h), rim_color)
	var border_t := clampf(short_side * 0.055, 1.5, 3.0)
	var ring_size := Vector2(maxf(w - border_t * 2.0, 4.0), maxf(h - border_t * 2.0, 4.0))
	_draw_filled_stadium(Vector2.ZERO, ring_size, inner_ring_color)

	# 3. Corpo esférico base (sombra 3D na borda interna)
	var ring_t := clampf(short_side * 0.045, 1.0, 2.5)
	var body_size := Vector2(maxf(ring_size.x - ring_t * 2.0, 4.0), maxf(ring_size.y - ring_t * 2.0, 4.0))
	_draw_filled_stadium(Vector2.ZERO, body_size, shadow_color)

	# 4. Camadas concêntricas para volume esférico 3D (núcleo brilhante deslocado levemente ao topo-esquerdo)
	var layers := 7
	for i in range(layers):
		var t := float(i + 1) / float(layers)
		var scale_f := lerpf(0.92, 0.30, t)
		var layer_sz := Vector2(maxf(body_size.x * scale_f, 2.0), maxf(body_size.y * scale_f, 2.0))
		var light_shift := Vector2(-short_side * 0.06 * t, -short_side * 0.08 * t)
		var col: Color
		if t < 0.5:
			col = shadow_color.lerp(mid_color, t * 2.0)
		else:
			col = mid_color.lerp(core_color, (t - 0.5) * 2.0)
		_draw_filled_stadium(light_shift, layer_sz, col)

	# 5. Reflexo especular vítreo no topo do orbe
	var gloss_w := maxf(body_size.x - short_side * 0.38, short_side * 0.34)
	var gloss_h := clampf(short_side * 0.22, 3.0, 18.0)
	var gloss_pos := Vector2(0.0, -body_size.y * 0.28)
	_draw_filled_stadium(gloss_pos, Vector2(gloss_w, gloss_h), Color(1.0, 1.0, 1.0, 0.28))

	var shine_w := maxf(gloss_w * 0.45, short_side * 0.16)
	var shine_h := maxf(gloss_h * 0.52, 2.0)
	var shine_pos := gloss_pos + Vector2(- (gloss_w - shine_w) * 0.32, -gloss_h * 0.08)
	_draw_filled_stadium(shine_pos, Vector2(shine_w, shine_h), Color(1.0, 1.0, 1.0, 0.48))

	# 6. Contorno nítido do orbe
	_draw_stadium_outline(Vector2.ZERO, Vector2(w, h), rim_color.lightened(0.15), 1.8)


func _draw_filled_stadium(center: Vector2, sz: Vector2, color: Color) -> void:
	var pts := _stadium_points(center, sz)
	if pts.size() >= 3:
		draw_colored_polygon(pts, color)


func _draw_stadium_outline(center: Vector2, sz: Vector2, color: Color, width: float) -> void:
	var pts := _stadium_points(center, sz)
	if pts.size() >= 3:
		pts.append(pts[0])
		draw_polyline(pts, color, width, true)


func _stadium_points(center: Vector2, sz: Vector2, arc_steps: int = 24) -> PackedVector2Array:
	var w := maxf(sz.x, 2.0)
	var h := maxf(sz.y, 2.0)
	var r := minf(w, h) * 0.5
	var pts := PackedVector2Array()
	if w >= h:
		var dx := w * 0.5 - r
		var c_right := center + Vector2(dx, 0.0)
		var c_left := center + Vector2(-dx, 0.0)
		for i in range(arc_steps + 1):
			var a := -PI * 0.5 + PI * float(i) / float(arc_steps)
			pts.append(c_right + Vector2(cos(a) * r, sin(a) * r))
		for i in range(arc_steps + 1):
			var a := PI * 0.5 + PI * float(i) / float(arc_steps)
			pts.append(c_left + Vector2(cos(a) * r, sin(a) * r))
	else:
		var dy := h * 0.5 - r
		var c_bot := center + Vector2(0.0, dy)
		var c_top := center + Vector2(0.0, -dy)
		for i in range(arc_steps + 1):
			var a := PI * float(i) / float(arc_steps)
			pts.append(c_bot + Vector2(cos(a) * r, sin(a) * r))
		for i in range(arc_steps + 1):
			var a := PI + PI * float(i) / float(arc_steps)
			pts.append(c_top + Vector2(cos(a) * r, sin(a) * r))
	return pts

