/// @func scr_ai_miner(_unit)
/// @desc AI for miner units. Returns a struct with target_gx, target_gy, skip_path, allow_resource_path, must_reach.
function scr_ai_miner(_unit)
{
    var _target_gx = _unit.grid_x;
    var _target_gy = _unit.grid_y;
    var _skip_path = false;
    var _allow_resource_path = false;
    var _must_reach = false;

    if (_unit.village_id == -1) return { target_gx: _target_gx, target_gy: _target_gy, skip_path: _skip_path, allow_resource_path: _allow_resource_path, must_reach: _must_reach };

    if (_unit.harvest_target_x != -1)
    {
        var _ridx = _unit.harvest_target_x + _unit.harvest_target_y * obj_world.world_width;

        if (obj_world.resource_grid[_ridx] == RESOURCE.NONE)
        {
            _unit.harvest_target_x = -1;
            _unit.harvest_target_y = -1;
            _unit.harvest_timer    = 0;
            _unit.harvest_retries  = 0;
            _unit.wander_pause_timer = 5;
            _skip_path = true;
        }
        else if (_unit.grid_x == _unit.harvest_target_x && _unit.grid_y == _unit.harvest_target_y)
        {
            _unit.harvest_retries = 0;
            if (scr_try_harvest(_unit)) _unit.wander_pause_timer = 10;
            _skip_path = true;
        }
        else if (++_unit.harvest_retries > 20)
        {
            _unit.harvest_target_x = -1;
            _unit.harvest_target_y = -1;
            _unit.harvest_timer    = 0;
            _unit.harvest_retries  = 0;
            _unit.wander_pause_timer = 30;
            _skip_path = true;
        }
        else
        {
            _target_gx           = _unit.harvest_target_x;
            _target_gy           = _unit.harvest_target_y;
            _allow_resource_path = true;
            _unit.path_cooldown  = irandom_range(5, 15);
        }
    }
    else
    {
        var _v = global.villages[_unit.village_id];

        // 0 = still has something to fetch, 1 = rest threshold met,
        // 2 = nothing left to mine anywhere in reach.
        var _idle = 0;

        if (!scr_village_needs_mining(_v))
        {
            _idle = 1;
        }
        else if (_unit.mine_dry_scans > 0)
        {
            // Still waiting out a failed search: do not re-run the (expensive)
            // ring scan every time the cooldown expires.
            _idle = 2;
        }
        else if (scr_find_harvest_target(_unit))
        {
            _unit.harvest_retries = 0;
            _unit.mine_dry_scans  = 0;
            _target_gx           = _unit.harvest_target_x;
            _target_gy           = _unit.harvest_target_y;
            _unit.path_cooldown  = irandom_range(5, 15);
            _allow_resource_path = true;
        }
        else
        {
            // The search failed. Two very different cases:
            if (_unit.harvest_failed_x != -1)
            {
                // A tile exists but no path reaches it (the search sets
                // harvest_failed_x for exactly that case). Skip it and retry
                // shortly instead of declaring the village out of ore.
                _unit.wander_pause_timer = 30;
                _skip_path = true;
            }
            else
            {
                // No candidate tile at all: scr_find_harvest_target clears
                // harvest_failed_x before returning false in that case. There
                // is genuinely nothing left to mine in reach, so treat the
                // miner as out of work and let it rest at the workshop. The
                // timer re-runs the search later; the housing tick also
                // refuses to wake it before then, which stops the
                // wake -> fail -> walk back loop.
                _unit.mine_dry_scans = 15;
                _idle = 2;
            }
        }

        if (_idle != 0)
        {
            // Walk back to the workshop. The housing tick takes the miner
            // inside once it reaches the door, and wakes it again as soon as a
            // stock drops below its cap (or the mining retry timer expires).
            var _rest = scr_find_rest_workshop(_unit);
            var _rest_spot = (_rest != noone) ? scr_rest_stand_tile(_unit, _rest) : [-1, -1];

            if (_rest_spot[0] != -1)
            {
                _target_gx = _rest_spot[0];
                _target_gy = _rest_spot[1];
                _unit.path_cooldown = irandom_range(5, 15);
            }
            else if (_unit.grid_x != _v.cx || _unit.grid_y != _v.cy)
            {
                _target_gx    = _v.cx;
                _target_gy    = _v.cy;
                _unit.path_cooldown = irandom_range(5, 15);
            }
            else
            {
                _target_gx    = _unit.grid_x + irandom_range(-3, 3);
                _target_gy    = _unit.grid_y + irandom_range(-3, 3);
                _unit.path_cooldown = irandom_range(5, 15);
            }
        }
    }

    return { target_gx: _target_gx, target_gy: _target_gy, skip_path: _skip_path, allow_resource_path: _allow_resource_path, must_reach: _must_reach };
}

