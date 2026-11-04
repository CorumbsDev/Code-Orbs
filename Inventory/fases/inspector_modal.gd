extends CanvasLayer
## Inspecionador visual de Orbes:
## - Representa os bits como pequenos orbes com formas e cores distintas para Sinal, Expoente, Mantissa e Byte.
## - Diagnostica e explica os efeitos de Overflow, Underflow e Aproximação (Perda de Precisão / Truncamento).

const COLOR_SIGN := Color(0.98, 0.28, 0.34, 1.0)     # Vermelho Coral — Sinal (Losango)
const COLOR_EXP := Color(0.18, 0.86, 0.48, 1.0)      # Verde Esmeralda — Expoente (Hexágono)
const COLOR_MANT := Color(1.0, 0.76, 0.18, 1.0)      # Âmbar Dourado — Mantissa (Triângulo)
const COLOR_BYTE := Color(0.64, 0.44, 0.98, 1.0)      # Roxo — Magnitude / Bits de Byte (Octógono)
const COLOR_BYTE_BORDER := Color(0.96, 0.76, 0.26, 0.85) # Moldura Âmbar — Agrupamento de 1 Byte (8 bits)

const COLOR_OVERFLOW := Color(1.0, 0.28, 0.22, 1.0)
const COLOR_UNDERFLOW := Color(0.35, 0.72, 1.0, 1.0)
const COLOR_PRECISION := Color(1.0, 0.72, 0.12, 1.0)
const COLOR_EXACT := Color(0.26, 0.90, 0.52, 1.0)

var config = null
var current_item: Node = null

var _root: Control = null
var _title_lbl: Label = null
var _orb_preview: OrbMiniPreview = null
var _summary_rt: RichTextLabel = null
var _status_badge_panel: PanelContainer = null
var _status_badge_lbl: Label = null
var _legend_hbox: HFlowContainer = null
var _bytes_flow: HFlowContainer = null
var _formula_rt: RichTextLabel = null

var insp_config_panel: PanelContainer = null
var spin_fp8_exp: SpinBox = null
var spin_fp8_mant: SpinBox = null
var spin_fp16_exp: SpinBox = null
var spin_fp16_mant: SpinBox = null

var _effects_container: VBoxContainer = null
var _active_effect_banner: PanelContainer = null
var _active_effect_icon: EffectBadgeControl = null
var _active_effect_rt: RichTextLabel = null

var _card_overflow: PanelContainer = null
var _card_underflow: PanelContainer = null
var _card_precision: PanelContainer = null
var _tag_overflow: Label = null
var _tag_underflow: Label = null
var _tag_precision: Label = null


