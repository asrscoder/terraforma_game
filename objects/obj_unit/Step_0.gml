// At the very top of obj_unit Step event
if (global.is_paused) exit;

// ============================================================
// HOUSED UNITS DO NOTHING
// ============================================================
// A unit inside a building keeps its instance (so member_ids and
// instance_exists() keep working) but skips the entire Step: AI dispatch,
// target selection, pathfinding, movement and sprite state. It is also not
// drawn (scr_unit_house sets visible = false). This is the entire per-unit
// cost, so housing is what makes large populations affordable.
// Every code path that gives the unit a job calls scr_unit_wake() first.
if (housed) exit;

// ============================================================
// 0. PUSH OUT OF BLOCKED TILE
// ============================================================
var _my_idx = grid_x + grid_y * obj_world.world_width;
if (obj_world.block_grid[_my_idx] == 1)
{
    var _exempt = false;
    if (can_walk_on_resources)
    {
        var _res = obj_world.resource_grid[_my_idx];
        if (_res == RESOURCE.TREE || _res == RESOURCE.STONE || _res == RESOURCE.IRON) _exempt = true;
    }

    if (!_exempt)
    {
        var _placed = false;
        var _radius = 1;

        while (!_placed && _radius <= 5)
        {
            for (var _dy = -_radius; _dy <= _radius && !_placed; _dy++)
            {
                for (var _dx = -_radius; _dx <= _radius && !_placed; _dx++)
                {
                    if (abs(_dx) != _radius && abs(_dy) != _radius) continue;

                    var _nx = grid_x + _dx;
                    var _ny = grid_y + _dy;

                    if (!scr_tile_allowed_for_unit(self, _nx, _ny)) continue;

                    // Spawn and movement use the tile's top-left corner.
                    // Use the same convention here (was +0.5 x, +1 y).
                    x          = _nx * obj_world.tile_size;
                    y          = _ny * obj_world.tile_size;
                    grid_x     = _nx;
                    grid_y     = _ny;
                    walk_path      = [];
                    walk_index     = 0;
                    path_allow_res = false;
                    _placed    = true;
                }
            }
            _radius++;
        }
    }
}

// Recompute after push-out; the old _my_idx is stale.
var _cur_idx = grid_x + grid_y * obj_world.world_width;

// ============================================================
// YANK BACK: units without leave permission must stay on
// their own village's claimed territory
// ============================================================
if (village_id != -1 && !can_leave_territory && !path_allow_res)
{
    if (obj_world.territory_grid[_cur_idx] != village_id)
    {
        var _v = global.villages[village_id];

        // Same top-left convention as spawning/movement (was +0.5 x, +1 y).
        x              = _v.cx * obj_world.tile_size;
        y              = _v.cy * obj_world.tile_size;
        grid_x         = _v.cx;
        grid_y         = _v.cy;
        walk_path      = [];
        walk_index     = 0;
        path_allow_res = false;
    }
}

