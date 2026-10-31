extends Node2D
## Marca visual desenhada sobre um orbe que sofreu degradação de dados.
## Cada estado tem cor, forma de anel e símbolo próprios (sem depender de fontes/emojis):
##  - "precision": âmbar, anel tracejado e símbolo de aproximação (≈)
##  - "underflow": azul, anel contínuo e seta para baixo (valor colapsou para perto de zero)
##  - "overflow":  vermelho, anel grosso pulsante e seta para cima (valor estourou o limite)

const COLOR_PRECISION := Color(1.0, 0.72, 0.12, 1.0)
const COLOR_UNDERFLOW := Color(0.35, 0.72, 1.0, 1.0)
const COLOR_OVERFLOW := Color(1.0, 0.28, 0.22, 1.0)
const BADGE_BG := Color(0.07, 0.07, 0.1, 0.92)

var kind: String = ""
var _time: float = 0.0


func _ready() -> void:
	z_index = 20
	z_as_relative = true


func set_kind(new_kind: String) -> void:
	kind = new_kind
	visible = kind != ""
	queue_redraw()


func _process(delta: float) -> void:
	if kind == "":
		return
	_time += delta
	queue_redraw()


func _kind_color() -> Color:
	match kind:
		"overflow":
			return COLOR_OVERFLOW
		"underflow":
			return COLOR_UNDERFLOW
		_:
			return COLOR_PRECISION


func _orb_rect() -> Rect2:
	var p := get_parent()
	if p != null and p.has_method("get_item_rect"):
		return p.get_item_rect()
	return Rect2(Vector2(-32, -32), Vector2(64, 64))


func _draw() -> void:
	if kind == "":
		return
	var rect := _orb_rect()
	var center := rect.position + rect.size * 0.5
	var radius := maxf(minf(rect.size.x, rect.size.y) * 0.5, 22.0) + 2.0
	var col := _kind_color()

	match kind:
		"precision":
			_draw_dashed_ring(center, radius, col, 2.5)
		"underflow":
			draw_arc(center, radius, 0.0, TAU, 40, col, 3.0, true)
		"overflow":
			var pulse := 0.65 + 0.35 * sin(_time * 7.0)
			var c := Color(col.r, col.g, col.b, pulse)
			draw_arc(center, radius, 0.0, TAU, 40, c, 4.5, true)

	# Selo no canto superior direito do orbe.
	var bpos := center + Vector2(radius * 0.72, -radius * 0.72)
	draw_circle(bpos, 11.0, BADGE_BG)
	draw_arc(bpos, 11.0, 0.0, TAU, 24, col, 2.0, true)
	match kind:
		"precision":
			_draw_wave(bpos + Vector2(0, -2.5), col)
			_draw_wave(bpos + Vector2(0, 2.5), col)
		"underflow":
			_draw_arrow(bpos, false, col)
		"overflow":
			_draw_arrow(bpos, true, col)


func _draw_dashed_ring(center: Vector2, radius: float, col: Color, width: float) -> void:
	var dashes := 16
	var step := TAU / float(dashes)
	for i in range(dashes):
		var a0 := step * float(i)
		draw_arc(center, radius, a0, a0 + step * 0.55, 6, col, width, true)


func _draw_wave(origin: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(9):
		var t := float(i) / 8.0
		pts.append(origin + Vector2(-6.0 + 12.0 * t, sin(t * TAU) * 1.8))
	draw_polyline(pts, col, 1.6, true)


func _draw_arrow(origin: Vector2, up: bool, col: Color) -> void:
	var s := -1.0 if up else 1.0
	# Haste
	draw_line(origin + Vector2(0, -5.5 * s), origin + Vector2(0, 1.5 * s), col, 2.2)
	# Ponta
	var tip := origin + Vector2(0, 6.0 * s)
	var pts := PackedVector2Array([tip, origin + Vector2(-4.5, 1.0 * s), origin + Vector2(4.5, 1.0 * s)])
	draw_colored_polygon(pts, col)