## Orbe individual de 1 bit com forma geométrica e cor de acordo com seu papel no dado binário.
class BitOrbShapeControl extends Control:
	var bit_char: String = "0"
	var role: String = "mant" # "sign" | "exp" | "mant" | "byte"
	var orb_size: float = 34.0
	var _lbl: Label = null

	func _init(p_bit: String, p_role: String, p_size: float = 34.0, p_tooltip: String = "") -> void:
		bit_char = p_bit
		role = p_role
		orb_size = p_size
		custom_minimum_size = Vector2(orb_size, orb_size)
		size = Vector2(orb_size, orb_size)
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = p_tooltip

		_lbl = Label.new()
		_lbl.text = bit_char
		_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if role == "mant":
			_lbl.offset_top = 2.0
		_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fs := 14 if orb_size >= 30.0 else 11
		_lbl.add_theme_font_size_override("font_size", fs)
		_lbl.add_theme_color_override("font_color", Color.WHITE if bit_char == "1" else Color(0.84, 0.88, 0.94, 0.92))
		_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		_lbl.add_theme_constant_override("outline_size", 3 if orb_size >= 30.0 else 2)
		add_child(_lbl)

	func _role_color() -> Color:
		match role:
			"sign":
				return COLOR_SIGN
			"exp":
				return COLOR_EXP
			"mant":
				return COLOR_MANT
			_:
				return COLOR_BYTE

	func _shape_points(center: Vector2, radius: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		match role:
			"sign":
				# Losango (Diamond) — Bit de Sinal
				pts.append(center + Vector2(0.0, -radius * 1.06))
				pts.append(center + Vector2(radius * 1.06, 0.0))
				pts.append(center + Vector2(0.0, radius * 1.06))
				pts.append(center + Vector2(-radius * 1.06, 0.0))
			"exp":
				# Hexágono (Hexagon) — Bits de Expoente
				for i in range(6):
					var a := -PI * 0.5 + TAU * float(i) / 6.0
					pts.append(center + Vector2(cos(a), sin(a)) * (radius * 1.02))
			"mant":
				# Triângulo Dourado (Triangle) — Bits de Mantissa
				pts.append(center + Vector2(0.0, -radius * 1.15))
				pts.append(center + Vector2(radius * 1.05, radius * 0.85))
				pts.append(center + Vector2(-radius * 1.05, radius * 0.85))
			_:
				# Octógono (Octagon) — Byte / Magnitude Inteira
				for i in range(8):
					var a := PI * 0.125 + TAU * float(i) / 8.0
					pts.append(center + Vector2(cos(a), sin(a)) * (radius * 1.02))
		return pts

	func _draw() -> void:
		var w := size.x if size.x > 4.0 else orb_size
		var h := size.y if size.y > 4.0 else orb_size
		var center := Vector2(w, h) * 0.5
		var radius := minf(w, h) * 0.43
		var is_one := bit_char == "1"
		var base := _role_color()
		if not is_one:
			base = base.darkened(0.36)

		# 1. Halo externo luminoso (mais intenso quando o bit vale 1)
		var glow_col := Color(base.r, base.g, base.b, 0.34 if is_one else 0.12)
		var glow_pts := _shape_points(center, radius + (2.8 if is_one else 1.2))
		if glow_pts.size() >= 3:
			draw_colored_polygon(glow_pts, glow_col)

		# 2. Corpo 3D em camadas concêntricas (estilo orbe do jogo)
		var shadow_col := base.darkened(0.52)
		shadow_col.a = 0.96 if is_one else 0.82
		var mid_col := base
		mid_col.a = 1.0 if is_one else 0.86
		var core_col := base.lightened(0.42 if is_one else 0.18)
		core_col.a = 1.0 if is_one else 0.88

		var outer_pts := _shape_points(center, radius)
		if outer_pts.size() >= 3:
			draw_colored_polygon(outer_pts, shadow_col)

		var layers := 4
		for i in range(layers):
			var t := float(i + 1) / float(layers)
			var r_layer := radius * lerpf(0.88, 0.34, t)
			var shift := Vector2(-radius * 0.10 * t, -radius * 0.12 * t)
			if role == "mant":
				shift = Vector2(0.0, -radius * 0.08 * t)
			var col := shadow_col.lerp(mid_col, t * 2.0) if t < 0.5 else mid_col.lerp(core_col, (t - 0.5) * 2.0)
			var l_pts := _shape_points(center + shift, r_layer)
			if l_pts.size() >= 3:
				draw_colored_polygon(l_pts, col)

		# 3. Brilho especular vítreo
		var shine_pos := center + Vector2(-radius * 0.24, -radius * 0.30)
		if role == "mant":
			shine_pos = center + Vector2(0.0, -radius * 0.40)
		draw_circle(shine_pos, maxf(radius * 0.20, 1.8), Color(1.0, 1.0, 1.0, 0.52 if is_one else 0.24))

		# 4. Contorno nítido da forma geométrica
		if outer_pts.size() >= 3:
			var closed := outer_pts.duplicate()
			closed.append(outer_pts[0])
			var rim_col := base.lightened(0.35 if is_one else 0.10)
			rim_col.a = 1.0 if is_one else 0.72
			draw_polyline(closed, rim_col, 2.0 if is_one else 1.4, true)


## Miniatura da forma geométrica para a legenda.
class LegendShapeBadge extends Control:
	var role: String = "sign"

	func _init(p_role: String) -> void:
		role = p_role
		custom_minimum_size = Vector2(22, 22)
		size = Vector2(22, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := 8.5
		if role == "byte_frame":
			var rect := Rect2(c - Vector2(r, r * 0.78), Vector2(r * 2.0, r * 1.56))
			draw_rect(rect, Color(0.14, 0.12, 0.08, 0.9), true)
			draw_rect(rect, COLOR_BYTE_BORDER, false, 2.0)
			return
		var col: Color = COLOR_SIGN if role == "sign" else (COLOR_EXP if role == "exp" else (COLOR_MANT if role == "mant" else COLOR_BYTE))
		var pts := PackedVector2Array()
		match role:
			"sign":
				pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			"exp":
				for i in range(6):
					var a := -PI * 0.5 + TAU * float(i) / 6.0
					pts.append(c + Vector2(cos(a), sin(a)) * r)
			"mant":
				pts = PackedVector2Array([c + Vector2(0, -r * 1.15), c + Vector2(r * 1.05, r * 0.85), c + Vector2(-r * 1.05, r * 0.85)])
			_:
				for i in range(8):
					var a := PI * 0.125 + TAU * float(i) / 8.0
					pts.append(c + Vector2(cos(a), sin(a)) * r)
		if pts.size() >= 3:
			draw_colored_polygon(pts, col)
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, col.lightened(0.35), 1.6, true)
			var shine := c + Vector2(0, -r * 0.35) if role == "mant" else c + Vector2(-r * 0.25, -r * 0.25)
			draw_circle(shine, 2.0, Color(1, 1, 1, 0.6))


## Ícone de selo de efeito (Overflow ↑, Underflow ↓, Aproximação ≈, Exato ✓).
class EffectBadgeControl extends Control:
	var kind: String = "exact"

	func _init(p_kind: String = "exact", p_size: Vector2 = Vector2(32, 32)) -> void:
		kind = p_kind
		custom_minimum_size = p_size
		size = p_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_kind(p_kind: String) -> void:
		kind = p_kind
		queue_redraw()

	func _col() -> Color:
		match kind:
			"overflow":
				return COLOR_OVERFLOW
			"underflow":
				return COLOR_UNDERFLOW
			"precision":
				return COLOR_PRECISION
			_:
				return COLOR_EXACT

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		var col := _col()
		draw_circle(c, r, Color(0.07, 0.08, 0.12, 0.95))
		if kind == "precision":
			var dashes := 12
			var step := TAU / float(dashes)
			for i in range(dashes):
				var a0 := step * float(i)
				draw_arc(c, r, a0, a0 + step * 0.58, 5, col, 2.2, true)
		else:
			draw_arc(c, r, 0.0, TAU, 28, col, 2.4, true)

		match kind:
			"overflow":
				_draw_arrow(c, true, col)
			"underflow":
				_draw_arrow(c, false, col)
			"precision":
				_draw_wave(c + Vector2(0, -3.0), col)
				_draw_wave(c + Vector2(0, 3.0), col)
			_:
				var p1 := c + Vector2(-r * 0.38, 0.5)
				var p2 := c + Vector2(-r * 0.08, r * 0.34)
				var p3 := c + Vector2(r * 0.42, -r * 0.30)
				draw_line(p1, p2, col, 2.4, true)
				draw_line(p2, p3, col, 2.4, true)

	func _draw_wave(origin: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(9):
			var t := float(i) / 8.0
			pts.append(origin + Vector2(-6.5 + 13.0 * t, sin(t * TAU) * 2.0))
		draw_polyline(pts, col, 1.8, true)

	func _draw_arrow(origin: Vector2, up: bool, col: Color) -> void:
		var s := -1.0 if up else 1.0
		draw_line(origin + Vector2(0, -6.0 * s), origin + Vector2(0, 2.0 * s), col, 2.4, true)
		var tip := origin + Vector2(0, 6.8 * s)
		var pts := PackedVector2Array([tip, origin + Vector2(-5.0, 1.2 * s), origin + Vector2(5.0, 1.2 * s)])
		draw_colored_polygon(pts, col)


## Miniatura do orbe inspecionado no cabeçalho do modal.
class OrbMiniPreview extends Control:
	var base_color: Color = Color(0.20, 0.52, 1.0, 1.0)
	var label_text: String = "0"
	var effect_kind: String = ""
	var _lbl: Label = null

	func _init() -> void:
		custom_minimum_size = Vector2(68, 54)
		size = Vector2(68, 54)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lbl = Label.new()
		_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lbl.add_theme_font_size_override("font_size", 15)
		_lbl.add_theme_color_override("font_color", Color.WHITE)
		_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		_lbl.add_theme_constant_override("outline_size", 3)
		add_child(_lbl)

	func configure(p_color: Color, p_text: String, p_effect: String) -> void:
		base_color = p_color
		label_text = p_text
		effect_kind = p_effect
		if _lbl:
			_lbl.text = label_text
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		draw_circle(c, r + 3.0, Color(base_color.r, base_color.g, base_color.b, 0.25))
		draw_circle(c, r, base_color.darkened(0.45))
		for i in range(5):
			var t := float(i + 1) / 5.0
			var rl := r * lerpf(0.90, 0.32, t)
			var col := base_color.darkened(0.35).lerp(base_color.lightened(0.38), t)
			draw_circle(c + Vector2(-r * 0.10 * t, -r * 0.12 * t), rl, col)
		draw_circle(c + Vector2(-r * 0.26, -r * 0.28), r * 0.22, Color(1, 1, 1, 0.45))
		draw_arc(c, r, 0.0, TAU, 32, base_color.lightened(0.28), 2.0, true)
		if effect_kind in ["overflow", "underflow", "precision"]:
			var ecol := COLOR_OVERFLOW if effect_kind == "overflow" else (COLOR_UNDERFLOW if effect_kind == "underflow" else COLOR_PRECISION)
			draw_arc(c, r + 3.5, 0.0, TAU, 32, ecol, 2.2, true)


func _ready() -> void:
	layer = 122
	_build_ui()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_inspector()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.07, 0.80)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_inspector()
	)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "InspectorPanel"
	panel.custom_minimum_size = Vector2(880, 580)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -440
	panel.offset_top = -290
	panel.offset_right = 440
	panel.offset_bottom = 290
	PanelArtLoader.apply_dialog_panel(panel)
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# 1. Barra de título com ícone de lupa
	var header_hbox := HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header_hbox)

	var header_icon_wrap := Control.new()
	header_icon_wrap.custom_minimum_size = Vector2(28, 28)
	var header_lupa := MagnifyingGlassIcon.new()
	header_icon_wrap.add_child(header_lupa)
	header_hbox.add_child(header_icon_wrap)

	_title_lbl = Label.new()
	_title_lbl.text = "Inspecionador Binário de Orbe"
	_title_lbl.add_theme_font_size_override("font_size", 21)
	_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.93, 0.76))
	header_hbox.add_child(_title_lbl)

	# Scroll central para acomodar qualquer quantidade de bytes confortavelmente
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(content_vbox)

	# 2. Resumo do Orbe Inspecionado
	var summary_card := PanelContainer.new()
	summary_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.08, 0.10, 0.16, 0.95), Color(0.36, 0.62, 0.92, 0.75)))
	content_vbox.add_child(summary_card)

	var summary_hbox := HBoxContainer.new()
	summary_hbox.add_theme_constant_override("separation", 14)
	summary_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_card.add_child(summary_hbox)

	_orb_preview = OrbMiniPreview.new()
	summary_hbox.add_child(_orb_preview)

	_summary_rt = RichTextLabel.new()
	_summary_rt.bbcode_enabled = true
	_summary_rt.fit_content = true
	_summary_rt.scroll_active = false
	_summary_rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	OrbHoverBar.apply_info_richtext(_summary_rt, 15)
	summary_hbox.add_child(_summary_rt)

	_status_badge_panel = PanelContainer.new()
	_status_badge_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	summary_hbox.add_child(_status_badge_panel)

	_status_badge_lbl = Label.new()
	_status_badge_lbl.add_theme_font_size_override("font_size", 13)
	_status_badge_panel.add_child(_status_badge_lbl)

	# 3. Seção de Orbes Binários (Formas e Cores por Papel + Agrupamento em Bytes)
	var bin_card := PanelContainer.new()
	bin_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.07, 0.08, 0.13, 0.96), Color(0.45, 0.55, 0.78, 0.70)))
	content_vbox.add_child(bin_card)

	var bin_vbox := VBoxContainer.new()
	bin_vbox.add_theme_constant_override("separation", 8)
	bin_card.add_child(bin_vbox)

	# Legenda visual dinâmica de Formas e Cores (mostra apenas o que o orbe usa)
	_legend_hbox = HFlowContainer.new()
	_legend_hbox.alignment = FlowContainer.ALIGNMENT_CENTER
	_legend_hbox.add_theme_constant_override("h_separation", 16)
	_legend_hbox.add_theme_constant_override("v_separation", 6)
	bin_vbox.add_child(_legend_hbox)

	_bytes_flow = HFlowContainer.new()
	_bytes_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	_bytes_flow.add_theme_constant_override("h_separation", 12)
	_bytes_flow.add_theme_constant_override("v_separation", 10)
	bin_vbox.add_child(_bytes_flow)

	_formula_rt = RichTextLabel.new()
	_formula_rt.bbcode_enabled = true
	_formula_rt.fit_content = true
	_formula_rt.scroll_active = false
	OrbHoverBar.apply_info_richtext(_formula_rt, 14)
	bin_vbox.add_child(_formula_rt)

	# 4. Painel opcional de customização de bits FP8 / FP16
	insp_config_panel = PanelContainer.new()
	insp_config_panel.add_theme_stylebox_override("panel", _make_card_style(Color(0.11, 0.10, 0.16, 0.95), Color(0.85, 0.68, 0.28, 0.8)))
	var cfg_vbox := VBoxContainer.new()
	cfg_vbox.add_theme_constant_override("separation", 6)
	insp_config_panel.add_child(cfg_vbox)

	var lbl_cfg := Label.new()
	lbl_cfg.text = "Ajustar Divisão de Bits do Ponto Flutuante (1 Bit de Sinal fixo):"
	lbl_cfg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cfg.add_theme_font_size_override("font_size", 14)
	cfg_vbox.add_child(lbl_cfg)

	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 14)
	cfg_vbox.add_child(grid)

	var lbl_fp8_exp := Label.new()
	lbl_fp8_exp.text = "FP8 Expoente:"
	grid.add_child(lbl_fp8_exp)
	spin_fp8_exp = SpinBox.new()
	spin_fp8_exp.min_value = 1
	spin_fp8_exp.max_value = 6
	spin_fp8_exp.value_changed.connect(_on_insp_cfg_changed.bind("fp8"))
	grid.add_child(spin_fp8_exp)

	var lbl_fp8_mant := Label.new()
	lbl_fp8_mant.text = "FP8 Mantissa:"
	grid.add_child(lbl_fp8_mant)
	spin_fp8_mant = SpinBox.new()
	spin_fp8_mant.editable = false
	grid.add_child(spin_fp8_mant)

	var lbl_fp16_exp := Label.new()
	lbl_fp16_exp.text = "FP16 Expoente:"
	grid.add_child(lbl_fp16_exp)
	spin_fp16_exp = SpinBox.new()
	spin_fp16_exp.min_value = 1
	spin_fp16_exp.max_value = 14
	spin_fp16_exp.value_changed.connect(_on_insp_cfg_changed.bind("fp16"))
	grid.add_child(spin_fp16_exp)

	var lbl_fp16_mant := Label.new()
	lbl_fp16_mant.text = "FP16 Mantissa:"
	grid.add_child(lbl_fp16_mant)
	spin_fp16_mant = SpinBox.new()
	spin_fp16_mant.editable = false
	grid.add_child(spin_fp16_mant)

	content_vbox.add_child(insp_config_panel)

	# 5. Seção de Efeitos (Overflow, Underflow, Aproximação) — Exibida SOMENTE se aconteceu algum efeito!
	_effects_container = VBoxContainer.new()
	_effects_container.add_theme_constant_override("separation", 8)
	_effects_container.visible = false
	content_vbox.add_child(_effects_container)

	_active_effect_banner = PanelContainer.new()
	_effects_container.add_child(_active_effect_banner)

	var banner_hbox := HBoxContainer.new()
	banner_hbox.add_theme_constant_override("separation", 12)
	banner_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_active_effect_banner.add_child(banner_hbox)

	_active_effect_icon = EffectBadgeControl.new("exact", Vector2(36, 36))
	_active_effect_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	banner_hbox.add_child(_active_effect_icon)

	_active_effect_rt = RichTextLabel.new()
	_active_effect_rt.bbcode_enabled = true
	_active_effect_rt.fit_content = true
	_active_effect_rt.scroll_active = false
	_active_effect_rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	OrbHoverBar.apply_info_richtext(_active_effect_rt, 14)
	banner_hbox.add_child(_active_effect_rt)

	var ov_res := _build_effect_explanation_card(
		"overflow",
		"Overflow (Estouro)",
		"Ocorre quando o valor ultrapassa o limite máximo dos bits. No ponto flutuante o expoente enche de 1s e vira Inf (Infinito). Nos inteiros (Short/Int), os bits excedentes invadem o bit de sinal e o valor dá a volta.",
		COLOR_OVERFLOW
	)
	_card_overflow = ov_res.card
	_tag_overflow = ov_res.tag
	_effects_container.add_child(_card_overflow)

	var un_res := _build_effect_explanation_card(
		"underflow",
		"Underflow (Subfluxo)",
		"Ocorre quando um número diferente de zero é tão próximo de 0 que nem o menor expoente negativo consegue representá-lo. Os bits de expoente e mantissa zeram e o valor colapsa para 0.0.",
		COLOR_UNDERFLOW
	)
	_card_underflow = un_res.card
	_tag_underflow = un_res.tag
	_effects_container.add_child(_card_underflow)

	var pr_res := _build_effect_explanation_card(
		"precision",
		"Aproximação (Precisão)",
		"Ocorre quando há poucos bits de mantissa para guardar todas as casas decimais (arredondamento), na soma de escalas distantes (absorção), ou ao converter decimal para inteiro cortando a fração.",
		COLOR_PRECISION
	)
	_card_precision = pr_res.card
	_tag_precision = pr_res.tag
	_effects_container.add_child(_card_precision)

	# Botão Fechar
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(bottom_hbox)

	var btn_close := Button.new()
	btn_close.text = "Fechar"
	btn_close.custom_minimum_size = Vector2(140, 40)
	btn_close.pressed.connect(close_inspector)
	bottom_hbox.add_child(btn_close)

	PanelArtLoader.skin_all_buttons(_root)


