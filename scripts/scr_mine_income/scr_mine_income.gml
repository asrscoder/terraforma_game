/// @func scr_tick_mine_income()
/// @desc Advances a per-building income clock for completed era-2+ mines.
///       Every 30 s each mine adds 10 stone and 3 iron to the village that
///       owns it, clamped to that village's caps (same rule as harvesting).
///       Call from obj_world Step.
function scr_tick_mine_income()
{
    if (global.is_paused) return;

    with (obj_building)
    {
        if (building_type != "mine") continue;
        if (state != "complete")     continue;
        if (level < 2)               continue;
        if (village_id < 0 || village_id >= array_length(global.villages)) continue;

        mine_income_timer++;
        if (mine_income_timer < 30 * 60) continue;
        mine_income_timer = 0;

        var _v = global.villages[village_id];
        _v.resources.stone = min(_v.resource_caps.stone, _v.resources.stone + 10);
        _v.resources.iron  = min(_v.resource_caps.iron,  _v.resources.iron  +  3);
        global.villages[village_id] = _v;
    }
}
