/// @func scr_mark_coastal_water(_gx, _gy)
/// @desc Marks adjacent water tiles as coastal so a port system can find them.
function scr_mark_coastal_water(_gx, _gy)
{
    var _w = obj_world.world_width;
    var _h = obj_world.world_height;

    // Lazy-create the grid so obj_world/Create_0.gml does not need editing.
    if (!variable_instance_exists(obj_world, "coastal_grid"))
    {
        obj_world.coastal_grid = array_create(_w * _h, 0);
    }

    // Direction tables are static: they used to be rebuilt (two array
    // allocations) on every call, and this function runs up to a few hundred
    // times per expansion scan.
    static _dx = [0, 1, 0, -1];
    static _dy = [-1, 0, 1, 0];

    for (var _i = 0; _i < 4; _i++)
    {
        var _nx = _gx + _dx[_i];
        var _ny = _gy + _dy[_i];

        if (_nx < 0 || _nx >= _w || _ny < 0 || _ny >= _h) continue;

        var _idx = _nx + _ny * _w;
        if (obj_world.terrain_grid[_idx] == TERRAIN.WATER)
        {
            obj_world.coastal_grid[_idx] = 1;
        }
    }
}

/// @func scr_ocean_depth_at(_v, _gx, _gy)
/// @desc How deep into the ocean a water tile sits relative to one village's
///       shore, measured by walking out through already-claimed water:
///         0   — the tile is land (it is the shore itself)
///         1.. — first, second, ... water tile out to sea
///         -1  — not connected to this village, so it cannot be claimed yet
///       Depth is cached in obj_world.water_depth_grid when a tile is claimed,
///       which keeps the check O(1) instead of scanning a radius per tile.
function scr_ocean_depth_at(_v, _gx, _gy)
{
    var _w = obj_world.world_width;
    var _h = obj_world.world_height;

    if (obj_world.terrain_grid[_gx + _gy * _w] != TERRAIN.WATER) return 0;

    if (!variable_instance_exists(obj_world, "water_depth_grid"))
    {
        obj_world.water_depth_grid = array_create(_w * _h, 0);
    }

    static _dx = [0, 1, 0, -1];
    static _dy = [-1, 0, 1, 0];

    var _best = -1;

    for (var _i = 0; _i < 4; _i++)
    {
        var _nx = _gx + _dx[_i];
        var _ny = _gy + _dy[_i];

        if (_nx < 0 || _nx >= _w || _ny < 0 || _ny >= _h) continue;

        var _nidx = _nx + _ny * _w;
        if (obj_world.territory_grid[_nidx] != _v.id) continue;

        var _d = 0;
        if (obj_world.terrain_grid[_nidx] == TERRAIN.WATER)
        {
            _d = obj_world.water_depth_grid[_nidx];
            if (_d < 1) _d = 1;   // water claimed before depth tracking existed
        }

        if (_best == -1 || _d < _best) _best = _d;
    }

    if (_best == -1) return -1;
    return _best + 1;
}