func _make_card_style(bg: Color, border: Color, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _make_legend_item(role: String, text: String, col: Color) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var badge := LegendShapeBadge.new(role)
	hb.add_child(badge)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", col.lightened(0.22))
	hb.add_child(lbl)
	return hb


func _build_effect_explanation_card(kind: String, title_str: String, body_str: String, col: Color) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style(Color(0.08, 0.09, 0.14, 0.94), col.darkened(0.25), 1))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	card.add_child(vb)

	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 6)
	vb.add_child(top_hb)

	var icon := EffectBadgeControl.new(kind, Vector2(24, 24))
	top_hb.add_child(icon)

	var t_lbl := Label.new()
	t_lbl.text = title_str
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", col.lightened(0.18))
	top_hb.add_child(t_lbl)

	var tag := Label.new()
	tag.text = "ATIVO"
	tag.visible = false
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color.WHITE)
	top_hb.add_child(tag)

	var desc := Label.new()
	desc.text = body_str
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96, 0.94))
	vb.add_child(desc)

	return {"card": card, "tag": tag}


func close_inspector() -> void:
	hide()


func _cfg_int(prop: String, default_val: int) -> int:
	if config != null and prop in config:
		return int(config.get(prop))
	return default_val


func _cfg_bool(prop: String, default_val: bool = false) -> bool:
	if config != null and prop in config:
		return bool(config.get(prop))
	return default_val


