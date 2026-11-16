/// @func scr_process_expansion_requests()
/// @desc For each kingdom whose capital requests expansion: pick 10 spare
///       villagers as colonists, choose a leader FROM those colonists, choose
///       a free spot outside the capital's territory, detach the colonists and
///       start a rally toward that spot.
function scr_process_expansion_requests()
{
    var _min_villagers = 10;

    for (var _k = 0; _k < array_length(global.kingdoms); _k++)
    {
        var _kingdom = global.kingdoms[_k];
        if (_kingdom.expansion_rally_active) continue;

        var _cap_id = _kingdom.capital_village_id;
        if (_cap_id == -1 || _cap_id >= array_length(global.villages)) continue;

        var _cap = global.villages[_cap_id];
        if (!_cap.expansion_request) continue;

        // Re-check the child-village cap at the moment the rally starts.
        // The request may have been set before a previous child finished,
        // so never trust the request alone.
        var _max_children = scr_era_max_child_villages(_kingdom.advancement_level);
        var _current_children = array_length(_kingdom.village_ids) - 1;
        if (_current_children >= _max_children)
        {
            _cap.expansion_request = false;
            global.villages[_cap_id] = _cap;
            continue;
        }

        var _spare = [];
        for (var _mi = 0; _mi < array_length(_cap.member_ids); _mi++)
        {
            var _u = _cap.member_ids[_mi];
            if (instance_exists(_u) && _u.unit_type == "villager" && !_u.is_leader)
                array_push(_spare, _u);
        }

        if (array_length(_spare) < _min_villagers)
        {
            _cap.expansion_request = false;
            global.villages[_cap_id] = _cap;
            continue;
        }

        // Colonists = first N spare villagers; leader = lowest id AMONG THEM
        var _colonists = [];
        for (var _i = 0; _i < _min_villagers; _i++) array_push(_colonists, _spare[_i]);

        var _leader = _colonists[0];
        for (var _i = 1; _i < array_length(_colonists); _i++)
            if (_colonists[_i].id < _leader.id) _leader = _colonists[_i];

        // Choose the child village's location now. The old "leader picks the
        // spot later" step no longer exists, so without this the rally stayed
        // at (-1, -1) forever and timed out.
        var _spot = scr_find_expansion_spot(_cap, _leader);
        if (_spot[0] == -1)
        {
            // No free/reachable land nearby. Clear the request so it can be
            // retried later instead of detaching colonists for nothing.
            scr_debug_log("Expansion fail for " + string(_cap_id) + ": No reachable free spot.");
            _cap.expansion_request = false;
            global.villages[_cap_id] = _cap;
            continue;
        }

        _kingdom.expansion_rally_active      = true;
        _kingdom.expansion_rally_x           = _spot[0];
        _kingdom.expansion_rally_y           = _spot[1];
        _kingdom.expansion_rally_age         = 0;
        _kingdom.expansion_source_village_id = _cap_id;
        global.kingdoms[_k] = _kingdom;

        var _new_members = [];
        for (var _ci = 0; _ci < array_length(_cap.member_ids); _ci++)
        {
            var _uid = _cap.member_ids[_ci];

            var _is_colonist = false;
            for (var _si = 0; _si < array_length(_colonists); _si++)
            {
                if (_uid == _colonists[_si]) { _is_colonist = true; break; }
            }

            if (_is_colonist && instance_exists(_uid))
            {
                // Colonists must be on the map to march, so take them out of
                // their beds before detaching them from the village.
                scr_unit_wake(_uid);

                _uid.village_id            = -1;   // kingdom_id stays: marks them as colonists
                _uid.can_leave_territory   = true;
                _uid.can_walk_on_resources = true;
                _uid.colonist_leader       = (_uid == _leader);
                _uid.walk_path             = [];
                _uid.walk_index            = 0;
                _uid.path_allow_res        = false;
                _uid.wander_pause_timer    = 0;
                _uid.path_cooldown         = 0;
            }
            else
            {
                array_push(_new_members, _uid);
            }
        }

        _cap.member_ids        = _new_members;
        _cap.expansion_request = false;
        global.villages[_cap_id] = _cap;
    }
}

/// @func scr_find_expansion_spot(_cap, _leader)
/// @desc Finds a free land tile for a child village: outside every village's
///       claim, with a clear 3x3 building area, reachable from the leader.
/// @returns {array} [gx, gy], or [-1, -1] when nothing suitable is nearby.
function scr_find_expansion_spot(_cap, _leader)
{
    var _w = obj_world.world_width;
    var _h = obj_world.world_height;

    // Start clear of the capital's own bounds. Nearby villages are handled
    // by the overlap/ownership checks below, so the search simply walks
    // outward until it finds unowned land.
    var _reach = max(
        abs(_cap.cx - _cap.left),
        abs(_cap.cx - _cap.right),
        abs(_cap.cy - _cap.top),
        abs(_cap.cy - _cap.bottom)
    );

    // The child claims an 11x11 rect, so leave room beyond that starting
    // ring. The A* budget below still bounds the work.
    var _start_r = _reach + 8;
    var _max_r   = _start_r + 60;
    var _checks  = 0;
    var _max_checks = 8;   // stop after a few unreachable candidates

    for (var _r = _start_r; _r <= _max_r; _r++)
    {
        for (var _dy = -_r; _dy <= _r; _dy++)
        {
            for (var _dx = -_r; _dx <= _r; _dx++)
            {
                if (max(abs(_dx), abs(_dy)) != _r) continue; // ring only

                var _gx = _cap.cx + _dx;
                var _gy = _cap.cy + _dy;

                if (_gx < 2 || _gx >= _w - 2) continue;
                if (_gy < 2 || _gy >= _h - 2) continue;

                // The town hall needs a free 3x3: land, unblocked, unowned.
                var _clear = true;
                for (var _oy = -1; _oy <= 1 && _clear; _oy++)
                {
                    for (var _ox = -1; _ox <= 1 && _clear; _ox++)
                    {
                        var _idx = (_gx + _ox) + (_gy + _oy) * _w;
                        if (obj_world.terrain_grid[_idx] == TERRAIN.WATER) _clear = false;
                        else if (obj_world.block_grid[_idx] == 1)           _clear = false;
                        else if (obj_world.territory_grid[_idx] != -1)      _clear = false;
                    }
                }
                if (!_clear) continue;

                // Keep the child's 11x11 founding claim clear of existing
                // villages. Otherwise it would be founded with almost no land.
                var _overlaps = false;
                for (var _vi = 0; _vi < array_length(global.villages); _vi++)
                {
                    var _v = global.villages[_vi];
                    if (_gx - 5 <= _v.right && _gx + 5 >= _v.left
                     && _gy - 5 <= _v.bottom && _gy + 5 >= _v.top)
                    {
                        _overlaps = true;
                        break;
                    }
                }
                if (_overlaps) continue;

                // Colonists must actually be able to march there.
                // scr_find_path returns [] both for "unreachable" and for
                // "already there", so handle the same-tile case explicitly.
                if (_leader.grid_x == _gx && _leader.grid_y == _gy) return [_gx, _gy];
                if (_checks >= _max_checks) return [-1, -1];
                _checks++;
                if (array_length(scr_find_path(_leader.grid_x, _leader.grid_y, _gx, _gy, true)) == 0) continue;

                return [_gx, _gy];
            }
        }
    }

    return [-1, -1];
}
