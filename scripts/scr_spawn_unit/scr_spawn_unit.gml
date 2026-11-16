/// @func scr_spawn_unit(_gx, _gy, _type)
/// @desc Spawns a unit at the given grid tile.
///        Rules:
///          - Terrain must match the type's unit class: land units need dry
///            land, water units (ships) need ocean, air units ignore terrain
///          - Blocked tiles → rejected
///          - Inside a village → joins that village
///          - Otherwise → spawns unaffiliated
///        Returns the instance id, or noone if the tile is invalid.
function scr_spawn_unit(_gx, _gy, _type = "villager")
{
    var _w = obj_world.world_width;
    var _h = obj_world.world_height;

    // Bounds check
    if (_gx < 0 || _gx >= _w) return noone;
    if (_gy < 0 || _gy >= _h) return noone;

    var _idx   = _gx + _gy * _w;
    var _class = scr_unit_class_for_type(_type);

    // Terrain class gate. Land units need dry land, water units need ocean
    // (ships), air units ignore terrain entirely.
    if (!scr_terrain_ok_for_class(_class, obj_world.terrain_grid[_idx] == TERRAIN.WATER))
        return noone;

    if (obj_world.block_grid[_idx] == 1) return noone;

    // Find which village (if any) contains the tile
    var _target_village_id = -1;
    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        var _v = global.villages[_i];
        if (scr_tile_in_union(_v, _gx, _gy))
        {
            _target_village_id = _v.id;
            break;
        }
    }
	
    // Miners need a village stockpile. If there is no village here,
    // spawn a plain villager instead of an invalid unaffiliated miner.
    if (_target_village_id == -1 && _type == "miner")
    {
        _type = "villager";
    }

    // === Create the unit ===
    var _unit = instance_create_depth(
        _gx * obj_world.tile_size,
        _gy * obj_world.tile_size,
        DEPTH.UNITS,
        obj_unit
    );

    _unit.grid_x = _gx;
    _unit.grid_y = _gy;
    _unit.x      = _gx * obj_world.tile_size;
    _unit.y      = _gy * obj_world.tile_size;

    // === Affiliation (assigned before the type setup so era-specific art —
    //     e.g. the ship — can be picked from the unit's kingdom) ===
    if (_target_village_id != -1)
    {
        // Spawned inside a village — assign to it
        scr_assign_unit_to_village(_unit, _target_village_id);
    }
    else
    {
        // Spawned on free land / open water — unaffiliated
        _unit.village_id = -1;
        _unit.kingdom_id = -1;
        _unit.is_hostile = true;
    }

    scr_apply_unit_type(_unit, _type);

    return _unit;
}