func open(p_config, p_item) -> void:
	config = p_config
	current_item = p_item
	if current_item == null or not is_instance_valid(current_item):
		return

	var fp8_e: int = int(current_item.fp_exp_bits) if current_item.data_type == current_item.DataType.FP8 and current_item.fp_exp_bits != -1 else _cfg_int("fp8_exp_bits", 4)
	var fp16_e: int = int(current_item.fp_exp_bits) if current_item.data_type == current_item.DataType.FP16 and current_item.fp_exp_bits != -1 else _cfg_int("fp16_exp_bits", 5)

	spin_fp8_exp.set_value_no_signal(fp8_e)
	spin_fp8_mant.set_value_no_signal(7 - fp8_e)
	spin_fp16_exp.set_value_no_signal(fp16_e)
	spin_fp16_mant.set_value_no_signal(15 - fp16_e)

	insp_config_panel.visible = _cfg_bool("allow_fp_customization", false) and current_item.data_type in [current_item.DataType.FP8, current_item.DataType.FP16]

	_update_inspector_text()
	show()


func _on_insp_cfg_changed(_val: float, type: String) -> void:
	if current_item == null or not is_instance_valid(current_item):
		return
	if type == "fp8" and current_item.data_type == current_item.DataType.FP8:
		var new_exp_bits := int(spin_fp8_exp.value)
		var new_mant_bits := 7 - new_exp_bits
		spin_fp8_mant.set_value_no_signal(new_mant_bits)

		var old_exp: int = int(current_item.fp_exp_bits) if current_item.fp_exp_bits != -1 else _cfg_int("fp8_exp_bits", 4)
		var old_mant: int = int(current_item.fp_mant_bits) if current_item.fp_mant_bits != -1 else _cfg_int("fp8_mant_bits", 3)
		var dict := _float_to_custom_fp_bits(float(current_item.value_float), old_exp, old_mant)
		var raw_bits: int = int(dict.bits)

		current_item.fp_exp_bits = new_exp_bits
		current_item.fp_mant_bits = new_mant_bits

		var new_float := _custom_fp_bits_to_float(raw_bits, new_exp_bits, new_mant_bits)
		if current_item.has_method("set_value_by_type"):
			current_item.set_value_by_type(new_float, current_item.data_type)
		else:
			current_item.value_float = new_float
			if current_item.has_method("update_label_display"):
				current_item.update_label_display()

	elif type == "fp16" and current_item.data_type == current_item.DataType.FP16:
		var new_exp_bits := int(spin_fp16_exp.value)
		var new_mant_bits := 15 - new_exp_bits
		spin_fp16_mant.set_value_no_signal(new_mant_bits)

		var old_exp: int = int(current_item.fp_exp_bits) if current_item.fp_exp_bits != -1 else _cfg_int("fp16_exp_bits", 5)
		var old_mant: int = int(current_item.fp_mant_bits) if current_item.fp_mant_bits != -1 else _cfg_int("fp16_mant_bits", 10)
		var dict := _float_to_custom_fp_bits(float(current_item.value_float), old_exp, old_mant)
		var raw_bits: int = int(dict.bits)

		current_item.fp_exp_bits = new_exp_bits
		current_item.fp_mant_bits = new_mant_bits

		var new_float := _custom_fp_bits_to_float(raw_bits, new_exp_bits, new_mant_bits)
		if current_item.has_method("set_value_by_type"):
			current_item.set_value_by_type(new_float, current_item.data_type)
		else:
			current_item.value_float = new_float
			if current_item.has_method("update_label_display"):
				current_item.update_label_display()

	_update_inspector_text()


