/// @file scr_find_path
/// @desc A* pathfinding with reusable scratch buffers.
///
///       The search used to keep its per-node data in structs keyed by
///       string(tile_index) and its frontier in a ds_priority. Every expanded
///       node therefore allocated strings and paid a hash lookup, and the
///       frontier churned a data structure per call. That made path generation
///       the dominant cost once a few hundred units were alive.
///
///       The version below stores the same data in flat arrays indexed by tile
///       index and uses a generation stamp instead of clearing those arrays
///       between calls, so a search allocates nothing at all. The public
///       signature and the returned path format are unchanged.

/// @func scr_pf_init()
/// @desc Allocates (or reshapes) the shared pathfinding buffers. Safe to call
///       on every search: it only does work when the world size changed.
function scr_pf_init()
{
    var _n = obj_world.world_width * obj_world.world_height;

    if (!variable_global_exists("pf_g")
     || array_length(global.pf_g) != _n)
    {
        global.pf_g      = array_create(_n, 0);    // best known cost from start
        global.pf_came   = array_create(_n, -1);   // parent tile index
        global.pf_stamp  = array_create(_n, 0);    // run id that last touched a tile
        global.pf_closed = array_create(_n, 0);    // run id that closed a tile
        global.pf_heap_i = array_create(0);        // frontier: tile indices
        global.pf_heap_p = array_create(0);        // frontier: priorities
        global.pf_gen    = 0;                      // monotonically increasing run id
    }
}

/// @func scr_pf_heap_push(_heap_i, _heap_p, _idx, _priority)
/// @desc Binary min-heap insert. Arrays are reference types, so the caller's
///       heap is updated in place.
function scr_pf_heap_push(_heap_i, _heap_p, _idx, _priority)
{
    array_push(_heap_i, _idx);
    array_push(_heap_p, _priority);

    var _n = array_length(_heap_i) - 1;

    while (_n > 0)
    {
        var _parent = (_n - 1) >> 1;
        if (_heap_p[_parent] <= _heap_p[_n]) break;

        var _ti = _heap_i[_parent];
        _heap_i[_parent] = _heap_i[_n];
        _heap_i[_n]      = _ti;

        var _tp = _heap_p[_parent];
        _heap_p[_parent] = _heap_p[_n];
        _heap_p[_n]      = _tp;

        _n = _parent;
    }
}

/// @func scr_pf_heap_pop(_heap_i, _heap_p)
/// @desc Removes and returns the lowest-priority tile index.
function scr_pf_heap_pop(_heap_i, _heap_p)
{
    var _end = array_length(_heap_i) - 1;
    var _top = _heap_i[0];

    // Move the last entry to the root, then drop the tail.
    _heap_i[0] = _heap_i[_end];
    _heap_p[0] = _heap_p[_end];
    array_pop(_heap_i);
    array_pop(_heap_p);

    _end--;                       // last valid index after the pop

    var _i = 0;
    while (_end >= 1)
    {
        var _l = _i * 2 + 1;
        if (_l > _end) break;

        var _r = _l + 1;
        var _m = _l;
        if (_r <= _end && _heap_p[_r] < _heap_p[_l]) _m = _r;

        if (_heap_p[_i] <= _heap_p[_m]) break;

        var _ti = _heap_i[_i];
        _heap_i[_i] = _heap_i[_m];
        _heap_i[_m] = _ti;

        var _tp = _heap_p[_i];
        _heap_p[_i] = _heap_p[_m];
        _heap_p[_m] = _tp;

        _i = _m;
    }

    return _top;
}

/// @func scr_pf_budget_init()
/// @desc Lazily creates the per-frame pathfinding budget globals. Safe to call
///       before obj_world has run its Create event.
function scr_pf_budget_init()
{
    if (!variable_global_exists("pf_budget_max")) global.pf_budget_max = 8;
    if (!variable_global_exists("pf_budget"))     global.pf_budget     = global.pf_budget_max;
}

/// @func scr_pf_take_budget()
/// @desc Claims one A* search from this frame's allowance. Ambient pathing
///       (unit wandering) asks for permission first so that a burst of units
///       deciding on the same frame cannot blow out the frame time.
///       Returns false when the allowance is spent: the caller should move on
///       and retry after its cooldown.
function scr_pf_take_budget()
{
    scr_pf_budget_init();

    if (global.pf_budget <= 0) return false;

    global.pf_budget--;
    return true;
}

/// @func scr_pf_reset_budget()
/// @desc Refills the per-frame allowance. Called from obj_game's End Step, so
///       the reset always happens after every unit has run its Step event.
function scr_pf_reset_budget()
{
    scr_pf_budget_init();
    global.pf_budget = global.pf_budget_max;
}

