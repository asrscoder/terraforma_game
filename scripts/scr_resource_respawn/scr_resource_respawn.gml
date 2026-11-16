/// @file scr_resource_respawn
/// @desc Resource regrowth (layer 1) and capped spread (layer 2).
///
///       Layer 1: every harvested tree/stone tile is queued and regrows on the
///                same tile after a delay, provided the tile is still free.
///       Layer 2: every few seconds one new tree/stone tries to grow next to an
///                existing one, but only while the total (present + pending
///                regrowth) is below the world's cap.
///
///       Counters are maintained incrementally so no full-world scans happen
///       after init. The world can therefore never exceed its starting density
///       by more than the small cap headroom defined in scr_resource_respawn_init.

/// @func scr_resource_respawn_init()
/// @desc Counts the generated resources, sets the caps and resets all timers.
///       Call once at the end of obj_world Create.
function scr_resource_respawn_init()
{
    // Runs inside obj_world's Create event: bare identifiers below are the
    // world instance's own variables (obj_world is not reliably resolvable
    // while its Create is still executing).
    var _count = array_length(resource_grid);
    var _trees = 0;
    var _stones = 0;
    var _irons = 0;

    for (var _i = 0; _i < _count; _i++)
    {
        var _res = resource_grid[_i];
        if (_res == RESOURCE.TREE)       _trees++;
        else if (_res == RESOURCE.STONE) _stones++;
        else if (_res == RESOURCE.IRON)  _irons++;
    }

    // Present resources
    tree_count  = _trees;
    stone_count = _stones;
    iron_count  = _irons;

    // Resources waiting to regrow (counted against the cap so spread cannot
    // steal room from tiles that are already owed a regrow)
    tree_pending  = 0;
    stone_pending = 0;
    iron_pending  = 0;

    // Small headroom above the generated world. Layer 2 slowly fills this,
    // then stops forever. 10% / 15% is roughly 380 trees and 110 stone.
    tree_cap  = round(_trees  * 1.10);
    stone_cap = round(_stones * 1.15);
    iron_cap  = round(_irons  * 1.10);

    // Pending regrowth queue: array of { idx, res, t, tries }
    regrow_queue = array_create(0);
    regrow_tick  = 0;

    // Layer 2 timers (frames at the current room speed). Tune these two if the
    // world should fill its headroom faster or slower.
    respawn_tree_interval  = 5 * 60;   // 5 s  -> one tree attempt
    respawn_stone_interval = 10 * 60;  // 10 s -> one stone attempt
    respawn_iron_interval  = 15 * 60;  // 15 s -> one iron attempt
    respawn_tree_timer     = respawn_tree_interval;
    respawn_stone_timer    = respawn_stone_interval;
    respawn_iron_timer     = respawn_iron_interval;
}

/// @func scr_resource_can_place(_idx, _res)
/// @desc True when a resource of type _res may occupy tile _idx.
function scr_resource_can_place(_idx, _res)
{
    if (_idx < 0 || _idx >= array_length(obj_world.terrain_grid)) return false;

    if (obj_world.resource_grid[_idx] != RESOURCE.NONE) return false;
    if (obj_world.block_grid[_idx]    != 0)             return false;

    var _terrain = obj_world.terrain_grid[_idx];

    if (_res == RESOURCE.TREE)
    {
        return (_terrain == TERRAIN.GRASS);
    }

    if (_res == RESOURCE.STONE)
    {
        return (_terrain == TERRAIN.GRASS || _terrain == TERRAIN.SAND);
    }

    if (_res == RESOURCE.IRON)
    {
        return (_terrain == TERRAIN.GRASS || _terrain == TERRAIN.SAND);
    }

    return false;
}

/// @func scr_resource_place(_idx, _res)
/// @desc Puts a resource on a tile and updates the live counter.
function scr_resource_place(_idx, _res)
{
    obj_world.resource_grid[_idx] = _res;
    obj_world.block_grid[_idx]    = 1;

    if (_res == RESOURCE.TREE)       obj_world.tree_count++;
    else if (_res == RESOURCE.STONE) obj_world.stone_count++;
    else if (_res == RESOURCE.IRON)  obj_world.iron_count++;
}

/// @func scr_resource_pending_remove(_res)
/// @desc Drops one pending regrow from the cap reservation.
function scr_resource_pending_remove(_res)
{
    if (_res == RESOURCE.TREE)
    {
        obj_world.tree_pending = max(0, obj_world.tree_pending - 1);
    }
    else if (_res == RESOURCE.STONE)
    {
        obj_world.stone_pending = max(0, obj_world.stone_pending - 1);
    }
    else if (_res == RESOURCE.IRON)
    {
        obj_world.iron_pending = max(0, obj_world.iron_pending - 1);
    }
}