func _update_inspector_text() -> void:
	if current_item == null or not is_instance_valid(current_item):
		return
	var item = current_item
	var effect_info := _analyze_item_effect(item)
	var active_kind: String = str(effect_info.get("kind", "exact"))

	# 1. Atualiza preview do orbe e resumo superior
	var orb_col := ItemVisuals.get_color_for_type(item)
	var compact_lbl := OrbValueFormat.compact_label_string(item)
	_orb_preview.configure(orb_col, compact_lbl, active_kind)

	var np_repr: String = OrbValueFormat.numpy_repr_string(item)
	var type_title: String = OrbValueFormat.type_title(item)
	var full_val: String = OrbValueFormat.full_value_string(item)
	var summary_text := "[b]%s[/b]" % type_title
	if np_repr != "":
		summary_text += "   ·   Código Python/NumPy: [b]%s[/b]" % np_repr
	summary_text += "\nValor armazenado: [b]%s[/b]" % full_val
	if item.get("has_source_value") and bool(item.has_source_value):
		var src_str := String.num(float(item.source_value), 6)
		if src_str != full_val and absf(float(item.source_value) - item.get_numeric_value()) > 1e-7:
			summary_text += "   (Valor original antes da conversão/operação: [b]%s[/b])" % src_str
	_summary_rt.text = ReadableBbcode.for_ui(summary_text)

	var has_effect := (active_kind in ["overflow", "underflow", "precision"])

	if _status_badge_panel:
		if has_effect:
			var badge_col := COLOR_EXACT
			var badge_txt := ""
			match active_kind:
				"overflow":
					badge_col = COLOR_OVERFLOW
					badge_txt = "↑ OVERFLOW"
				"underflow":
					badge_col = COLOR_UNDERFLOW
					badge_txt = "↓ UNDERFLOW"
				"precision":
					badge_col = COLOR_PRECISION
					badge_txt = "≈ APROXIMAÇÃO"
			_status_badge_panel.visible = true
			_status_badge_panel.add_theme_stylebox_override("panel", _make_card_style(badge_col.darkened(0.65), badge_col, 2))
			_status_badge_lbl.text = badge_txt
			_status_badge_lbl.add_theme_color_override("font_color", badge_col.lightened(0.25))
		else:
			_status_badge_panel.visible = false

	# 2. Reconstrói os Orbes Binários agrupados por Byte
	for ch in _bytes_flow.get_children():
		ch.queue_free()

	var bit_specs: Array[Dictionary] = _build_bit_specs_for_item(item)
	var orb_px := 27.0 if bit_specs.size() > 32 else 34.0
	var total_bits := bit_specs.size()
	var num_bytes := maxi(1, int(ceil(float(total_bits) / 8.0)))

	# Atualiza a legenda mostrando ESTRITAMENTE o que este orbe possui
	var has_sign := false
	var has_exp := false
	var has_mant := false
	var has_byte := false

	for spec in bit_specs:
		match str(spec.get("role", "")):
			"sign": has_sign = true
			"exp": has_exp = true
			"mant": has_mant = true
			"byte": has_byte = true

	if _legend_hbox:
		for ch in _legend_hbox.get_children():
			ch.queue_free()
		if has_sign:
			_legend_hbox.add_child(_make_legend_item("sign", "Sinal (Losango)", COLOR_SIGN))
		if has_exp:
			_legend_hbox.add_child(_make_legend_item("exp", "Expoente (Hexágono)", COLOR_EXP))
		if has_mant:
			_legend_hbox.add_child(_make_legend_item("mant", "Mantissa (Triângulo)", COLOR_MANT))
		if has_byte:
			_legend_hbox.add_child(_make_legend_item("byte", "Magnitude (Octógono)", COLOR_BYTE))
		if num_bytes > 0:
			_legend_hbox.add_child(_make_legend_item("byte_frame", "Byte (Bloco de 8 bits)", COLOR_BYTE_BORDER))

	for b_idx in range(num_bytes):
		var start_i := b_idx * 8
		var end_i := mini(start_i + 8, total_bits)
		var byte_num := (num_bytes - 1) - b_idx
		var msb_pos := total_bits - 1 - start_i
		var lsb_pos := total_bits - end_i

		var byte_card := PanelContainer.new()
		byte_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.10, 0.11, 0.17, 0.96), COLOR_BYTE_BORDER, 2))

		var b_vbox := VBoxContainer.new()
		b_vbox.add_theme_constant_override("separation", 4)
		byte_card.add_child(b_vbox)

		var roles_in_byte: PackedStringArray = PackedStringArray()
		for i in range(start_i, end_i):
			var r_lbl: String = str(bit_specs[i].get("role_label", ""))
			if r_lbl != "" and not roles_in_byte.has(r_lbl):
				roles_in_byte.append(r_lbl)

		var byte_hdr := Label.new()
		byte_hdr.text = "Byte %d (bits %d..%d) · %s" % [byte_num, msb_pos, lsb_pos, " + ".join(roles_in_byte)]
		byte_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		byte_hdr.add_theme_font_size_override("font_size", 11)
		byte_hdr.add_theme_color_override("font_color", COLOR_BYTE_BORDER.lightened(0.18))
		b_vbox.add_child(byte_hdr)

		var bits_hbox := HBoxContainer.new()
		bits_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		bits_hbox.add_theme_constant_override("separation", 4)
		b_vbox.add_child(bits_hbox)

		for i in range(start_i, end_i):
			var spec: Dictionary = bit_specs[i]
			var bit_orb := BitOrbShapeControl.new(
				str(spec.get("bit", "0")),
				str(spec.get("role", "byte")),
				orb_px,
				str(spec.get("tooltip", ""))
			)
			bits_hbox.add_child(bit_orb)

		_bytes_flow.add_child(byte_card)

	_formula_rt.text = ReadableBbcode.for_ui(_build_formula_breakdown_text(item))

	# 3. Seção de Efeitos: exibe SOMENTE se ocorreu Overflow, Underflow ou Aproximação
	if _effects_container:
		_effects_container.visible = has_effect
	if _active_effect_banner:
		_active_effect_banner.visible = has_effect
	if _card_overflow:
		_card_overflow.visible = (active_kind == "overflow")
	if _card_underflow:
		_card_underflow.visible = (active_kind == "underflow")
	if _card_precision:
		_card_precision.visible = (active_kind == "precision")

	if has_effect:
		var effect_col := COLOR_OVERFLOW if active_kind == "overflow" else (COLOR_UNDERFLOW if active_kind == "underflow" else COLOR_PRECISION)
		_active_effect_icon.set_kind(active_kind)
		_active_effect_banner.add_theme_stylebox_override(
			"panel",
			_make_card_style(effect_col.darkened(0.75), effect_col, 2)
		)
		_active_effect_rt.text = ReadableBbcode.for_ui(str(effect_info.get("bbcode", "")))
		_highlight_effect_card(_card_overflow, _tag_overflow, COLOR_OVERFLOW, active_kind == "overflow")
		_highlight_effect_card(_card_underflow, _tag_underflow, COLOR_UNDERFLOW, active_kind == "underflow")
		_highlight_effect_card(_card_precision, _tag_precision, COLOR_PRECISION, active_kind == "precision")