/// @func scr_builder_distance_to_site(_unit, _site)
/// @desc Chebyshev distance (in tiles) from the unit to the building footprint.
///       Returns 0 when the unit stands on the footprint itself.
function scr_builder_distance_to_site(_unit, _site)
{
    var _dx = 0;
    var _dy = 0;

    if (_unit.grid_x < _site.footprint_left)        _dx = _site.footprint_left - _unit.grid_x;
    else if (_unit.grid_x > _site.footprint_right)  _dx = _unit.grid_x - _site.footprint_right;

    if (_unit.grid_y < _site.footprint_top)         _dy = _site.footprint_top - _unit.grid_y;
    else if (_unit.grid_y > _site.footprint_bottom) _dy = _unit.grid_y - _site.footprint_bottom;

    return max(_dx, _dy);
}

/// @func scr_builder_find_stand_tile(_unit, _site, _max_ring)
/// @desc Finds the tile nearest the unit within _max_ring tiles of the
///       footprint that the builder may actually occupy (terrain, buildings,
///       resources, territory rules). Prefers tiles closest to the building.
///       Returns [-1, -1] when nothing suitable exists.
function scr_builder_find_stand_tile(_unit, _site, _max_ring = 4)
{
    var _best   = [-1, -1];
    var _best_s = 1000000;

    var _l = _site.footprint_left   - _max_ring;
    var _r = _site.footprint_right  + _max_ring;
    var _t = _site.footprint_top    - _max_ring;
    var _b = _site.footprint_bottom + _max_ring;

    for (var _gy = _t; _gy <= _b; _gy++)
    {
        for (var _gx = _l; _gx <= _r; _gx++)
        {
            // Skip the building's own footprint.
            if (_gx >= _site.footprint_left && _gx <= _site.footprint_right
             && _gy >= _site.footprint_top  && _gy <= _site.footprint_bottom) continue;

            if (!scr_tile_allowed_for_unit(_unit, _gx, _gy)) continue;

            // Distance from this tile to the footprint box.
            var _fx = 0;
            var _fy = 0;

            if (_gx < _site.footprint_left)        _fx = _site.footprint_left - _gx;
            else if (_gx > _site.footprint_right)  _fx = _gx - _site.footprint_right;

            if (_gy < _site.footprint_top)         _fy = _site.footprint_top - _gy;
            else if (_gy > _site.footprint_bottom) _fy = _gy - _site.footprint_bottom;

            var _dfoot = max(_fx, _fy);
            var _du    = abs(_unit.grid_x - _gx) + abs(_unit.grid_y - _gy);

            // Nearest ring first, then nearest to the unit.
            var _score = _dfoot * 1000 + _du;

            if (_score < _best_s)
            {
                _best_s = _score;
                _best   = [_gx, _gy];
            }
        }
    }

    return _best;
}

