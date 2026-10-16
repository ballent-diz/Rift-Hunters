extends Node2D
## Impact autonome : lancé uniquement à la confirmation d’un contact par le combat.
signal visual_finished
const Shapes = preload("res://assets/vfx/hunter/effects_common.gd")
const TEXTURE = preload("res://assets/vfx/hunter/cleaving_slash/textures/blade-impact.png")
const PALETTE = preload("res://assets/vfx/hunter/cel_paint.gdshader")
@export var destroy_on_finish: bool = true
@export var visual_size: float = 104.0
var _elapsed: float = 0.0
var _playing := false

func _ready() -> void:
	var paint := ShaderMaterial.new()
	paint.shader = PALETTE
	material = paint

func play(direction: Vector2 = Vector2.RIGHT) -> void:
	rotation = direction.angle() if direction.length_squared() > .001 else 0.0
	_elapsed = 0.0
	_playing = true
	queue_redraw()

func duration() -> float:
	return .42

func seek_visual(seconds: float) -> void:
	_elapsed = maxf(seconds,0.0)
	_playing = false
	queue_redraw()

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= duration():
		_playing = false
		visual_finished.emit()
		if destroy_on_finish:
			queue_free()

func _draw() -> void:
	if _elapsed >= duration():
		return
	var p: float = _elapsed/duration()
	var growth: float = .40+.60*(1-pow(1-clampf(p/.13,0.0,1.0),3))
	var stretch: float = 1.0+p*.32
	var width: float = visual_size*growth*stretch
	var alpha: float = 1.0-smoothstep(.25,1.0,p)
	(material as ShaderMaterial).set_shader_parameter("erosion",smoothstep(.27,.96,p)*.9)
	draw_texture_rect(TEXTURE,Rect2(-width*.5,-width*.5,width,width),false,Color(1,1,1,alpha))
	Shapes.burst(self,Vector2.ZERO,_elapsed,.42,26,63,Color("51cce5"),Color("efffff"),.34)
	var shock: float = clampf(_elapsed/.20,0.0,1.0)
	if shock < 1.0:
		draw_set_transform(Vector2(0,20),0,Vector2(1,.36))
		Shapes.ring(self,Vector2.ZERO,7+shock*49,Color(.62,.95,1,(1-shock)*.6),1.8)
		draw_set_transform(Vector2.ZERO)
