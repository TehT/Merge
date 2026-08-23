@tool
extends EditorScript

## The exact colors from your legend, in a specific order.
const KOPPEN_PALETTE: Array[Color] = [
	Color("#0000ff"), # 0: Af (Tropical Rainforest)
	Color("#0077ff"), # 1: Am (Tropical Monsoon)
	Color("#44aaff"), # 2: Aw (Tropical Savanna)
	Color("#ff0000"), # 3: BWh (Hot Desert)
	Color("#ff9696"), # 4: BWk (Cold Desert)
	Color("#f5a500"), # 5: BSh (Hot Semi-Arid / Steppe)
	Color("#ffdb58"), # 6: BSk (Cold Semi-Arid / Steppe)
	Color("#ffff00"), # 7: Csa (Hot-Summer Mediterranean)
	Color("#c8c800"), # 8: Csb (Warm-Summer Mediterranean)
	Color("#969600"), # 9: Csc (Cold-Summer Mediterranean)
	Color("#96ff96"), # 10: Cwa (Dry-Winter Humid Subtropical)
	Color("#64c864"), # 11: Cwb (Dry-Winter Subtropical Highland)
	Color("#329632"), # 12: Cwc (Dry-Winter Subpolar Oceanic)
	Color("#ff00ff"), # 13: Dsa (Hot-Summer Mediterranean Continental)
	Color("#c800c8"), # 14: Dsb (Warm-Summer Mediterranean Continental)
	Color("#963296"), # 15: Dsc (Subarctic Mediterranean)
	Color("#966496"), # 16: Dsd (Extremely Cold Subarctic Mediterranean)
	Color("#abb8ff"), # 17: Dwa (Monsoon-Influenced Hot-Summer Humid Continental)
	Color("#5a77db"), # 18: Dwb (Monsoon-Influenced Warm-Summer Humid Continental)
	Color("#4c51b5"), # 19: Dwc (Monsoon-Influenced Subarctic)
	Color("#320087"), # 20: Dwd (Monsoon-Influenced Extremely Cold Subarctic)
	Color("#00ffff"), # 21: Dfa (Hot-Summer Humid Continental)
	Color("#38c8ff"), # 22: Dfb (Warm-Summer Humid Continental)
	Color("#007d7d"), # 23: Dfc (Subarctic)
	Color("#00465f"), # 24: Dfd (Extremely Cold Subarctic)
	Color("#b2b2b2"), # 25: ET (Tundra)
	Color("#666666")  # 26: EF (Ice Cap)
]

func _run() -> void:
	var source_path := "C:/Users/tords/Documents/project/textures/biome_mask.png" # Update this
	var output_path := "C:/Users/tords/Documents/project/textures/biome_index_mask.png" # Update this
	
	var source_image := Image.load_from_file(source_path)
	if source_image == null:
		push_error("Failed to load source image.")
		return
		
	var width := source_image.get_width()
	var height := source_image.get_height()
	var index_image := Image.create(width, height, false, Image.FORMAT_R8)
	
	for y in range(height):
		for x in range(width):
			var pixel_color := source_image.get_pixel(x, y)
			
			# Fast check for pure black (Ocean), mapped to 255 to keep it out of the 0-26 range
			if pixel_color.r < 0.15 and pixel_color.g < 0.15 and pixel_color.b < 0.15:
				index_image.set_pixel(x, y, Color(255.0 / 255.0, 0.0, 0.0, 1.0))
				continue
			
			var closest_index := 0
			var min_dist := 1000.0
			
			for i in range(KOPPEN_PALETTE.size()):
				var r_diff = pixel_color.r - KOPPEN_PALETTE[i].r
				var g_diff = pixel_color.g - KOPPEN_PALETTE[i].g
				var b_diff = pixel_color.b - KOPPEN_PALETTE[i].b
				var dist = r_diff * r_diff + g_diff * g_diff + b_diff * b_diff
				
				if dist < min_dist:
					min_dist = dist
					closest_index = i
					
			var normalized_id = float(closest_index) / 255.0
			index_image.set_pixel(x, y, Color(normalized_id, 0.0, 0.0, 1.0))
			
	index_image.save_png(output_path)
	print("Index map baked successfully!")
