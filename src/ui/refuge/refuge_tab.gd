class_name RefugeTab
extends MarginContainer
## Onglet du Refuge. Chaque onglet est autonome : ajouter un onglet = créer une sous-classe et l'enregistrer.

var refuge: Refuge


func title_key() -> String:
	return ""


## true : il y a quelque chose à faire ici (repère « ● » sur l'onglet).
func needs_attention() -> bool:
	return false


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


## Contenu défilant de l'onglet. Reconstruire l'onglet (après un clic) garde la position de défilement (UiKit.clear).
func scroll_box(separation: int = 8) -> VBoxContainer:
	UiKit.clear(self)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	scroll.add_child(box)
	return box
