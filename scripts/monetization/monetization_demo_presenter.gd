class_name MonetizationDemoPresenter
extends CanvasLayer

const DEMO_VIDEO_PATH := "res://assets/video/demo_ad_4s.ogv"

var _banner: Panel
var _fullscreen: ColorRect
var _video: VideoStreamPlayer
var _demo_video: VideoStream
var _finished_callback: Callable


func _ready() -> void:
	layer = 100
	_demo_video = load(DEMO_VIDEO_PATH) as VideoStream
	if _demo_video == null:
		push_error("Monetization demo video is unavailable: %s" % DEMO_VIDEO_PATH)
	_create_banner()
	_create_fullscreen()


func set_banner_visible(should_show: bool) -> void:
	_banner.visible = should_show


func show_interstitial(on_finished: Callable) -> void:
	if _fullscreen.visible or _demo_video == null:
		if _demo_video == null and on_finished.is_valid():
			on_finished.call()
		return
	_finished_callback = on_finished
	_fullscreen.visible = true
	_video.stream = _demo_video
	_video.play()


func _create_banner() -> void:
	_banner = Panel.new()
	_banner.name = "DemoBanner"
	_banner.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_banner.offset_top = -150.0
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_banner.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f6c849")
	style.border_color = Color("#4d1734")
	style.set_border_width_all(6)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	_banner.add_theme_stylebox_override("panel", style)
	add_child(_banner)

	var label := Label.new()
	label.text = "ТЕСТОВЫЙ РЕКЛАМНЫЙ БАННЕР\nнижний рекламный слот"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("#4d1734"))
	_banner.add_child(label)


func _create_fullscreen() -> void:
	_fullscreen = ColorRect.new()
	_fullscreen.name = "DemoInterstitial"
	_fullscreen.color = Color("#090512")
	_fullscreen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fullscreen.mouse_filter = Control.MOUSE_FILTER_STOP
	_fullscreen.visible = false
	add_child(_fullscreen)

	_video = VideoStreamPlayer.new()
	_video.name = "Video"
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.expand = true
	_video.finished.connect(_finish_interstitial)
	_fullscreen.add_child(_video)

	var badge := Label.new()
	badge.text = "ТЕСТОВАЯ РЕКЛАМА • 4 СЕК"
	badge.position = Vector2(24, 24)
	badge.add_theme_font_size_override("font_size", 26)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 5)
	_fullscreen.add_child(badge)


func _finish_interstitial() -> void:
	_video.stop()
	_fullscreen.visible = false
	var callback := _finished_callback
	_finished_callback = Callable()
	if callback.is_valid():
		callback.call()
