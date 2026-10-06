extends CanvasLayer

signal exit_requested
signal purchase_requested

var _message: Label
var _purchase: Button
var _exit: Button

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.08, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	shade.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 720
	content.add_theme_constant_override("separation", 36)
	center.add_child(content)
	_message = Label.new()
	_message.text = "Реклама недоступна. Возможно, включён блокировщик рекламы или возникла ошибка сети.\n\nЧтобы продолжить, отключите рекламу покупкой."
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 40)
	content.add_child(_message)
	_purchase = Button.new()
	_purchase.text = "Отключить рекламу"
	_purchase.custom_minimum_size.y = 110
	_purchase.add_theme_font_size_override("font_size", 38)
	_purchase.pressed.connect(func() -> void: purchase_requested.emit())
	content.add_child(_purchase)
	_exit = Button.new()
	_exit.text = "Выход"
	_exit.custom_minimum_size.y = 110
	_exit.add_theme_font_size_override("font_size", 38)
	_exit.pressed.connect(func() -> void: exit_requested.emit())
	content.add_child(_exit)

func set_purchase_available(available: bool, price: String) -> void:
	_purchase.disabled = not available
	_purchase.text = "Отключить рекламу" + (" · " + price if not price.is_empty() else "")

func set_pending() -> void:
	_purchase.disabled = true
	_exit.disabled = true
	_message.text = "Ожидание подтверждения покупки…"

func show_purchase_failure() -> void:
	_exit.disabled = false
	_message.text = "Покупка отменена или не подтверждена. Реклама остаётся включённой.\n\nПовторите покупку или вернитесь в главное меню."
