/// @func scr_find_harvest_target(_unit)
/// @desc Picks the nearest harvestable resource tile for a miner.
///
///       The search is an expanding ring around the miner, so the cost is
///       proportional to the distance to the nearest match (typically a few
///       hundred tiles) instead of the whole search box. The previous version
///       always scanned 201 x 201 = 40,401 tiles, per miner, per retarget.
///
///       Targets are still kept near the village and away from other
///       kingdoms' territory. Within the first ring that has any candidate one
///       is picked at random, so miners spread out instead of all converging
///       on the single closest tile.
///
///       Returns true and sets harvest_target_x/y on success.
function scr_find_harvest_target(_unit)
{
    if (_unit.village_id == -1) return false;

    var _v = global.villages[_unit.village_id];

    // === Determine which resource type to target ===
    var _wood_full  = (_v.resources.wood  >= _v.resource_caps.wood);
    var _stone_full = (_v.resources.stone >= _v.resource_caps.stone);
    var _iron_full  = (_v.resources.iron  >= _v.resource_caps.iron);

    // Iron is locked until the kingdom reaches era 2. Era-1 miners therefore
    // never consider it, even when the stockpile is below its cap.
    var _can_mine_iron = scr_kingdom_can_mine_iron(_v.kingdom_id);

    // Collect the resources that still need topping up.
    var _want = [];
    if (!_wood_full)  array_push(_want, RESOURCE.TREE);
    if (!_stone_full) array_push(_want, RESOURCE.STONE);
    if (!_iron_full && _can_mine_iron) array_push(_want, RESOURCE.IRON);

    if (array_length(_want) == 0) return false;

    // Pick one needed resource type at random per attempt.
    var _target_res = _want[irandom(array_length(_want) - 1)];

    // === Search limits (tune these two) ===
    // _search_r      ring walk radius around the miner.
    // _area_r        max distance from the village centre, so miners do not
    //                slowly drift across the island after every harvest.
    var _search_r = 60;
    var _area_r   = max(
        60,
        max(abs(_v.cx - _v.left), abs(_v.cx - _v.right),
            abs(_v.cy - _v.top),  abs(_v.cy - _v.bottom)) + 30
    );

    var _grid = obj_world.resource_grid;
    var _w    = obj_world.world_width;
    var _h    = obj_world.world_height;

    var _best_x = -1;
    var _best_y = -1;

    // === Expanding-ring search: stop at the first ring with a candidate ===
    // Inside each ring a candidate is chosen by reservoir sampling, so miners
    // spread out instead of all converging on the single closest tile — and no
    // per-ring array has to be allocated.
    for (var _r = 0; _r <= _search_r; _r++)
    {
        var _found = 0;
        var _pick  = -1;

        var _y0 = max(0,      _unit.grid_y - _r);
        var _y1 = min(_h - 1, _unit.grid_y + _r);
        var _x0 = max(0,      _unit.grid_x - _r);
        var _x1 = min(_w - 1, _unit.grid_x + _r);

        for (var _ty = _y0; _ty <= _y1; _ty++)
        {
            for (var _tx = _x0; _tx <= _x1; _tx++)
            {
                // Only the outside edge of the box belongs to this ring.
                if (max(abs(_tx - _unit.grid_x), abs(_ty - _unit.grid_y)) != _r) continue;

                if (_grid[_tx + _ty * _w] != _target_res) continue;

                // Skip the resource we already gave up on (avoids an infinite
                // retry loop on an unreachable / repeatedly-failed tile).
                if (_tx == _unit.harvest_failed_x && _ty == _unit.harvest_failed_y) continue;

                // Keep the target near this village.
                if (max(abs(_tx - _v.cx), abs(_ty - _v.cy)) > _area_r) continue;

                // Skip resources in other kingdoms' territory.
                if (scr_tile_in_other_kingdom(_tx, _ty, _unit.kingdom_id)) continue;

                _found++;
                if (irandom(_found - 1) == 0) _pick = _tx + _ty * _w;
            }
        }

        if (_pick == -1) continue;

        _best_x = _pick mod _w;
        _best_y = _pick div _w;
        break;
    }

    if (_best_x == -1)
    {
        // Nothing usable nearby — clear the failed tile so we retry
        // previously-failed tiles next time instead of locking out forever.
        _unit.harvest_failed_x = -1;
        _unit.harvest_failed_y = -1;
        return false;
    }

    // === Reachability check ===
    // Only for distant targets: anything a few tiles away is almost always
    // walkable, and the harvest_retries counter in scr_ai_miner abandons the
    // rare enclosed pocket. Skipping the check for close targets keeps an A*
    // search out of the common retargeting path.
    var _dist = max(abs(_best_x - _unit.grid_x), abs(_best_y - _unit.grid_y));

    if (_dist > 6)
    {
        var _path = scr_find_path(_unit.grid_x, _unit.grid_y, _best_x, _best_y, true);
        if (array_length(_path) == 0)
        {
            _unit.harvest_failed_x = _best_x;
            _unit.harvest_failed_y = _best_y;
            return false;
        }
    }

    _unit.harvest_target_x = _best_x;
    _unit.harvest_target_y = _best_y;
    _unit.harvest_timer    = 0;
    return true;
}