// ============================================================
// 1. AI — target selection
// ============================================================
if (array_length(walk_path) == 0)
{
    if (wander_pause_timer > 0)
    {
        wander_pause_timer--;
    }
    else if (path_cooldown > 0)
    {
        path_cooldown--;
    }
    else
    {
        var _target_gx           = grid_x;
        var _target_gy           = grid_y;
        var _skip_path           = false;
        var _allow_resource_path = false;
        var _must_reach          = false;

        // ---- Dispatch to type-specific AI ----
        var _ai;
        if (unit_type == "miner" && village_id != -1)
        {
            _ai = scr_ai_miner(self);
        }
        else if (unit_type == "builder")
        {
            _ai = scr_ai_builder(self);
        }
        else if (unit_type == "leader" && leader_anchor_x != -1)
        {
            _ai = scr_ai_leader(self);
        }
        else if (unit_type == "villager" && village_id == -1 && kingdom_id != -1
              && variable_global_exists("kingdoms") && kingdom_id < array_length(global.kingdoms)
              && global.kingdoms[kingdom_id].expansion_rally_active)
        {
            _ai = scr_ai_colonist(self, global.kingdoms[kingdom_id]);
        }
        else if (unit_type == "villager")
        {
            _ai = scr_ai_villager(self);
        }
        else
        {
            _ai = scr_ai_default(self);
        }

        _target_gx           = _ai.target_gx;
        _target_gy           = _ai.target_gy;
        _skip_path           = _ai.skip_path;
        _allow_resource_path = _ai.allow_resource_path;
        _must_reach          = _ai.must_reach;

        // ---- TARGET CLAMP ----
        if (village_id != -1 && !can_leave_territory && !_allow_resource_path)
        {
            var _v = global.villages[village_id];
            _target_gx = clamp(_target_gx, _v.left, _v.right);
            _target_gy = clamp(_target_gy, _v.top,  _v.bottom);
        }

        // ---- Validate target against the gate ----
        if (!_skip_path && !_allow_resource_path)
        {
            if (!scr_tile_allowed_for_unit(self, _target_gx, _target_gy))
            {
                var _ok  = false;
                var _wr2 = max(1, wander_radius);

                for (var _t = 0; _t < 8; _t++)
                {
                    var _tx2 = grid_x + irandom_range(-_wr2, _wr2);
                    var _ty2 = grid_y + irandom_range(-_wr2, _wr2);

                    if (village_id != -1)
                    {
                        var _v2 = global.villages[village_id];
                        _tx2 = clamp(_tx2, _v2.left, _v2.right);
                        _ty2 = clamp(_ty2, _v2.top,  _v2.bottom);
                    }

                    if (scr_tile_allowed_for_unit(self, _tx2, _ty2))
                    {
                        _target_gx = _tx2;
                        _target_gy = _ty2;
                        _ok        = true;
                        break;
                    }
                }

                if (!_ok)
                {
                    wander_pause_timer = 15;
                    _skip_path         = true;
                }
            }
        }

        // ---- Path generation ----
        if (!_skip_path)
        {
            if (_target_gx < 0 || _target_gx >= obj_world.world_width)  _target_gx = grid_x;
            if (_target_gy < 0 || _target_gy >= obj_world.world_height) _target_gy = grid_y;

            if (scr_tile_allowed_for_unit(self, _target_gx, _target_gy, _allow_resource_path))
            {
                if (scr_line_is_clear(grid_x, grid_y, _target_gx, _target_gy, unit_class))
                {
                    walk_path      = [[_target_gx, _target_gy]];
                    walk_index     = 0;
                    path_allow_res = _allow_resource_path;
                    path_cooldown  = irandom_range(20, 45);
                }
                else
                {
                    // Budgeted: if this frame's allowance is already spent the
                    // call returns [] and the unit takes the short wiggle step
                    // below instead, then retries after its cooldown.
                    var _new_path = scr_find_path(grid_x, grid_y, _target_gx, _target_gy, _allow_resource_path, unit_class, true);

                    if (array_length(_new_path) > 0)
                    {
                        var _safe = [];
                        for (var _p = 0; _p < array_length(_new_path); _p++)
                        {
                            var _pgx = _new_path[_p][0];
                            var _pgy = _new_path[_p][1];
                            if (!scr_tile_allowed_for_unit(self, _pgx, _pgy, _allow_resource_path)) break;
                            array_push(_safe, _new_path[_p]);
                        }
                        if (array_length(_safe) > 0)
                        {
                            walk_path      = _safe;
                            walk_index     = 0;
                            path_allow_res = _allow_resource_path;
                            path_cooldown  = irandom_range(20, 45);
                        }
                    }
                }
            }

            // Fallback wiggle
            if (array_length(walk_path) == 0)
            {
                for (var _i = 0; _i < 12; _i++)
                {
                    var _wx = grid_x + irandom_range(-2, 2);
                    var _wy = grid_y + irandom_range(-2, 2);
                    if (_wx == grid_x && _wy == grid_y) continue;
                    if (!scr_tile_allowed_for_unit(self, _wx, _wy)) continue;
                    if (!scr_line_is_clear(grid_x, grid_y, _wx, _wy, unit_class)) continue;
                    walk_path      = [[_wx, _wy]];
                    walk_index     = 0;
                    path_allow_res = false;
                    path_cooldown  = irandom_range(5, 15);
                    break;
                }
            }

            if (array_length(walk_path) == 0) wander_pause_timer = 15;
        }
    }
}
// ============================================================
// 2. MOVEMENT
// ============================================================
var _moving = false;

if (walk_index < array_length(walk_path))
{
    var _target_gx = walk_path[walk_index][0];
    var _target_gy = walk_path[walk_index][1];

    // STEP CLAMP: never step outside village bounds unless the unit
    // is allowed to leave the village.
    if (village_id != -1 && !can_leave_territory && !path_allow_res)
    {
        var _v = global.villages[village_id];
        if (_target_gx < _v.left || _target_gx > _v.right
         || _target_gy < _v.top  || _target_gy > _v.bottom)
        {
            walk_path          = [];
            walk_index         = 0;
            path_allow_res     = false;
            wander_pause_timer = 5;
        }
    }

    if (!scr_tile_allowed_for_unit(self, _target_gx, _target_gy, path_allow_res))
    {
        walk_path          = [];
        walk_index         = 0;
        path_allow_res     = false;
        wander_pause_timer = 5;
    }
    else
    {
        var _tx   = _target_gx * obj_world.tile_size;
        var _ty   = _target_gy * obj_world.tile_size;
        var _dx   = _tx - x;
        var _dy   = _ty - y;
        var _dist = point_distance(x, y, _tx, _ty);

        if (_dist <= move_speed)
        {
            x        = _tx;
            y        = _ty;
            grid_x   = _target_gx;
            grid_y   = _target_gy;
            walk_index++;

            if (walk_index >= array_length(walk_path))
            {
                walk_path          = [];
                walk_index         = 0;
                path_allow_res     = false;
                wander_pause_timer = irandom_range(wander_pause_min, wander_pause_max);
            }
        }
        else
        {
            x += (_dx / _dist) * move_speed;
            y += (_dy / _dist) * move_speed;
            _moving = true;
            if (abs(_dx) > 0.1) image_xscale = sign(_dx);
        }
    }
}

// ============================================================
// 3. STATE + SPRITE
// ============================================================
state = _moving ? "walk" : "idle";

var _target_spr = (state == "walk") ? spr_walk : spr_idle;

if (sprite_index != _target_spr) {
    sprite_index = _target_spr;
    image_index  = 0;
}