/// @func scr_find_path(_start_gx, _start_gy, _goal_gx, _goal_gy, _allow_resource_goal, _class, _budgeted)
/// @desc A* pathfinding (4-directional). _allow_resource_goal lets the path
///       enter resource tiles (miners / colonists). _class selects which
///       terrain the unit may cross ("land", "water", "air"). The search is
///       capped so an unreachable goal can't flood the whole island.
///       _budgeted = true makes the call count against the per-frame search
///       allowance (ambient wandering only). Returns [] when no path exists,
///       or (when _budgeted) when this frame's allowance is already spent.
function scr_find_path(_start_gx, _start_gy, _goal_gx, _goal_gy, _allow_resource_goal = false, _class = "land", _budgeted = false)
{
    var _w     = obj_world.world_width;
    var _h     = obj_world.world_height;
    var _grid  = obj_world.terrain_grid;
    var _block = obj_world.block_grid;
    var _res   = obj_world.resource_grid;

    if (_goal_gx < 0 || _goal_gx >= _w) return [];
    if (_goal_gy < 0 || _goal_gy >= _h) return [];

    if (_start_gx < 0 || _start_gx >= _w) return [];
    if (_start_gy < 0 || _start_gy >= _h) return [];

    var _goal_idx = _goal_gx + _goal_gy * _w;

    if (!scr_terrain_ok_for_class(_class, _grid[_goal_idx] == TERRAIN.WATER)) return [];

    if (_block[_goal_idx] == 1)
    {
        if (!_allow_resource_goal) return [];
        if (_res[_goal_idx] == RESOURCE.NONE) return [];
    }

    if (_start_gx == _goal_gx && _start_gy == _goal_gy) return [];

    // Ambient pathing is rate-limited so a burst of units deciding on the same
    // frame cannot stall the game. Callers that must not be refused (village
    // founding, miner targeting) leave _budgeted false and always get a search.
    if (_budgeted && !scr_pf_take_budget()) return [];

    // === Shared scratch buffers ===
    scr_pf_init();

    var _g      = global.pf_g;
    var _came   = global.pf_came;
    var _stamp  = global.pf_stamp;
    var _closed = global.pf_closed;
    var _heap_i = global.pf_heap_i;
    var _heap_p = global.pf_heap_p;

    // Any stamp from an earlier run is stale and treated as "unvisited".
    var _gen = ++global.pf_gen;

    var _start_idx = _start_gx + _start_gy * _w;

    _stamp[_start_idx]  = _gen;
    _closed[_start_idx] = 0;
    _g[_start_idx]      = 0;
    _came[_start_idx]   = -1;

    array_resize(_heap_i, 0);
    array_resize(_heap_p, 0);

    scr_pf_heap_push(_heap_i, _heap_p, _start_idx,
        scr_heuristic(_start_gx, _start_gy, _goal_gx, _goal_gy));

    static _dx = [ 0, 1, 0, -1];
    static _dy = [-1, 0, 1,  0];

    var _iter     = 0;
    var _max_iter = 12000;

    while (array_length(_heap_i) > 0)
    {
        if (++_iter > _max_iter) break;

        var _current = scr_pf_heap_pop(_heap_i, _heap_p);

        // A tile can be queued more than once; only the first pop matters.
        if (_stamp[_current] != _gen)  continue;
        if (_closed[_current] == _gen) continue;
        _closed[_current] = _gen;

        if (_current == _goal_idx)
        {
            return scr_reconstruct_path(_came, _start_idx, _goal_idx);
        }

        var _cx = _current mod _w;
        var _cy = _current div _w;
        var _cg = _g[_current];

        for (var _i = 0; _i < 4; _i++)
        {
            var _nx = _cx + _dx[_i];
            var _ny = _cy + _dy[_i];

            if (_nx < 0 || _nx >= _w) continue;
            if (_ny < 0 || _ny >= _h) continue;

            var _n_idx = _nx + _ny * _w;

            if (_block[_n_idx] == 1)
            {
                var _is_resource = (_res[_n_idx] != RESOURCE.NONE);
                if (!(_allow_resource_goal && _is_resource)) continue;
            }

            if (!scr_terrain_ok_for_class(_class, _grid[_n_idx] == TERRAIN.WATER)) continue;

            if (_stamp[_n_idx] == _gen && _closed[_n_idx] == _gen) continue;

            var _tentative_g = _cg + 1;
            var _known       = (_stamp[_n_idx] == _gen);

            if (!_known || _tentative_g < _g[_n_idx])
            {
                if (!_known)
                {
                    _stamp[_n_idx]  = _gen;
                    _closed[_n_idx] = 0;
                }

                _g[_n_idx]    = _tentative_g;
                _came[_n_idx] = _current;

                scr_pf_heap_push(_heap_i, _heap_p, _n_idx,
                    _tentative_g + scr_heuristic(_nx, _ny, _goal_gx, _goal_gy));
            }
        }
    }

    return [];
}

/// @func scr_heuristic(_ax, _ay, _bx, _by)
function scr_heuristic(_ax, _ay, _bx, _by)
{
    return abs(_ax - _bx) + abs(_ay - _by);
}

/// @func scr_reconstruct_path(_came_from, _start_idx, _goal_idx)
/// @desc Walks the parent chain back to the start. Built goal-first and then
///       reversed: array_insert(_path, 0, ...) shifted the whole array on
///       every step and cost more than the search itself on long paths.
function scr_reconstruct_path(_came_from, _start_idx, _goal_idx)
{
    var _w    = obj_world.world_width;
    var _path = [];

    var _current = _goal_idx;
    var _guard   = 0;

    while (_current != _start_idx && _current >= 0 && ++_guard <= 10000)
    {
        array_push(_path, [_current mod _w, _current div _w]);
        _current = _came_from[_current];
    }

    var _n = array_length(_path);
    for (var _i = 0; _i < (_n >> 1); _i++)
    {
        var _tmp          = _path[_i];
        _path[_i]         = _path[_n - 1 - _i];
        _path[_n - 1 - _i] = _tmp;
    }

    return _path;
}
