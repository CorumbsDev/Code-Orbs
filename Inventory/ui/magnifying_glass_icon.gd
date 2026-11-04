class_name MagnifyingGlassIcon
extends Control
## Ícone vetorial de lupa (independente de fontes/emojis) para o botão do Inspecionador.

@export var icon_color: Color = Color(1.0, 0.97, 0.88, 1.0)
@export var handle_color: Color = Color(1.0, 0.88, 0.62, 1.0)
@export var glass_tint: Color = Color(0.38, 0.86, 1.0, 0.30)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var w := size.x if size.x > 4.0 else 44.0
	var h := size.y if size.y > 4.0 else 44.0
	var short_side := minf(w, h)
	var center := Vector2(w, h) * 0.5
	var r := clampf(short_side * 0.24, 6.0, 14.0)
	var lens_center := center + Vector2(-r * 0.28, -r * 0.28)
	var dir := Vector2(0.70710678, 0.70710678)
	var handle_start := lens_center + dir * (r + 1.0)
	var handle_end := lens_center + dir * (r * 2.15)
	var shadow_offset := Vector2(1.5, 1.8)
	var shadow_col := Color(0.0, 0.0, 0.0, 0.78)

	# 1. Sombra para contraste sobre o botão
	draw_line(handle_start + shadow_offset, handle_end + shadow_offset, shadow_col, 6.0, true)
	draw_circle(handle_end + shadow_offset, 3.0, shadow_col)
	draw_arc(lens_center + shadow_offset, r, 0.0, TAU, 32, shadow_col, 4.5, true)

	# 2. Cabo da lupa (contorno escuro + miolo claro)
	draw_line(handle_start, handle_end, Color(0.08, 0.06, 0.04, 0.95), 5.6, true)
	draw_circle(handle_end, 2.8, Color(0.08, 0.06, 0.04, 0.95))
	draw_line(handle_start, handle_end, handle_color, 3.4, true)
	draw_circle(handle_end, 1.7, handle_color)

	# 3. Vidro da lente e aro
	draw_circle(lens_center, maxf(r - 1.2, 2.0), glass_tint)
	draw_arc(lens_center, r, 0.0, TAU, 32, Color(0.08, 0.06, 0.04, 0.95), 4.4, true)
	draw_arc(lens_center, r, 0.0, TAU, 32, icon_color, 2.6, true)

	# 4. Brilho especular na lente
	if r >= 5.0:
		draw_arc(lens_center, r * 0.62, PI * 1.08, PI * 1.62, 14, Color(1.0, 1.0, 1.0, 0.85), 1.8, true)


static func make_inspect_button(on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.name = "BtnInspect"
	btn.text = ""
	btn.custom_minimum_size = Vector2(46, 46)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.tooltip_text = "Inspecionar orbe (ver binário, formato e efeitos)"
	var icon := MagnifyingGlassIcon.new()
	btn.add_child(icon)
	if on_pressed.is_valid():
		btn.pressed.connect(on_pressed)
	return btn

