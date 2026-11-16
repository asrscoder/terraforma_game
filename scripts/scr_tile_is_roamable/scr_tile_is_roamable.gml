/// @func scr_terrain_ok_for_class(_class, _is_water)
/// @desc Terrain half of the movement gate: may a unit of _class occupy a
///       tile with the given water-ness? Water units are the mirror image of
///       land units — they need ocean and refuse land. Air units ignore it.
function scr_terrain_ok_for_class(_class, _is_water)
{
    switch (_class)
    {
        case "water": return _is_water;
        case "air":   return true;
        default:      return !_is_water;   // "land"
    }
}

/// scr_tile_is_roamable(unit, gx, gy, allow_resource = false)
/// @desc Physical terrain check. Land units refuse water, water units refuse
///       land (ships), air units ignore terrain. Blocked tiles stop everyone;
///       only resource tiles on land can be excused for the relevant units.
function scr_tile_is_roamable(_unit, _gx, _gy, _allow_resource = false)
{
    if (_gx < 0 || _gx >= obj_world.world_width)  return false;
    if (_gy < 0 || _gy >= obj_world.world_height) return false;

    var _idx      = _gx + _gy * obj_world.world_width;
    var _is_water = (obj_world.terrain_grid[_idx] == TERRAIN.WATER);

    if (!scr_terrain_ok_for_class(_unit.unit_class, _is_water)) return false;

    if (obj_world.block_grid[_idx] == 1)
    {
        if (!_allow_resource) return false;

        // Only resource tiles are excusable
        var _res = obj_world.resource_grid[_idx];
        if (_res != RESOURCE.TREE && _res != RESOURCE.STONE && _res != RESOURCE.IRON) return false;
    }

    return true;
}