func _highlight_effect_card(card: PanelContainer, tag: Label, col: Color, is_active: bool) -> void:
	if card == null:
		return
	if is_active:
		card.add_theme_stylebox_override("panel", _make_card_style(col.darkened(0.72), col, 2))
	else:
		card.add_theme_stylebox_override("panel", _make_card_style(Color(0.08, 0.09, 0.14, 0.94), col.darkened(0.35), 1))
	if tag != null:
		tag.visible = is_active


func _build_bit_specs_for_item(item: Node) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var dt: int = item.data_type

	if dt in [item.DataType.INT, item.DataType.SHORT_INT]:
		var bits := 32 if dt == item.DataType.INT else 16
		var int_val: int = item.value if dt == item.DataType.INT else item.value_short
		var bin_str := _int_to_bin_str(int_val, bits)
		for i in range(bits):
			var bit_pos := (bits - 1) - i
			var b_ch := bin_str[i]
			if i == 0:
				specs.append({
					"bit": b_ch,
					"role": "sign",
					"role_label": "Sinal",
					"tooltip": "Bit %d — Sinal (Complemento de 2): %s (%s)" % [bit_pos, b_ch, "Negativo (-)" if b_ch == "1" else "Positivo (+)"]
				})
			else:
				var weight := 1 << bit_pos
				specs.append({
					"bit": b_ch,
					"role": "byte",
					"role_label": "Magnitude",
					"tooltip": "Bit %d — Magnitude Inteira: bit %s (peso 2^%d = %d)" % [bit_pos, b_ch, bit_pos, weight]
				})
		return specs

	if dt == item.DataType.BINARY:
		var b_str: String = item.value_binary if item.value_binary != "" else _int_to_bin_str(item.value, maxi(item.binary_bits, 1))
		var n := b_str.length()
		for i in range(n):
			var bit_pos := (n - 1) - i
			var b_ch := b_str[i]
			specs.append({
				"bit": b_ch,
				"role": "byte",
				"role_label": "Binário",
				"tooltip": "Bit %d — Valor posicional: %s × 2^%d = %d" % [bit_pos, b_ch, bit_pos, (1 << bit_pos) if b_ch == "1" else 0]
			})
		return specs

	if dt == item.DataType.RAW:
		var raw_v: float = item.value_float
		var is_decimal := ("." in str(item.raw_literal)) or not is_equal_approx(raw_v, roundf(raw_v))
		if not is_decimal and absf(raw_v) <= 2147483647.0:
			var bin_i := _int_to_bin_str(int(roundf(raw_v)), 16 if absf(raw_v) <= 32767.0 else 32)
			var nb := bin_i.length()
			for i in range(nb):
				var bit_pos := (nb - 1) - i
				var b_ch := bin_i[i]
				if i == 0:
					specs.append({
						"bit": b_ch,
						"role": "sign",
						"role_label": "Sinal",
						"tooltip": "Bit %d — Sinal: %s (%s)" % [bit_pos, b_ch, "Negativo (-)" if b_ch == "1" else "Positivo (+)"]
					})
				else:
					specs.append({
						"bit": b_ch,
						"role": "byte",
						"role_label": "Magnitude",
						"tooltip": "Bit %d — Magnitude: bit %s (2^%d)" % [bit_pos, b_ch, bit_pos]
					})
			return specs
		return _build_fp_bit_specs(_float_to_custom_fp_bits(raw_v, 8, 23), 8, 23)

	if dt == item.DataType.FLOAT:
		return _build_fp_bit_specs(_float_to_custom_fp_bits(item.value_float, 8, 23), 8, 23)
	if dt == item.DataType.DOUBLE:
		return _build_fp_bit_specs(_double_to_fp_bits(item.value_double), 11, 52)
	if dt == item.DataType.FP8:
		var e8: int = int(item.fp_exp_bits) if item.fp_exp_bits != -1 else _cfg_int("fp8_exp_bits", 4)
		var m8: int = int(item.fp_mant_bits) if item.fp_mant_bits != -1 else _cfg_int("fp8_mant_bits", 3)
		return _build_fp_bit_specs(_float_to_custom_fp_bits(float(item.value_float), e8, m8), e8, m8)
	if dt == item.DataType.FP16:
		var e16: int = int(item.fp_exp_bits) if item.fp_exp_bits != -1 else _cfg_int("fp16_exp_bits", 5)
		var m16: int = int(item.fp_mant_bits) if item.fp_mant_bits != -1 else _cfg_int("fp16_mant_bits", 10)
		return _build_fp_bit_specs(_float_to_custom_fp_bits(float(item.value_float), e16, m16), e16, m16)

	return specs


func _build_fp_bit_specs(dict: Dictionary, exp_bits: int, mant_bits: int) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var total := 1 + exp_bits + mant_bits
	var s_ch := "1" if int(dict.get("sign", 0)) != 0 else "0"
	specs.append({
		"bit": s_ch,
		"role": "sign",
		"role_label": "Sinal",
		"tooltip": "Bit %d — Sinal (Losango Vermelho): %s → %s" % [total - 1, s_ch, "Negativo (-)" if s_ch == "1" else "Positivo (+)"]
	})

	var exp_val: int = int(dict.get("exp", 0))
	for i in range(exp_bits - 1, -1, -1):
		var b_ch := "1" if (exp_val & (1 << i)) != 0 else "0"
		var bit_pos := mant_bits + i
		specs.append({
			"bit": b_ch,
			"role": "exp",
			"role_label": "Expoente",
			"tooltip": "Bit %d — Expoente (Hexágono Verde): bit %s (peso 2^%d = %d no expoente)" % [bit_pos, b_ch, i, 1 << i]
		})

	var mant_val: int = int(dict.get("mant", 0))
	for i in range(mant_bits - 1, -1, -1):
		var b_ch := "1" if (mant_val & (1 << i)) != 0 else "0"
		var frac_idx := mant_bits - i
		specs.append({
			"bit": b_ch,
			"role": "mant",
			"role_label": "Mantissa",
			"tooltip": "Bit %d — Mantissa (Triângulo Dourado): bit %s (fração 2^-%d)" % [i, b_ch, frac_idx]
		})
	return specs


