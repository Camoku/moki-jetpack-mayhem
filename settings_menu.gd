# ==========================================================
#  settings_menu.gd - the in-game AUDIO settings overlay
# ==========================================================
#  A global menu (owned by the Audio autoload, so it exists in every scene).
#  A small "Audio" button sits in the top-right corner at all times; click it
#  (or press ESC) to open the panel: Master / Music / SFX sliders + a Mute
#  toggle. Changes apply live and are saved by the Audio manager.
#  The UI is built in code so there's no scene file to wire up.
# ==========================================================
extends CanvasLayer

var _open: bool = false
var _menu_root: Control          # the dim + panel (hidden until opened)
var _sliders: Dictionary = {}    # bus name -> HSlider
var _pcts: Dictionary = {}       # bus name -> Label
var _mute_btn: Button


func _ready() -> void:
	layer = 128                                  # above everything (HUD included)
	process_mode = Node.PROCESS_MODE_ALWAYS      # works while the tree is paused
	_build()


func _build() -> void:
	# A full-screen layer that lets gameplay clicks pass through (only its
	# button/dim children grab the mouse).
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# The always-visible corner button that opens the menu.
	var gear := Button.new()
	gear.text = "Audio"
	gear.focus_mode = Control.FOCUS_NONE
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -118.0
	gear.offset_top = 10.0
	gear.offset_right = -10.0
	gear.offset_bottom = 42.0
	gear.modulate = Color(1, 1, 1, 0.8)
	gear.pressed.connect(open)
	root.add_child(gear)

	# The menu itself (hidden until opened).
	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.visible = false
	root.add_child(_menu_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.custom_minimum_size = Vector2(360, 0)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "AUDIO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.55))
	vb.add_child(title)

	_add_slider(vb, "Master")
	_add_slider(vb, "Music")
	_add_slider(vb, "SFX")

	_mute_btn = Button.new()
	_mute_btn.focus_mode = Control.FOCUS_NONE
	_mute_btn.pressed.connect(_on_mute)
	vb.add_child(_mute_btn)

	var resume := Button.new()
	resume.text = "Resume  (Esc)"
	resume.focus_mode = Control.FOCUS_NONE
	resume.pressed.connect(close)
	vb.add_child(resume)


# One labelled volume row: "Master  [=====slider=====]  80%"
func _add_slider(parent: VBoxContainer, bus: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = bus
	name_lbl.custom_minimum_size = Vector2(70, 0)
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(210, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_slider_changed.bind(bus))
	row.add_child(slider)
	_sliders[bus] = slider

	var pct := Label.new()
	pct.custom_minimum_size = Vector2(48, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	_pcts[bus] = pct


func _on_slider_changed(value: float, bus: String) -> void:
	Audio.set_bus_volume(bus, value)
	_pcts[bus].text = "%d%%" % roundi(value * 100.0)


func _on_mute() -> void:
	Audio.toggle_mute()
	Audio.play("select")
	_refresh_mute()


func _refresh_mute() -> void:
	_mute_btn.text = "Muted: ON" if Audio.muted else "Muted: off"


# Pull the current values from the Audio manager into the widgets.
func _refresh() -> void:
	for bus in _sliders:
		_sliders[bus].set_value_no_signal(Audio.get_bus_volume(bus))
		_pcts[bus].text = "%d%%" % roundi(Audio.get_bus_volume(bus) * 100.0)
	_refresh_mute()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	# Don't open over another pause owner (slot machine / game over).
	if _open or get_tree().paused:
		return
	_open = true
	_menu_root.visible = true
	_refresh()
	get_tree().paused = true
	Audio.play("select")


func close() -> void:
	if not _open:
		return
	_open = false
	_menu_root.visible = false
	get_tree().paused = false
