class_name Projectile
extends RefCounted
## Projectile léger (pas un nœud) : mis à jour et dessiné par ProjectileManager.

var friendly: bool = true
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var info: DamageInfo
var hostile_damage: float = 0.0
## Tir ennemi entravant (toile de suie) : durée et multiplicateur de vitesse du Chasseur touché.
var hinder_time: float = 0.0
var hinder_mult: float = 1.0
var source_id: StringName = &""
var pierce_left: int = 0
var split: int = 0
var chain: int = 0
var homing: float = 0.0
var target: Enemy
var life: float = 1.5
var radius: float = 6.0
var color := Color.WHITE
var hit_ids: Dictionary = {}
