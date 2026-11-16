/// @func scr_try_form_villages()
/// @desc Runs periodically. Handles founding, expansion, migration, etc.
function scr_try_form_villages()
{

    // === Build unit list (snapshot) ===
    var _count = instance_number(obj_unit);
    var _units = array_create(_count);
    var _i = 0;
    with (obj_unit) { _units[_i] = id; _i++; }

    // ================================================================
    // Tunables
    // ================================================================
    var _cluster_radius      = 15;
    var _beacon_radius       = 30;   // wider radius so spread-out groups still get an anchor
    var _assimilation_radius = 5;
    var _founding_min        = 5;
    var _village_radius      = 5;
    var _migration_batch     = 10;

    // ================================================================
    // PASS 1: Unaffiliated villagers — local cluster founding
    // ================================================================
    // Every unaffiliated villager is a candidate. A candidate founds a
    // village when at least _founding_min unaffiliated villagers (itself
    // included) are within _cluster_radius AND can reach it. This means
    // separate groups can found their own villages, and a lone straggler
    // somewhere else can no longer block a local group.
    //
    // After founding, the largest remaining group gets a beacon: its
    // candidate stands still and the rest path to it, so scattered
    // villagers still converge.
    // ================================================================

    // Collect unaffiliated villagers.
    var _unaffiliated = [];
    for (var _ui = 0; _ui < _count; _ui++)
    {
        var _uu = _units[_ui];
        if (!instance_exists(_uu)) continue;
        if (_uu.unit_type != "villager") continue;
        if (_uu.village_id != -1) continue;
        if (_uu.kingdom_id != -1)
        {
            var _uk = global.kingdoms[_uu.kingdom_id];
            if (_uk.expansion_rally_active) continue;
        }
        array_push(_unaffiliated, _uu);
    }

    // Stable order: oldest (lowest id) first.
    for (var _si = 1; _si < array_length(_unaffiliated); _si++)
    {
        var _key = _unaffiliated[_si];
        var _sj  = _si - 1;
        while (_sj >= 0)
        {
            if (_unaffiliated[_sj].id <= _key.id) break;
            _unaffiliated[_sj + 1] = _unaffiliated[_sj];
            _sj--;
        }
        _unaffiliated[_sj + 1] = _key;
    }

    // ---- Founding pass ----
    for (var _ci = 0; _ci < array_length(_unaffiliated); _ci++)
    {
        var _cand = _unaffiliated[_ci];
        if (!instance_exists(_cand)) continue;
        if (_cand.village_id != -1) continue; // founded/assimilated earlier this scan

        // Cheap distance check first: can this candidate possibly have
        // enough neighbours? Avoids running A* for every single villager.
        var _nearby = 1; // the candidate itself
        for (var _qi = 0; _qi < array_length(_unaffiliated); _qi++)
        {
            var _qu = _unaffiliated[_qi];
            if (!instance_exists(_qu) || _qu == _cand) continue;
            if (_qu.village_id != -1) continue;
            if (point_distance(_cand.grid_x, _cand.grid_y, _qu.grid_x, _qu.grid_y) <= _cluster_radius) _nearby++;
        }

        if (_nearby < _founding_min) continue;

        // Full cluster: only villagers that can actually reach the candidate.
        // Same tile counts as reachable: scr_find_path returns [] when
        // start == goal, and converged villagers do end up on one tile.
        var _cluster = [_cand];

        for (var _ni = 0; _ni < array_length(_unaffiliated); _ni++)
        {
            var _nu = _unaffiliated[_ni];
            if (!instance_exists(_nu) || _nu == _cand) continue;
            if (_nu.village_id != -1) continue;
            if (point_distance(_cand.grid_x, _cand.grid_y, _nu.grid_x, _nu.grid_y) > _cluster_radius) continue;

            if ((_nu.grid_x == _cand.grid_x && _nu.grid_y == _cand.grid_y)
             || array_length(scr_find_path(_nu.grid_x, _nu.grid_y, _cand.grid_x, _cand.grid_y, true)) > 0)
            {
                array_push(_cluster, _nu);
            }
        }

        if (array_length(_cluster) < _founding_min) continue;

        // Nearest existing village (Chebyshev distance to its territory).
        var _too_close       = false;
        var _closest_village = -1;
        var _closest_dist    = 99999;

        for (var _vi = 0; _vi < array_length(global.villages); _vi++)
        {
            var _v = global.villages[_vi];
            var _dx = 0; var _dy = 0;
            if (_cand.grid_x < _v.left) _dx = _v.left - _cand.grid_x;
            else if (_cand.grid_x > _v.right) _dx = _cand.grid_x - _v.right;
            if (_cand.grid_y < _v.top) _dy = _v.top - _cand.grid_y;
            else if (_cand.grid_y > _v.bottom) _dy = _cand.grid_y - _v.bottom;
            var _cheb = max(_dx, _dy);
            if (_cheb < _closest_dist) { _closest_dist = _cheb; _closest_village = _vi; }
            if (_cheb < _assimilation_radius) _too_close = true;
        }

        if (_too_close && _closest_village != -1)
        {
            // The whole group joins the nearby village (candidate included).
            var _target_v = global.villages[_closest_village];

            for (var _ai = 0; _ai < array_length(_cluster); _ai++)
            {
                var _au = _cluster[_ai];
                if (!instance_exists(_au)) continue;

                _au.village_id = _closest_village;
                _au.kingdom_id = _target_v.kingdom_id;
                _au.x          = _target_v.cx * obj_world.tile_size;
                _au.y          = _target_v.cy * obj_world.tile_size;
                _au.grid_x     = _target_v.cx;
                _au.grid_y     = _target_v.cy;
                _au.walk_path  = [];
                _au.walk_index = 0;
                _au.path_allow_res = false;
                _au.wander_pause_timer = 0;
                _au.path_cooldown = 0;

                var _already = false;
                for (var _mi = 0; _mi < array_length(_target_v.member_ids); _mi++)
                {
                    if (_target_v.member_ids[_mi] == _au.id) { _already = true; break; }
                }
                if (!_already) array_push(_target_v.member_ids, _au.id);
            }

            global.villages[_closest_village] = _target_v;
        }
        else
        {
            // Found a new village at the candidate's tile. Town hall
            // placement is handled by scr_create_village/scr_place_construction.
            var _new_id = scr_create_village(_cand.grid_x, _cand.grid_y, _village_radius, "villager", -1, true);
            var _new_v  = global.villages[_new_id];

            // Candidate becomes the leader.
            _cand.unit_type  = "leader";
            _cand.village_id = _new_id;
            _cand.kingdom_id = _new_v.kingdom_id;
            _cand.is_leader  = true;
            _cand.home_x     = _cand.grid_x;
            _cand.home_y     = _cand.grid_y;
            array_push(_new_v.member_ids, _cand.id);
            scr_apply_unit_type(_cand, "leader");

            // Everyone else in the cluster joins the new village.
            for (var _ai = 0; _ai < array_length(_cluster); _ai++)
            {
                var _au = _cluster[_ai];
                if (!instance_exists(_au) || _au == _cand) continue;

                _au.village_id = _new_id;
                _au.kingdom_id = _new_v.kingdom_id;
                _au.x          = _new_v.cx * obj_world.tile_size;
                _au.y          = _new_v.cy * obj_world.tile_size;
                _au.grid_x     = _new_v.cx;
                _au.grid_y     = _new_v.cy;
                _au.walk_path  = [];
                _au.walk_index = 0;
                _au.path_allow_res = false;
                _au.wander_pause_timer = 0;
                _au.path_cooldown = 0;

                array_push(_new_v.member_ids, _au.id);
                scr_apply_unit_type(_au, "villager");
            }

            global.villages[_new_id] = _new_v;
        }
    }

    // ---- Beacon pass ----
    // Largest remaining unaffiliated group becomes the convergence target.
    // A group of one gets no beacon, so stragglers just wander.
    var _beacon      = noone;
    var _beacon_size = 0;

    for (var _bi = 0; _bi < array_length(_unaffiliated); _bi++)
    {
        var _bu = _unaffiliated[_bi];
        if (!instance_exists(_bu)) continue;
        if (_bu.village_id != -1) continue;

        var _group = 1;
        for (var _bj = 0; _bj < array_length(_unaffiliated); _bj++)
        {
            var _other = _unaffiliated[_bj];
            if (!instance_exists(_other) || _other == _bu) continue;
            if (_other.village_id != -1) continue;
            if (point_distance(_bu.grid_x, _bu.grid_y, _other.grid_x, _other.grid_y) <= _beacon_radius) _group++;
        }

        if (_group > _beacon_size)
        {
            _beacon_size = _group;
            _beacon      = _bu;
        }
    }

    if (_beacon != noone && _beacon_size >= 2)
    {
        global.village_founder_id = _beacon.id;
        global.village_founder_x  = _beacon.grid_x;
        global.village_founder_y  = _beacon.grid_y;

        // The beacon unit stands still so the rest can catch up.
        _beacon.walk_path  = [];
        _beacon.walk_index = 0;
    }
    else
    {
        global.village_founder_id = noone;
        global.village_founder_x  = -1;
        global.village_founder_y  = -1;
    }

    // ================================================================
    // PASS 2: Found children from rally (Delegated to helper function)
    // ================================================================
    scr_try_found_from_rally();

    // ================================================================
    // PASS 2b: Kingdom advancement (run before expansion requests so the
    // new level's caps apply on the same scan)
    // ================================================================
    scr_check_kingdom_level_up();

    // ================================================================
    // PASS 3: Migration
    // ================================================================
    for (var _mvi = 0; _mvi < array_length(global.villages); _mvi++)
    {
        var _src = global.villages[_mvi];

        var _over_capacity = (array_length(_src.member_ids) >= scr_village_housing_cap(_src));
        var _is_cramped    = _src.cramped;

        if (!_over_capacity && !_is_cramped) continue;
        if (array_length(_src.member_ids) <= _founding_min) continue;

        var _best_sibling_id = -1;
        var _best_dist       = 99999;

        for (var _sj2 = 0; _sj2 < array_length(global.villages); _sj2++)
        {
            if (_sj2 == _mvi) continue;

            var _sib = global.villages[_sj2];
            if (_sib.kingdom_id != _src.kingdom_id) continue;
            if (array_length(_sib.member_ids) >= scr_village_housing_cap(_sib)) continue;

            var _d = point_distance(_src.cx, _src.cy, _sib.cx, _sib.cy);
            if (_d < _best_dist)
            {
                _best_dist       = _d;
                _best_sibling_id = _sj2;
            }
        }

        if (_best_sibling_id == -1) continue;

        var _dest = global.villages[_best_sibling_id];
        var _migrated  = 0;
        var _remaining = [];

        for (var _ui2 = 0; _ui2 < array_length(_src.member_ids); _ui2++)
        {
            var _unit_id = _src.member_ids[_ui2];

            if (_migrated >= _migration_batch)
            {
                array_push(_remaining, _unit_id);
                continue;
            }

            var _unit = _unit_id;
            if (!instance_exists(_unit)) continue;
            if (_unit.is_leader)
            {
                array_push(_remaining, _unit.id);
                continue;
            }

            // Migrating to another village: leave the current bed first, so the
            // bed is freed and the unit is visible to walk to its new home.
            scr_unit_wake(_unit);

            _unit.village_id = _best_sibling_id;
            _unit.kingdom_id = _dest.kingdom_id;
            array_push(_dest.member_ids, _unit.id);
            var _path = scr_find_path(_unit.grid_x, _unit.grid_y, _dest.cx, _dest.cy, true);

            if (array_length(_path) > 0)
            {
                _unit.walk_path          = _path;
                _unit.walk_index         = 0;
                _unit.wander_pause_timer = 0;
                _unit.path_cooldown      = 0;
            }

            _migrated++;
        }

        _src.member_ids = _remaining;
        global.villages[_mvi]              = _src;
        global.villages[_best_sibling_id] = _dest;
    }

    // ================================================================
    // PASS 4: Role assignment
    // ================================================================
    for (var _ri = 0; _ri < array_length(global.villages); _ri++)
    {
        scr_assign_roles(_ri);
    }

    // ================================================================
    // PASS 5 & 6: Village expansion & requests
    // ================================================================
    scr_try_expand_village();
    scr_set_expansion_requests();

    // ================================================================
    // PASS 7: Process requests (every 10 sec)
    // ================================================================
    if (!variable_global_exists("expansion_scan_timer"))
    {
        global.expansion_scan_timer = 0;
    }

    global.expansion_scan_timer++;
    if (global.expansion_scan_timer >= 10)
    {
        global.expansion_scan_timer = 0;
        scr_process_expansion_requests();
    }

    // ================================================================
    // PASS 8 & 9: Building upgrades, placement & completion
    // ================================================================
    // Ports get first claim on the single construction slot. Otherwise an
    // era-2 village with level-1 houses still queued keeps starting an
    // upgrade every time a site finishes, so the placement pass never gets
    // a free slot and the first port is never built.
    scr_try_place_port();
    scr_try_upgrade_buildings();
    scr_try_place_buildings();
    scr_try_complete_buildings();
}
