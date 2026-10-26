class_name UiKit
extends RefCounted
## Shared look for the menus: pixel fonts, card panels with a coloured header, gamepad button
## glyphs, keyboard keycaps and little station icons.

const INK := Color("1a1422")
const CREAM := Color("f3e9d2")
const GOLD := Color("f0c040")
const MUTED := Color("b8b0c8")
const BUTTON_COLORS := {
	"A": Color("5cc85a"), "B": Color("e0524a"), "X": Color("4a8ee0"), "Y": Color("f0c040"),
}

static var _title_font: Font
static var _body_font: Font


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://assets/fonts/PressStart2P.ttf")
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		var f: FontFile = load("res://assets/fonts/PixelifySans.ttf")
		var v := FontVariation.new()
		v.base_font = f
		v.variation_opentype = {"wght": 500}
		v.opentype_features = {"liga": 0, "clig": 0}  # its "fi" ligature reads like "A"
		_body_font = v
	return _body_font


## A big pixel-font heading with a hard drop shadow.
static func title(text: String, font_size := 16, color := GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", INK)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func label(text: String, font_size := 9, color := CREAM, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("line_spacing", -4)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(60, 0)
	return l


## A card: a dark panel with a coloured header strip. Returns the VBox to fill.
static func card(parent: Control, heading: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.08, 0.16, 0.92)
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_offset = Vector2(3, 3)
	sb.shadow_size = 1
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)
	var head := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = accent
	hs.content_margin_left = 6
	hs.content_margin_top = 4
	hs.content_margin_bottom = 3
	hs.border_color = accent.darkened(0.45)
	hs.border_width_bottom = 2
	head.add_theme_stylebox_override("panel", hs)
	outer.add_child(head)
	var hl := Label.new()
	hl.text = heading
	hl.add_theme_font_override("font", title_font())
	hl.add_theme_font_size_override("font_size", 8)
	hl.add_theme_color_override("font_color", INK)
	hl.add_theme_constant_override("outline_size", 0)
	head.add_child(hl)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	pad.add_child(box)
	return box


## One row: a few glyphs/keycaps, then a description.
static func row(parent: Control, glyphs: Array, text: String, color := CREAM) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	var g := HBoxContainer.new()
	g.add_theme_constant_override("separation", 1)
	g.custom_minimum_size = Vector2(46, 0)
	for name: String in glyphs:
		if name == "+":
			var plus := label("+", 8, MUTED)
			g.add_child(plus)
		else:
			g.add_child(Glyph.new(name))
	h.add_child(g)
	var l := label(text, 9, color, true)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	parent.add_child(h)
	return h


class Glyph:
	extends Control
	## A gamepad button (round, in its colour), a stick, a D-pad or a keyboard keycap.
	var glyph := "A"

	func _init(g: String) -> void:
		glyph = g
		var w := 13.0
		if glyph.begins_with("key:"):
			w = maxf(13.0, 6.0 + glyph.length() * 4.5 - 18.0)
		elif glyph in ["Start", "LB", "RB"]:
			w = 20.0
		custom_minimum_size = Vector2(w, 13)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := UiKit.body_font()
		var c := size / 2.0
		if UiKit.BUTTON_COLORS.has(glyph):
			draw_circle(c + Vector2(0, 1), 6.0, UiKit.INK)
			draw_circle(c, 6.0, UiKit.BUTTON_COLORS[glyph])
			draw_circle(c + Vector2(-1.5, -1.5), 2.0, Color(1, 1, 1, 0.35))
			_centered(font, glyph, c + Vector2(0, 3.5), 9, UiKit.INK)
		elif glyph == "stick":
			draw_circle(c + Vector2(0, 1), 6.0, UiKit.INK)
			draw_circle(c, 6.0, Color("50505c"))
			draw_circle(c, 3.5, Color("8a8a98"))
		elif glyph == "dpad":
			for r in [Rect2(c.x - 2, c.y - 6, 4, 12), Rect2(c.x - 6, c.y - 2, 12, 4)]:
				draw_rect(Rect2(r.position + Vector2(0, 1), r.size), UiKit.INK)
				draw_rect(r, Color("8a8a98"))
		elif glyph.begins_with("key:"):
			var t := glyph.substr(4)
			var r := Rect2(Vector2(0.5, 0.5), size - Vector2(1, 2))
			draw_rect(Rect2(r.position + Vector2(0, 1.5), r.size), UiKit.INK)
			draw_rect(r, Color("e8e2d4"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color.WHITE)
			_centered(font, t, c + Vector2(0, 2.5), 8, UiKit.INK)
		else:
			var r := Rect2(Vector2(0.5, 1.5), size - Vector2(1, 3))
			draw_rect(Rect2(r.position + Vector2(0, 1), r.size), UiKit.INK)
			draw_rect(r, Color("5a5a68"))
			_centered(font, glyph, c + Vector2(0, 2.5), 7, UiKit.CREAM)

	func _centered(font: Font, t: String, base: Vector2, fs: int, col: Color) -> void:
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(base.x - w / 2.0, base.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


class StationIcon:
	extends Control
	## A station drawn just like it looks on the balloon, for the menus.
	var _balloon: Balloon
	var _station: Station

	func _init(role: int) -> void:
		custom_minimum_size = Vector2(32, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_balloon = Balloon.new()
		_station = Balloon.STATION_SCRIPTS[role].new()
		_station.role = role
		_station.balloon = _balloon
		_station.unlocked = true
		_station.visible = true
		_station.scale = Vector2(1.25, 1.25)
		var x := 16.0
		match role:
			Roles.PROPELLER:
				x = 6.0
			Roles.PROPELLER2:
				x = 26.0
			Roles.FISHING:
				x = 30.0
		_station.position = Vector2(x, 29)
		add_child(_station)

	func _exit_tree() -> void:
		if is_instance_valid(_balloon):
			_balloon.free()


class ItemIcon:
	extends Control
	## A sprite from Art, centred.
	var sprite := "fuel"

	func _init(s: String) -> void:
		sprite = s
		custom_minimum_size = Vector2(20, 20)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var tex := Art.sprite(sprite)
		draw_set_transform((size / 2.0 - tex.get_size()).floor(), 0.0, Vector2(2, 2))
		draw_texture(tex, Vector2.ZERO)