func _build_formula_breakdown_text(item: Node) -> String:
	var dt: int = item.data_type
	if dt in [item.DataType.INT, item.DataType.SHORT_INT]:
		var bits := 32 if dt == item.DataType.INT else 16
		var v: int = item.value if dt == item.DataType.INT else item.value_short
		var s_bit := "1 (Negativo -)" if v < 0 else "0 (Positivo +)"
		var min_v := "-2.147.483.648" if bits == 32 else "-32.768"
		var max_v := "2.147.483.647" if bits == 32 else "32.767"
		return "[b]Estrutura Inteira (%d bits / %d Bytes):[/b]   [color=#ff6b72]◆ Sinal: %s[/color]   ·   [color=#b48cff]■ Magnitude: %d bits[/color]   ·   Alcance do tipo: [b]%s a %s[/b]" % [
			bits, bits / 8, s_bit, bits - 1, min_v, max_v
		]
	if dt == item.DataType.BINARY:
		var b_str: String = item.value_binary
		return "[b]Binário Puro (%d bit(s)):[/b]   [color=#b48cff]%s[/color]   →   Valor Decimal: [b]%d[/b]" % [b_str.length(), b_str, item.value]

	var exp_bits := 8
	var mant_bits := 23
	var dict: Dictionary
	if dt == item.DataType.DOUBLE:
		exp_bits = 11
		mant_bits = 52
		dict = _double_to_fp_bits(item.value_double)
	elif dt == item.DataType.FP8:
		exp_bits = item.fp_exp_bits if item.fp_exp_bits != -1 else _cfg_int("fp8_exp_bits", 4)
		mant_bits = item.fp_mant_bits if item.fp_mant_bits != -1 else _cfg_int("fp8_mant_bits", 3)
		dict = _float_to_custom_fp_bits(item.value_float, exp_bits, mant_bits)
	elif dt == item.DataType.FP16:
		exp_bits = item.fp_exp_bits if item.fp_exp_bits != -1 else _cfg_int("fp16_exp_bits", 5)
		mant_bits = item.fp_mant_bits if item.fp_mant_bits != -1 else _cfg_int("fp16_mant_bits", 10)
		dict = _float_to_custom_fp_bits(item.value_float, exp_bits, mant_bits)
	elif dt == item.DataType.RAW:
		var raw_v: float = item.value_float
		var is_dec := ("." in str(item.raw_literal)) or not is_equal_approx(raw_v, roundf(raw_v))
		if not is_dec and absf(raw_v) <= 2147483647.0:
			var fits_short := absf(raw_v) <= 32767.0
			return "[b]Prévia Binária (Orbe sem tipo — RAW inteiro):[/b]   Cabe em [b]Short (2 Bytes)[/b]: %s   ·   Cabe em [b]Int (4 Bytes)[/b]: Sim" % [
				"Sim (≤ 32767)" if fits_short else "Não (> 32767, sofreria Overflow em Short!)"
			]
		dict = _float_to_custom_fp_bits(raw_v, 8, 23)
	else:
		dict = _float_to_custom_fp_bits(item.value_float, 8, 23)

	var bias := (1 << (exp_bits - 1)) - 1
	var max_exp := (1 << exp_bits) - 1
	var raw_exp: int = int(dict.get("exp", 0))
	var actual_exp := raw_exp - bias
	var sign_sym := "-" if int(dict.get("sign", 0)) != 0 else "+"
	var exp_desc := "%d (Expoente = %d − Viés %d)" % [actual_exp, raw_exp, bias]
	if raw_exp == max_exp:
		exp_desc = "TODOS 1s (%d) → INFINITO / NaN (Overflow)" % raw_exp
	elif raw_exp == 0:
		exp_desc = "TODOS 0s (0) → Zero / Subnormal"

	return "[b]Decodificação Ponto Flutuante:[/b]   [color=#ff6b72]◆ Sinal (1 bit): %s[/color]   |   [color=#4ce884]⬡ Expoente (%d bits): %s[/color]   |   [color=#fca82a]▲ Mantissa (%d bits de precisão)[/color]" % [
		sign_sym, exp_bits, exp_desc, mant_bits
	]


