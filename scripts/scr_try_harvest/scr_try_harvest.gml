/// @func scr_try_harvest(_unit)
/// @desc Ticks the harvest timer if the miner is at the target tile.
///       On completion, adds resources to the village and clears the tile.
///       Returns true when the harvest completes this tick.
function scr_try_harvest(_unit)
{
    if (_unit.harvest_target_x == -1) return false;

    if (_unit.grid_x != _unit.harvest_target_x
     || _unit.grid_y != _unit.harvest_target_y)
    {
        _unit.harvest_timer = 0;
        return false;
    }

    _unit.harvest_timer++;

    if (_unit.harvest_timer < _unit.harvest_required) return false;

    var _idx = _unit.harvest_target_x + _unit.harvest_target_y * obj_world.world_width;
    var _res = obj_world.resource_grid[_idx];

    if (_unit.village_id != -1)
    {
        var _v = global.villages[_unit.village_id];

        if (_res == RESOURCE.TREE)
        {
            _v.resources.wood = min(_v.resource_caps.wood, _v.resources.wood + irandom_range(1, 4));
            scr_resource_harvested(_idx, _res);
        }
        else if (_res == RESOURCE.STONE)
        {
            _v.resources.stone = min(_v.resource_caps.stone, _v.resources.stone + irandom_range(1, 4));
            scr_resource_harvested(_idx, _res);
        }
        else if (_res == RESOURCE.IRON)
        {
            _v.resources.iron = min(_v.resource_caps.iron, _v.resources.iron + irandom_range(1, 3));
            scr_resource_harvested(_idx, _res);
        }

        global.villages[_unit.village_id] = _v;
    }

    _unit.harvest_target_x = -1;
    _unit.harvest_target_y = -1;
    _unit.harvest_timer    = 0;
    return true;
}