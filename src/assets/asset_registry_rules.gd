class_name AssetRegistryRules
extends RefCounted
## Animations minimales attendues par catégorie d'asset (voir docs/ASSET_PIPELINE.md).

const REQUIRED := {
	"player": ["idle", "move", "dash", "hurt", "death"],
	"monster": ["idle", "move", "attack", "technique"],
	"enemy": ["move", "death"],
	"boss": ["idle", "move", "attack", "death"],
}


static func required_animations(category: String) -> Array:
	return REQUIRED.get(category, [])