/// @func scr_ai_builder(_unit)
function scr_ai_builder(_unit)
{
    var _target_gx = _unit.grid_x;
    var _target_gy = _unit.grid_y;
    var _skip_path = false;
    var _allow_resource_path = false;
    var _must_reach = false;

    var _site = noone;

    if (_unit.build_target_id != noone && instance_exists(_unit.build_target_id))
    {
        if (_unit.build_target_id.state == "construction") _site = _unit.build_target_id;
        else _unit.build_target_id = noone;
    }

    if (_site == noone)
    {
        var _best_priority = 9999;
        var _best_site     = noone;

        with (obj_building)
        {
            if (state != "construction")        continue;
            if (village_id != other.village_id) continue;

            var _prio = 99;
            switch (building_type)
            {
                case "town_hall":  _prio = 1; break;
                case "watchtower": _prio = 2; break;
                case "mine":       _prio = 3; break;
                case "boat_port":  _prio = 4; break;
                case "workshop":   _prio = 5; break;
                case "barracks":   _prio = 5; break;
                case "house_a":    _prio = 6; break;
                case "house_b":    _prio = 7; break;
                default:           _prio = 8; break;
            }

            if (_prio < _best_priority)
            {
                _best_priority = _prio;
                _best_site     = id;
            }
        }

        if (_best_site != noone)
        {
            _unit.build_target_id = _best_site;
            _site           = _best_site;
        }
    }

    if (_site != noone)
    {
        var _dist = scr_builder_distance_to_site(_unit, _site);

        if (_dist <= 2)
        {
            // Close enough - wait for the rest of the crew.
            _skip_path = true;
        }
        else
        {
            // Walk to a tile that is actually standable around the footprint.
            // The old code targeted the sprite origin (one tile BELOW the
            // building), which is often blocked by resources or outside the
            // village's territory, so builders could never arrive.
            var _spot = scr_builder_find_stand_tile(_unit, _site, 4);

            if (_spot[0] != -1)
            {
                _target_gx = _spot[0];
                _target_gy = _spot[1];
                _unit.path_cooldown = irandom_range(5, 15);
            }
            else
            {
                // Site is walled in: still try the footprint edge, and let the
                // completion stall timer in scr_try_complete_buildings resolve it.
                _target_gx = _site.footprint_left;
                _target_gy = _site.footprint_top;
                _unit.path_cooldown = irandom_range(5, 15);
            }
        }
    }
    else
    {
        // Nothing left to build: walk back to the workshop. The housing tick
        // shelters the builder once it reaches the door, and wakes it again
        // the moment a new construction site appears.
        var _rest = scr_find_rest_workshop(_unit);
        var _rest_spot = (_rest != noone) ? scr_rest_stand_tile(_unit, _rest) : [-1, -1];

        if (_rest_spot[0] != -1)
        {
            _target_gx = _rest_spot[0];
            _target_gy = _rest_spot[1];
            _unit.path_cooldown = irandom_range(5, 15);
        }
        else
        {
            var _wr = max(1, _unit.wander_radius);
            _target_gx = _unit.grid_x + irandom_range(-_wr, _wr);
            _target_gy = _unit.grid_y + irandom_range(-_wr, _wr);
            if (_unit.village_id != -1)
            {
                var _v = global.villages[_unit.village_id];
                _target_gx = clamp(_target_gx, _v.left, _v.right);
                _target_gy = clamp(_target_gy, _v.top,  _v.bottom);
            }
        }
    }

    return { target_gx: _target_gx, target_gy: _target_gy, skip_path: _skip_path, allow_resource_path: _allow_resource_path, must_reach: _must_reach };
}

/// @func scr_ai_leader(_unit)
function scr_ai_leader(_unit)
{
    var _target_gx = _unit.grid_x;
    var _target_gy = _unit.grid_y;
    var _skip_path = false;
    var _allow_resource_path = false;
    var _must_reach = false;

    if (_unit.leader_anchor_x != -1)
    {
        var _wr = max(1, _unit.wander_radius);
        _target_gx = _unit.leader_anchor_x + irandom_range(-_wr, _wr);
        _target_gy = _unit.leader_anchor_y + irandom_range(-_wr, _wr);
        if (_unit.village_id != -1)
        {
            var _v = global.villages[_unit.village_id];
            _target_gx = clamp(_target_gx, _v.left, _v.right);
            _target_gy = clamp(_target_gy, _v.top,  _v.bottom);
        }
    }

    return { target_gx: _target_gx, target_gy: _target_gy, skip_path: _skip_path, allow_resource_path: _allow_resource_path, must_reach: _must_reach };
}

