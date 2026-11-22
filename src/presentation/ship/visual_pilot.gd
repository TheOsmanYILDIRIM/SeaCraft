extends RefCounted

const SHIP_SPRITE := preload("res://src/presentation/ship/pilot_atlas_sprite.gd")
const WATER_SHADER := preload("res://src/presentation/ship/pilot_water.gdshader")
const RUNTIME := "res://src/presentation/ship/pilot_atlases/"


static func mount_atlas(parent: Node2D, ship_id: String, cell_world_size: float) -> Sprite2D:
	var path := RUNTIME + ship_id + ".png"
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var texture := load(path) as Texture2D
	if texture == null or texture.get_width() * 2 != texture.get_height() * 4 or texture.get_height() % 2 != 0:
		push_error("Invalid visual pilot atlas: " + ship_id)
		return null
	var sprite := SHIP_SPRITE.new()
	sprite.name = ship_id
	sprite.texture = texture
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * (cell_world_size / (texture.get_height() * 0.5))
	parent.add_child(sprite)
	sprite.bind_heading(parent)
	return sprite


static func water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	return material
