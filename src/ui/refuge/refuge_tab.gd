class_name RefugeTab
extends MarginContainer
## Onglet du Refuge. Chaque onglet est autonome : ajouter un onglet = créer une sous-classe et l'enregistrer.

var refuge: Refuge
var _scroll_restore: Callable


func title_key() -> String:
	return ""


func setup(p_refuge: Refuge) -> void:
	refuge = p_refuge
	add_theme_constant_override("margin_left", 16)
	add_theme_constant_override("margin_right", 16)
	add_theme_constant_override("margin_top", 12)
	add_theme_constant_override("margin_bottom", 12)


## Reconstruit le contenu à partir du profil (appelé à l'ouverture et après chaque changement).
func refresh() -> void:
	pass


func profile() -> ProfileData:
	return Profile.profile


## Contenu défilant de l'onglet. Reconstruire l'onglet (après un clic) garde la position de défilement.
func scroll_box(separation: int = 8) -> VBoxContainer:
	var previous: int = 0
	for child: Node in get_children():
		if child is ScrollContainer:
			previous = (child as ScrollContainer).scroll_vertical
	UiKit.clear(self)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	scroll.add_child(box)
	if previous > 0:
		# La hauteur du contenu n'est connue qu'après la mise en page : on replace la barre dès que sa plage change.
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		_scroll_restore = _restore_scroll.bind(bar, previous)
		bar.changed.connect(_scroll_restore)
	return box


## Tant que la mise en page n'est pas finie, la plage est partielle et la valeur serait rabotée : on réessaie.
func _restore_scroll(bar: VScrollBar, value: int) -> void:
	bar.value = value
	if bar.page > 0.0 and bar.max_value - bar.page >= value and bar.changed.is_connected(_scroll_restore):
		bar.changed.disconnect(_scroll_restore)