func _analyze_item_effect(item: Node) -> Dictionary:
	var dt: int = item.data_type
	var cur_val: float = item.get_numeric_value() if item.has_method("get_numeric_value") else 0.0
	var has_src: bool = bool(item.get("has_source_value"))
	var src_val: float = float(item.source_value) if has_src else cur_val
	var deg_kind: String = str(item.get("degradation_kind")) if item.get("degradation_kind") != null else ""

	# 1. Verifica OVERFLOW
	var is_overflow := deg_kind == "overflow" or is_inf(cur_val)
	if not is_overflow and has_src:
		if dt == item.DataType.SHORT_INT and (src_val > 32767.0 or src_val < -32768.0):
			is_overflow = true
		elif dt == item.DataType.INT and (src_val > 2147483647.0 or src_val < -2147483648.0):
			is_overflow = true

	if is_overflow:
		var msg := "[b]EFEITO DETECTADO NESTE ORBE: OVERFLOW (Estouro de Capacidade)[/b]\n"
		if dt in [item.DataType.SHORT_INT, item.DataType.INT]:
			var bits := 16 if dt == item.DataType.SHORT_INT else 32
			msg += "O valor original ([b]%s[/b]) excedeu o limite máximo de %d bits e invadiu o [b]Losango Vermelho (Bit de Sinal)[/b], fazendo o número dar a volta para [b]%s[/b]." % [
				String.num(src_val, 4), bits, OrbValueFormat.full_value_string(item)
			]
		else:
			msg += "O valor ([b]%s[/b]) ultrapassou o alcance máximo do tipo: todos os [b]Hexágonos Verdes (Expoente)[/b] ficaram em [b]1[/b], transformando o orbe em [b]Infinito (Inf)[/b]." % [
				String.num(src_val, 4)
			]
		return {"kind": "overflow", "bbcode": msg}

	# 2. Verifica UNDERFLOW
	var is_underflow := deg_kind == "underflow" or (has_src and src_val != 0.0 and cur_val == 0.0 and dt in [item.DataType.FLOAT, item.DataType.DOUBLE, item.DataType.FP8, item.DataType.FP16])
	if is_underflow:
		var msg := "[b]EFEITO DETECTADO NESTE ORBE: UNDERFLOW (Colapso para Zero)[/b]\n"
		msg += "O valor original ([b]%s[/b]) era pequeno demais para o menor expoente negativo deste tipo. Todos os [b]Hexágonos Verdes (Expoente)[/b] e [b]Triângulos Dourados (Mantissa)[/b] zeraram, colapsando o valor para [b]0.0[/b]." % [
			String.num(src_val, 6)
		]
		return {"kind": "underflow", "bbcode": msg}

	# 3. Verifica APROXIMAÇÃO (Perda de Precisão / Truncamento / Quantização)
	var diff := absf(cur_val - src_val) if has_src else 0.0
	var is_precision := deg_kind == "precision" or (has_src and diff > 1e-7)
	if not is_precision and dt in [item.DataType.FP8, item.DataType.FP16]:
		var e_b: int = (int(item.fp_exp_bits) if item.fp_exp_bits != -1 else _cfg_int("fp8_exp_bits", 4)) if dt == item.DataType.FP8 else (int(item.fp_exp_bits) if item.fp_exp_bits != -1 else _cfg_int("fp16_exp_bits", 5))
		var m_b: int = (int(item.fp_mant_bits) if item.fp_mant_bits != -1 else _cfg_int("fp8_mant_bits", 3)) if dt == item.DataType.FP8 else (int(item.fp_mant_bits) if item.fp_mant_bits != -1 else _cfg_int("fp16_mant_bits", 10))
		var d_fp := _float_to_custom_fp_bits(cur_val, e_b, m_b)
		var recon := _custom_fp_bits_to_float(int(d_fp.bits), e_b, m_b)
		if absf(recon - cur_val) > 1e-6:
			is_precision = true

	if is_precision:
		var msg := "[b]EFEITO DETECTADO NESTE ORBE: APROXIMAÇÃO (Perda de Precisão)[/b]\n"
		if dt in [item.DataType.INT, item.DataType.SHORT_INT] and has_src and src_val != floorf(src_val):
			msg += "Na conversão para inteiro, a parte decimal de [b]%s[/b] foi descartada (truncamento), restando apenas [b]%s[/b]." % [
				String.num(src_val, 6), OrbValueFormat.full_value_string(item)
			]
		else:
			msg += "Os [b]Triângulos Dourados (Mantissa)[/b] têm bits limitados e arredondaram o valor de [b]%s[/b] para a representação binária mais próxima: [b]%s[/b] (erro de %s)." % [
				String.num(src_val, 6), OrbValueFormat.full_value_string(item), String.num(diff, 6)
			]
		return {"kind": "precision", "bbcode": msg}

	# 4. Sem degradação ativa (Exato) — inclui dicas preventivas
	var ok_msg := "[b]DIAGNÓSTICO DESTE ORBE: Representação Estável (Sem Overflow / Underflow)[/b]\n"
	if dt == item.DataType.RAW:
		if absf(cur_val) > 32767.0:
			ok_msg += "Dica: como [b]%s[/b] > 32.767, colocá-lo em [b]Short (16 bits)[/b] causará [b]Overflow[/b]! Use [b]Int (32 bits)[/b] ou superior." % OrbValueFormat.full_value_string(item)
		elif ("." in str(item.raw_literal)) or not is_equal_approx(cur_val, roundf(cur_val)):
			ok_msg += "Dica: este valor possui parte decimal ([b]%s[/b]). Em [b]Int/Short[/b] perderia a fração; use [b]Float/Double/FP16[/b]." % OrbValueFormat.full_value_string(item)
		else:
			ok_msg += "Este valor cabe perfeitamente em tipos inteiros sem perda de precisão."
	else:
		ok_msg += "Os bits atuais de Sinal, Expoente/Magnitude e Mantissa representam o valor dentro dos limites do tipo."
	return {"kind": "exact", "bbcode": ok_msg}


func _int_to_bin_str(val: int, bits: int) -> String:
	var s := ""
	for i in range(bits - 1, -1, -1):
		s += "1" if (val & (1 << i)) != 0 else "0"
	return s


func _float_to_custom_fp_bits(val: float, exp_bits: int, mant_bits: int) -> Dictionary:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, val)
	var f_bits := bytes.decode_u32(0)

	var sign_bit := (f_bits >> 31) & 1
	var f_exp := (f_bits >> 23) & 0xFF
	var f_mant := f_bits & 0x7FFFFF

	var tgt_bias := (1 << (exp_bits - 1)) - 1
	var tgt_exp := 0
	var tgt_mant := 0

	if f_exp == 0xFF:
		tgt_exp = (1 << exp_bits) - 1
		tgt_mant = 1 if f_mant != 0 else 0
	elif f_exp == 0:
		tgt_exp = 0
		tgt_mant = 0
	else:
		var actual_exp := f_exp - 127
		tgt_exp = actual_exp + tgt_bias
		if tgt_exp >= (1 << exp_bits) - 1:
			tgt_exp = (1 << exp_bits) - 1
			tgt_mant = 0
		elif tgt_exp <= 0:
			tgt_exp = 0
			tgt_mant = 0
		else:
			if mant_bits <= 23:
				tgt_mant = f_mant >> (23 - mant_bits)
			else:
				tgt_mant = f_mant << (mant_bits - 23)

	var combined_bits := (sign_bit << (exp_bits + mant_bits)) | (tgt_exp << mant_bits) | tgt_mant
	return {"sign": sign_bit, "exp": tgt_exp, "mant": tgt_mant, "bits": combined_bits}


func _custom_fp_bits_to_float(bits: int, exp_bits: int, mant_bits: int) -> float:
	var sign_bit := (bits >> (exp_bits + mant_bits)) & 1
	var tgt_exp := (bits >> mant_bits) & ((1 << exp_bits) - 1)
	var tgt_mant := bits & ((1 << mant_bits) - 1)
	var tgt_bias := (1 << (exp_bits - 1)) - 1

	var f_exp := 0
	var f_mant := 0

	if tgt_exp == ((1 << exp_bits) - 1):
		f_exp = 0xFF
		f_mant = 1 if tgt_mant != 0 else 0
	elif tgt_exp == 0:
		f_exp = 0
		f_mant = 0
	else:
		var actual_exp := tgt_exp - tgt_bias
		f_exp = actual_exp + 127
		if f_exp <= 0:
			f_exp = 0
		elif f_exp >= 0xFF:
			f_exp = 0xFF
			f_mant = 0
		else:
			if mant_bits <= 23:
				f_mant = tgt_mant << (23 - mant_bits)
			else:
				f_mant = tgt_mant >> (mant_bits - 23)

	var f_bits := (sign_bit << 31) | (f_exp << 23) | f_mant
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, f_bits)
	return bytes.decode_float(0)


func _double_to_fp_bits(val: float) -> Dictionary:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, val)
	var f_bits := bytes.decode_u64(0)
	var sign_bit := (f_bits >> 63) & 1
	var f_exp := (f_bits >> 52) & 0x7FF
	var f_mant := f_bits & 0xFFFFFFFFFFFFF
	return {"sign": sign_bit, "exp": f_exp, "mant": f_mant}