/// @func scr_resource_harvested(_idx, _res)
/// @desc Clears a harvested tile, updates counters and queues its regrowth.
///       Called from scr_try_harvest.
function scr_resource_harvested(_idx, _res)
{
    if (_res != RESOURCE.TREE && _res != RESOURCE.STONE && _res != RESOURCE.IRON) return;

    obj_world.resource_grid[_idx] = RESOURCE.NONE;
    obj_world.block_grid[_idx]    = 0;

    var _delay;

    if (_res == RESOURCE.TREE)
    {
        obj_world.tree_count   = max(0, obj_world.tree_count - 1);
        obj_world.tree_pending = obj_world.tree_pending + 1;
        _delay = irandom_range(20 * 60, 35 * 60);   // 20-35 s
    }
    else if (_res == RESOURCE.STONE)
    {
        obj_world.stone_count   = max(0, obj_world.stone_count - 1);
        obj_world.stone_pending = obj_world.stone_pending + 1;
        _delay = irandom_range(40 * 60, 60 * 60);   // 40-60 s
    }
    else
    {
        obj_world.iron_count   = max(0, obj_world.iron_count - 1);
        obj_world.iron_pending = obj_world.iron_pending + 1;
        _delay = irandom_range(60 * 60, 90 * 60);   // 60-90 s
    }

    array_push(obj_world.regrow_queue, {
        idx:   _idx,
        res:   _res,
        t:     _delay,
        tries: 0,
    });
}

/// @func scr_resource_try_spread(_res)
/// @desc Grows one resource next to an existing resource of the same type.
///       Only free, unclaimed tiles are used so forests do not sprout inside
///       village territory and block building placement.
///       Returns true when a resource was added.
function scr_resource_try_spread(_res)
{
    var _w     = obj_world.world_width;
    var _h     = obj_world.world_height;
    var _total = _w * _h;

    // === Find a random existing resource to grow next to ===
    var _src = -1;
    repeat (40)
    {
        var _r = irandom(_total - 1);
        if (obj_world.resource_grid[_r] == _res)
        {
            _src = _r;
            break;
        }
    }

    if (_src == -1) return false;

    var _sx = _src mod _w;
    var _sy = _src div _w;

    static _dx = [ 1,  1,  0, -1, -1, -1,  0,  1];
    static _dy = [ 0,  1,  1,  1,  0, -1, -1, -1];
    var _start = irandom(7);

    for (var _k = 0; _k < 8; _k++)
    {
        var _o  = (_start + _k) mod 8;
        var _nx = _sx + _dx[_o];
        var _ny = _sy + _dy[_o];

        if (_nx < 0 || _nx >= _w || _ny < 0 || _ny >= _h) continue;

        var _idx = _nx + _ny * _w;

        if (!scr_resource_can_place(_idx, _res)) continue;

        // Keep village interiors clear; regrowth (layer 1) still works there.
        if (obj_world.territory_grid[_idx] != -1) continue;

        scr_resource_place(_idx, _res);
        return true;
    }

    return false;
}

/// @func scr_tick_resource_respawn()
/// @desc Frame tick: advances the regrow queue and runs the capped spread
///       attempts. Call from obj_world Step.
function scr_tick_resource_respawn()
{
    if (global.is_paused) return;

    // === Layer 2: slow capped spread ===
    obj_world.respawn_tree_timer--;
    if (obj_world.respawn_tree_timer <= 0)
    {
        obj_world.respawn_tree_timer = obj_world.respawn_tree_interval;

        if (obj_world.tree_count + obj_world.tree_pending < obj_world.tree_cap)
        {
            scr_resource_try_spread(RESOURCE.TREE);
        }
    }

    obj_world.respawn_stone_timer--;
    if (obj_world.respawn_stone_timer <= 0)
    {
        obj_world.respawn_stone_timer = obj_world.respawn_stone_interval;

        if (obj_world.stone_count + obj_world.stone_pending < obj_world.stone_cap)
        {
            scr_resource_try_spread(RESOURCE.STONE);
        }
    }

    obj_world.respawn_iron_timer--;
    if (obj_world.respawn_iron_timer <= 0)
    {
        obj_world.respawn_iron_timer = obj_world.respawn_iron_interval;

        if (obj_world.iron_count + obj_world.iron_pending < obj_world.iron_cap)
        {
            scr_resource_try_spread(RESOURCE.IRON);
        }
    }

    // === Layer 1: regrow mined tiles ===
    // Processed once per second so a long queue stays cheap; a regrow tile is
    // only ever off by less than one second.
    obj_world.regrow_tick--;
    if (obj_world.regrow_tick > 0) return;
    obj_world.regrow_tick = 60;

    for (var _i = array_length(obj_world.regrow_queue) - 1; _i >= 0; _i--)
    {
        var _e = obj_world.regrow_queue[_i];

        _e.t -= 60;
        if (_e.t > 0) continue;

        if (scr_resource_can_place(_e.idx, _e.res))
        {
            scr_resource_place(_e.idx, _e.res);
            scr_resource_pending_remove(_e.res);
            array_delete(obj_world.regrow_queue, _i, 1);
        }
        else
        {
            // Something was built on the tile, or another resource is there.
            _e.tries++;
            if (_e.tries >= 3)
            {
                scr_resource_pending_remove(_e.res);
                array_delete(obj_world.regrow_queue, _i, 1);
            }
            else
            {
                _e.t = 5 * 60;   // retry in 5 s
            }
        }
    }
}
