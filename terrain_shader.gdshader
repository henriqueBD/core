shader_type canvas_item;
uniform sampler2D source_tex : hint_default_black, filter_nearest;
uniform sampler2D atlas : filter_nearest;
uniform vec2 top_left_world;

//air is transparent
const int atlas_width = 4;
const int atlas_height = 1;
const int num_tiles = 5;
const float tile_side = 32.0;

const vec4 edge_colors[5] = vec4[](
    vec4(0.0, 0.0, 0.0, 0.0),
    vec4(122.0 / 255.0, 71.0/255.0, 53.0 / 255.0, 1),
    vec4(91.0/255.0, 109.0/255.0, 109.0/255.0, 1),
    vec4(1, 254.0/255.0, 161.0/255.0, 1),
    vec4(0.6, 0.3, 0.8, 1)
);

void fragment() {
    // Get the type of the current tile from the red channel of the source texture.
    int tile_type = int(floor(texture(source_tex, UV).r * 255.0));

	if (tile_type == 0){
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
	else if (tile_type >= num_tiles) {
		COLOR = vec4(1.0, 0.0, 1.0, 1.0);
	}
	else{
	    // Get the size of a single pixel in UV coordinates. This is a built-in Godot variable.
	    vec2 pixel_size = TEXTURE_PIXEL_SIZE;

	    // Sample the texture for the four cardinal neighbors (top, bottom, left, right).
	    int top_neighbor = int(floor(texture(source_tex, UV + vec2(0.0, -pixel_size.y)).r * 255.0));
	    int bottom_neighbor = int(floor(texture(source_tex, UV + vec2(0.0, pixel_size.y)).r * 255.0));
	    int left_neighbor = int(floor(texture(source_tex, UV + vec2(-pixel_size.x, 0.0)).r * 255.0));
	    int right_neighbor = int(floor(texture(source_tex, UV + vec2(pixel_size.x, 0.0)).r * 255.0));

	    // Check if any neighbor has a different type than the current tile.
	    bool has_different_neighbor = (tile_type != top_neighbor) ||
	                                  (tile_type != bottom_neighbor) ||
	                                  (tile_type != left_neighbor) ||
	                                  (tile_type != right_neighbor);

	    // If it has a different neighbor, use the edge color.
	    if (has_different_neighbor) {
	        COLOR = edge_colors[tile_type];
	    } else {
			vec2 atlas_tile_uv_offset = vec2(
			    float((tile_type - 1) % atlas_width) * tile_side,
			    float((tile_type - 1) / atlas_width) * tile_side
			);

			// Convert to UV coordinates (0-1 range)
			vec2 atlas_tile_uv = (UV * tile_side + atlas_tile_uv_offset) / vec2(textureSize(atlas, 0));

			// Sample from the atlas
			COLOR = texture(atlas, atlas_tile_uv);
	    }
	}
}