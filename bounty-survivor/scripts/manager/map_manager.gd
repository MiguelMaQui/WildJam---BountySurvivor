extends Node2D

@export var player: Node2D
@export var ground_layer: TileMapLayer
@export var details_layer: TileMapLayer
@export var objects_layer: TileMapLayer

var chunk_size := 16 
var render_distance := 2 
var loaded_chunks := {} 

var noise = FastNoiseLite.new()

# --- LISTAS DE VARIEDAD ---
var ground_tiles = [Vector2i(2, 2)] 
var detail_tiles = [Vector2i(1, 4), Vector2i(4, 4), Vector2i(9, 4), Vector2i(1, 6), Vector2i(9, 6), Vector2i(3, 6), Vector2i(11, 6)] 
var rock_and_stump_tiles = [Vector2i(1, 7), Vector2i(5, 13), Vector2i(5, 8), Vector2i(8, 13), Vector2i(1, 17), Vector2i(11, 17), Vector2i(13, 17), Vector2i(1, 12), Vector2i(11, 14)] 
var tree_tiles = [Vector2i(1, 15), Vector2i(1, 1), Vector2i(1, 9)] 

func _ready() -> void:
	noise.seed = randi()
	noise.frequency = 0.15 

func _process(_delta: float) -> void:
	if player == null: return
	
	var player_tile_pos = ground_layer.local_to_map(player.global_position)
	var p_chunk_x = floor(player_tile_pos.x / float(chunk_size))
	var p_chunk_y = floor(player_tile_pos.y / float(chunk_size))
	var current_chunk = Vector2i(p_chunk_x, p_chunk_y)
	
	_load_chunks_around(current_chunk)
	_unload_distant_chunks(current_chunk)

func _load_chunks_around(center_chunk: Vector2i) -> void:
	for x in range(center_chunk.x - render_distance, center_chunk.x + render_distance + 1):
		for y in range(center_chunk.y - render_distance, center_chunk.y + render_distance + 1):
			var chunk = Vector2i(x, y)
			if not loaded_chunks.has(chunk):
				_generate_chunk(chunk)

func _generate_chunk(chunk: Vector2i) -> void:
	loaded_chunks[chunk] = true
	
	for x in range(chunk_size):
		for y in range(chunk_size):
			var tile_x = chunk.x * chunk_size + x
			var tile_y = chunk.y * chunk_size + y
			var coords = Vector2i(tile_x, tile_y)
			
			# --- CAPA 1: SUELO (ID 0) ---
			ground_layer.set_cell(coords, 0, ground_tiles.pick_random()) 
			
			var n_val = noise.get_noise_2d(tile_x, tile_y)
			
			# --- CAPA 2: OBJETOS CON COLISIÓN (ID 1 o ID 2) ---
			if n_val > 0.4:
				# EL TRUCO DE ESPACIADO: Solo generamos en coordenadas que sean múltiplo de 3
				if tile_x % 2 == 0 and tile_y % 2 == 0:
					if randf() > 0.2: # Probabilidad alta porque ya filtramos muchos bloques
						if randf() > 0.5:
							objects_layer.set_cell(coords, 1, rock_and_stump_tiles.pick_random()) 
						else:
							objects_layer.set_cell(coords, 2, tree_tiles.pick_random()) 
			
			# --- CAPA 3: DETALLES VISUALES (ID 3) ---
			elif n_val > 0.1 and n_val < 0.3:
				if randf() > 0.8: 
					details_layer.set_cell(coords, 3, detail_tiles.pick_random())

func _unload_distant_chunks(center_chunk: Vector2i) -> void:
	var chunks_to_remove = []
	for chunk in loaded_chunks.keys():
		var dist_x = abs(chunk.x - center_chunk.x)
		var dist_y = abs(chunk.y - center_chunk.y)
		if dist_x > render_distance + 1 or dist_y > render_distance + 1:
			chunks_to_remove.append(chunk)
			
	for chunk in chunks_to_remove:
		_clear_chunk(chunk)
		loaded_chunks.erase(chunk)

func _clear_chunk(chunk: Vector2i) -> void:
	for x in range(chunk_size):
		for y in range(chunk_size):
			var coords = Vector2i(chunk.x * chunk_size + x, chunk.y * chunk_size + y)
			ground_layer.erase_cell(coords)
			details_layer.erase_cell(coords)
			objects_layer.erase_cell(coords)
