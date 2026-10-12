class_name VisualData
extends Resource
## Apparence d'une entité : identifiant d'asset (manifeste) + description du placeholder.

enum Shape {
	HUNTER, BLADE_BEAST, MONOLITH, MOTH, SKITTER, SHELL, SPITTER, LUNGER,
	DEVOURER, ORB, CRYSTAL, CHEST, GEM, BLOB,
	VINE, WISP, MAW, MIRROR, BROOD, SHADE, WARDEN, COLOSSUS,
}

## Clé dans assets/asset_manifest.json (ex. &"monster.ashblade").
@export var visual_id: StringName = &""
@export var shape: Shape = Shape.BLOB
## Diamètre approximatif du placeholder en pixels.
@export var size: float = 32.0
@export var primary: Color = Color(0.6, 0.6, 0.7)
@export var secondary: Color = Color(0.3, 0.3, 0.4)
@export var accent: Color = Color(1, 1, 1)
