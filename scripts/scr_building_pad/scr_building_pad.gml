/// Padded building occupancy grid.
///
/// Every building placement test used to do a "1-tile gap from every other
/// building" check with `with (obj_building)` for each candidate tile. That is
/// O(candidate tiles x buildings) — the boat-port scan alone reached roughly
/// 384k instance iterations — and `with` is by far the most expensive way to
/// read four numbers.
///
/// Instead, obj_world keeps `building_pad_grid`, where each building marks its
/// footprint *expanded by the gap* in every direction. A candidate footprint
/// then only has to test its own tiles: a hit means some building sits within
/// the gap. That is one array read per tile and exactly equivalent to the old
/// AABB test (`candidate footprint + pad` vs `building footprint`, inclusive).
///
/// Nothing in the game removes a building, but scr_bpad_remove() exists so
/// demolition never silently corrupts the grid. The grid stores counts, not
/// flags, so overlapping pads unwind correctly.

/// @func scr_bpad_init()
/// @desc Creates the padded grid if it is missing. obj_world/Create_0 makes it
///       up front; this is only the safety net for call order changes.
function scr_bpad_init()
{
    if (!instance_exists(obj_world)) return;

    if (!variable_instance_exists(obj_world, "building_pad_grid"))
    {
        obj_world.building_pad_grid =
            array_create(obj_world.world_width * obj_world.world_height, 0);
    }
}

/// @func scr_bpad_add(_inst, _gap)
/// @desc Marks _inst's footprint plus _gap tiles around it. Call once, right
///       after a building's footprint_left/top/right/bottom have been set.
///       _gap defaults to 1, which is the spacing every placement test uses.
function scr_bpad_add(_inst, _gap = 1)
{
    if (!instance_exists(_inst)) return;

    scr_bpad_init();

    var _w = obj_world.world_width;
    var _h = obj_world.world_height;
    var _grid = obj_world.building_pad_grid;

    var _l = max(0,     _inst.footprint_left   - _gap);
    var _t = max(0,     _inst.footprint_top    - _gap);
    var _r = min(_w - 1, _inst.footprint_right  + _gap);
    var _b = min(_h - 1, _inst.footprint_bottom + _gap);

    for (var _gy = _t; _gy <= _b; _gy++)
    {
        var _row = _gy * _w;

        for (var _gx = _l; _gx <= _r; _gx++)
        {
            _grid[_gx + _row] += 1;
        }
    }
}

/// @func scr_bpad_remove(_inst, _gap)
/// @desc Clears what scr_bpad_add() marked. Only needed if buildings can ever
///       be destroyed; the counters guard against double-removal.
function scr_bpad_remove(_inst, _gap = 1)
{
    if (!instance_exists(_inst)) return;

    scr_bpad_init();

    var _w = obj_world.world_width;
    var _h = obj_world.world_height;
    var _grid = obj_world.building_pad_grid;

    var _l = max(0,     _inst.footprint_left   - _gap);
    var _t = max(0,     _inst.footprint_top    - _gap);
    var _r = min(_w - 1, _inst.footprint_right  + _gap);
    var _b = min(_h - 1, _inst.footprint_bottom + _gap);

    for (var _gy = _t; _gy <= _b; _gy++)
    {
        var _row = _gy * _w;

        for (var _gx = _l; _gx <= _r; _gx++)
        {
            var _idx = _gx + _row;
            if (_grid[_idx] > 0) _grid[_idx] -= 1;
        }
    }
}

/// @func scr_bpad_hit(_left, _top, _right, _bottom)
/// @desc True when a building (or its gap) overlaps the tile rect
///       (_left, _top) to (_right, _bottom) inclusive. This replaces the
///       per-tile `with (obj_building)` AABB loop in every *_fits script.
function scr_bpad_hit(_left, _top, _right, _bottom)
{
    scr_bpad_init();

    var _w = obj_world.world_width;
    var _h = obj_world.world_height;
    var _grid = obj_world.building_pad_grid;

    var _l = max(0, _left);
    var _t = max(0, _top);
    var _r = min(_w - 1, _right);
    var _b = min(_h - 1, _bottom);

    for (var _gy = _t; _gy <= _b; _gy++)
    {
        var _row = _gy * _w;

        for (var _gx = _l; _gx <= _r; _gx++)
        {
            if (_grid[_gx + _row] > 0) return true;
        }
    }

    return false;
}
