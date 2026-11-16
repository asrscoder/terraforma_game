// Boat ports are drawn in two pieces: an upright shoreline house that never
// rotates, and a pier/deck that points into the water. Rotating a whole hut
// is what made early ports look collapsed, so only the pier is ever rotated.
if (building_type == "boat_port")
{
    var _gx  = footprint_left;
    var _gy  = footprint_top;
    var _dir = port_dir;

    if (state == "construction")
    {
        // A generic scaffold, kept upright on the land half.
        var _site = scr_construction_sprite(building_type);
        var _pos  = scr_port_house_anchor(
            _dir, _gx, _gy,
            sprite_get_width(_site), sprite_get_height(_site)
        );

        draw_sprite_ext(_site, image_index, _pos[0], _pos[1], 1, 1, 0, c_white, 1);
        exit;
    }

    // Pier first (it sits in the water), then the house on top of the shore.
    var _pier     = scr_get_port_pier_sprite(level);
    var _pier_pos = scr_port_pier_anchor(_dir, _gx, _gy);
    var _angle    = scr_port_dir_angle(_dir);

    var _tex_filter = gpu_get_tex_filter();
    if (_angle != 0) gpu_set_tex_filter(false);
    draw_sprite_ext(_pier, image_index, _pier_pos[0], _pier_pos[1], 1, 1, _angle, c_white, 1);
    if (_angle != 0) gpu_set_tex_filter(_tex_filter);

    var _house = scr_get_building_sprite(building_type, level, false);
    if (_house != -1)
    {
        var _house_pos = scr_port_house_anchor(
            _dir, _gx, _gy,
            sprite_get_width(_house), sprite_get_height(_house)
        );

        draw_sprite_ext(_house, image_index, _house_pos[0], _house_pos[1], 1, 1, 0, c_white, 1);
    }
    exit;
}

if (state == "construction")
{
    draw_self();
    exit;
}

var _body = scr_get_building_sprite(building_type, level, false);
var _roof = scr_get_building_sprite(building_type, level, true);

if (_body == -1)
{
    draw_self();
    exit;
}

// Kingdom color for roof tinting
var _kcol = c_white;
if (village_id != -1)
{
    var _k_id = global.villages[village_id].kingdom_id;
    if (_k_id != -1 && _k_id < array_length(global.kingdoms))
    {
        _kcol = global.kingdoms[_k_id].color;
    }
}

// Body
draw_sprite_ext(_body, image_index, x, y, image_xscale, 1, 0, c_white, 1);

// Roof (tinted with kingdom color)
if (_roof != -1)
{
    draw_sprite_ext(_roof, image_index, x, y, image_xscale, 1, 0, _kcol, 1);
}