/// @func scr_ai_villager(_unit)
function scr_ai_villager(_unit)
{
    var _target_gx = _unit.grid_x;
    var _target_gy = _unit.grid_y;
    var _skip_path = false;
    var _allow_resource_path = false;
    var _must_reach = false;

    if (_unit.village_id == -1)
    {
        // Unaffiliated: converge toward the beacon leader.
        if (variable_global_exists("village_founder_id") && global.village_founder_id == _unit.id)
        {
            // This unit IS the beacon: stand still.
            _target_gx = _unit.grid_x;
            _target_gy = _unit.grid_y;
            _skip_path = true;
        }
        else if (!variable_global_exists("village_founder_id") || global.village_founder_id == noone
              || !instance_exists(global.village_founder_id))
        {
            if (variable_global_exists("village_founder_id") && global.village_founder_id != noone)
            {
                global.village_founder_id = noone;
                global.village_founder_x  = -1;
                global.village_founder_y  = -1;
            }
            // No beacon - wander locally.
            var _wr = max(1, _unit.wander_radius);
            _target_gx = _unit.grid_x + irandom_range(-_wr, _wr);
            _target_gy = _unit.grid_y + irandom_range(-_wr, _wr);
        }
        else
        {
            _target_gx           = global.village_founder_x;
            _target_gy           = global.village_founder_y;
            _allow_resource_path = true;
            _must_reach          = true;
        }
    }
    else
    {
        // In a village: wander inside bounds.
        var _wr2 = max(1, _unit.wander_radius);
        _target_gx = _unit.grid_x + irandom_range(-_wr2, _wr2);
        _target_gy = _unit.grid_y + irandom_range(-_wr2, _wr2);
        var _v = global.villages[_unit.village_id];
        _target_gx = clamp(_target_gx, _v.left, _v.right);
        _target_gy = clamp(_target_gy, _v.top,  _v.bottom);
    }

    return { target_gx: _target_gx, target_gy: _target_gy, skip_path: _skip_path, allow_resource_path: _allow_resource_path, must_reach: _must_reach };
}

/// @func scr_ai_default(_unit)
function scr_ai_default(_unit)
{
    var _target_gx = _unit.grid_x;
    var _target_gy = _unit.grid_y;
    var _skip_path = false;
    var _allow_resource_path = false;
    var _must_reach = false;

    var _wr = max(1, _unit.wander_radius);
    _target_gx = _unit.grid_x + irandom_range(-_wr, _wr);
    _target_gy = _unit.grid_y + irandom_range(-_wr, _wr);
    if (_unit.village_id != -1)
    {
        var _v = global.villages[_unit.village_id];
        _target_gx = clamp(_target_gx, _v.left, _v.right);
        _target_gy = clamp(_target_gy, _v.top,  _v.bottom);
    }

    return { target_gx: _target_gx, target_gy: _target_gy, skip_path: _skip_path, allow_resource_path: _allow_resource_path, must_reach: _must_reach };
}

/// @func scr_ai_colonist(_unit, _k)
/// @desc AI for colonists (unaffiliated villagers marching to an expansion rally).
function scr_ai_colonist(_unit, _k)
{
    var _target_gx = _unit.grid_x;
    var _target_gy = _unit.grid_y;
    var _skip_path = false;
    var _allow_resource_path = true;
    var _must_reach = true;

    if (_k.expansion_rally_x == -1)
    {
        _skip_path         = true;
        _unit.wander_pause_timer = 30;
    }
    else
    {
        _target_gx = _k.expansion_rally_x;
        _target_gy = _k.expansion_rally_y;

        var _arrive_r = _unit.colonist_leader ? 0 : 3;
        if (point_distance(_unit.grid_x, _unit.grid_y, _target_gx, _target_gy) <= _arrive_r)
        {
            _skip_path         = true;
            _unit.wander_pause_timer = 5;
        }
    }

    return { target_gx: _target_gx, target_gy: _target_gy, skip_path: _skip_path, allow_resource_path: _allow_resource_path, must_reach: _must_reach };
}
