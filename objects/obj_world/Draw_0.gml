//Camera
var cam = view_camera[0];

var cam_x = camera_get_view_x(cam);
var cam_y = camera_get_view_y(cam);

var cam_width = camera_get_view_width(cam);
var cam_height = camera_get_view_height(cam);

//Calculate visible tile range
var start_x = max(0, floor(cam_x / tile_size));
var start_y = max(0, floor(cam_y / tile_size));

var end_X = min(
	world_width, 
	ceil((cam_x+cam_width) / tile_size) + 1);
var end_y = min(
	world_height,
	ceil((cam_y + cam_height) /tile_size) + 1);

// Frame counts are cached in Create (terrain_frame_count) and the animation
// phase is resolved once per frame, so the tile loop is two array reads and a
// mod instead of a sprite_get_number() call per tile.
var _phase = floor(anim_timer);

//Draw only visible tiles
for(var tile_y = start_y; tile_y < end_y; tile_y++)
{
	for(var tile_x = start_x; tile_x < end_X; tile_x++)
	{
		var index = tile_x + tile_y * world_width;
		var terrain = terrain_grid[index];
		
		var _spr = terrain_sprite[terrain];
		var _frame = _phase mod terrain_frame_count[terrain];
		
		draw_sprite(
			_spr,
			_frame,
			tile_x * tile_size,
			tile_y * tile_size
		);
	}
}
