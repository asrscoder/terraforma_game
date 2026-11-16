/// @func scr_find_house_spot(_village_id)
/// @desc Returns [gx, gy] for the best house placement tile, or [-1, -1]
///       if none found. Prefers tiles near the town hall with randomness.
function scr_find_house_spot(_village_id)
{
    var _v = global.villages[_village_id];

    var _best = [-1, -1];
    var _best_dist = 999999;

    for (var _gy = _v.top; _gy <= _v.bottom - 1; _gy++)
    {
        for (var _gx = _v.left; _gx <= _v.right - 1; _gx++)
        {
            if (!scr_house_fits(_v, _gx, _gy)) continue;

            var _d = point_distance(_gx, _gy, _v.cx, _v.cy);

            // Distance-based with random tie-break
            if (_d < _best_dist || (_d == _best_dist && irandom(1) == 0))
            {
                _best_dist = _d;
                _best      = [_gx, _gy];
            }
        }
    }

    return _best;
}

/// @func scr_watchtower_fits(_v, _gx, _gy)
/// @desc Returns true if a 1x2 watchtower can be placed with its top tile
///       at (_gx, _gy). Checks the footprint, then a 1-tile gap from all
///       other buildings.
function scr_watchtower_fits(_v, _gx, _gy)
{
    // 1x2 footprint check
    if (!scr_rect_can_place_building(_v, _gx, _gy, _gx, _gy + 1))
        return false;

    // 1-tile gap check from every other building (one lookup, not a scan)
    return !scr_bpad_hit(_gx, _gy, _gx, _gy + 1);
}

/// @func scr_find_watchtower_spot(_village_id)
/// @desc Returns [gx, gy] for the best 1x2 watchtower top tile, or [-1, -1].
///       Prefers a ring around the village centre so towers sit towards the
///       outskirts instead of on top of the town hall.
function scr_find_watchtower_spot(_village_id)
{
    var _v = global.villages[_village_id];

    var _best       = [-1, -1];
    var _best_score = 999999;

    // Preferred distance (tiles) from the village centre.
    var _ring = 7;

    for (var _gy = _v.top; _gy <= _v.bottom - 1; _gy++)
    {
        for (var _gx = _v.left; _gx <= _v.right; _gx++)
        {
            if (!scr_watchtower_fits(_v, _gx, _gy)) continue;

            var _d     = point_distance(_gx, _gy, _v.cx, _v.cy);
            var _score = abs(_d - _ring);

            // Distance-based with random tie-break
            if (_score < _best_score || (_score == _best_score && irandom(1) == 0))
            {
                _best_score = _score;
                _best       = [_gx, _gy];
            }
        }
    }

    return _best;
}

/// @func scr_mine_fits(_v, _gx, _gy)
/// @desc Returns true if a 1x1 mine can be placed at (_gx, _gy): a free,
///       in-territory tile with a 1-tile gap from every other building.
function scr_mine_fits(_v, _gx, _gy)
{
    if (!scr_rect_can_place_building(_v, _gx, _gy, _gx, _gy)) return false;

    return !scr_bpad_hit(_gx, _gy, _gx, _gy);
}

/// @func scr_find_mine_spot(_village_id)
/// @desc Returns [gx, gy] for the best 1x1 mine tile, or [-1, -1].
///       Strongly prefers a tile adjacent to stone or iron so the mine sits
///       against ore; otherwise falls back to a ring near the village edge.
function scr_find_mine_spot(_village_id)
{
    var _v = global.villages[_village_id];

    var _best       = [-1, -1];
    var _best_score = 999999;
    var _ring       = 5;

    var _w = obj_world.world_width;
    var _h = obj_world.world_height;

    var _min_x = max(0, _v.left);
    var _max_x = min(_w - 1, _v.right);
    var _min_y = max(0, _v.top);
    var _max_y = min(_h - 1, _v.bottom);

    for (var _gy = _min_y; _gy <= _max_y; _gy++)
    {
        for (var _gx = _min_x; _gx <= _max_x; _gx++)
        {
            if (!scr_mine_fits(_v, _gx, _gy)) continue;

            // Is this tile adjacent to a stone or iron deposit?
            var _ore = false;
            for (var _oy = -1; _oy <= 1 && !_ore; _oy++)
            {
                for (var _ox = -1; _ox <= 1; _ox++)
                {
                    if (_ox == 0 && _oy == 0) continue;

                    var _nx = _gx + _ox;
                    var _ny = _gy + _oy;
                    if (_nx < 0 || _nx >= _w || _ny < 0 || _ny >= _h) continue;

                    var _res = obj_world.resource_grid[_nx + _ny * _w];
                    if (_res == RESOURCE.STONE || _res == RESOURCE.IRON)
                    {
                        _ore = true;
                        break;
                    }
                }
            }

            var _d     = point_distance(_gx, _gy, _v.cx, _v.cy);
            var _score = _ore ? (_d - 1000) : abs(_d - _ring);

            // Distance-based with random tie-break
            if (_score < _best_score || (_score == _best_score && irandom(1) == 0))
            {
                _best_score = _score;
                _best       = [_gx, _gy];
            }
        }
    }

    return _best;
}

/// @func scr_workshop_fits(_v, _gx, _gy)
/// @desc Returns true if a 2x2 workshop can be placed with its top-left tile
///       at (_gx, _gy): free land inside the village with a 1-tile gap from
///       every other building.
function scr_workshop_fits(_v, _gx, _gy)
{
    if (!scr_rect_can_place_building(_v, _gx, _gy, _gx + 1, _gy + 1)) return false;

    return !scr_bpad_hit(_gx, _gy, _gx + 1, _gy + 1);
}

/// @func scr_find_workshop_spot(_village_id)
/// @desc Returns [gx, gy] for the best 2x2 workshop top-left tile, or [-1,-1].
///       Prefers a ring around the village centre so workshops sit among the
///       working buildings instead of taking the plots next to the hall.
function scr_find_workshop_spot(_village_id)
{
    var _v = global.villages[_village_id];

    var _best       = [-1, -1];
    var _best_score = 999999;

    // Preferred distance (tiles) from the village centre.
    var _ring = 6;

    for (var _gy = _v.top; _gy <= _v.bottom - 1; _gy++)
    {
        for (var _gx = _v.left; _gx <= _v.right - 1; _gx++)
        {
            if (!scr_workshop_fits(_v, _gx, _gy)) continue;

            var _d     = point_distance(_gx + 0.5, _gy + 0.5, _v.cx, _v.cy);
            var _score = abs(_d - _ring);

            // Distance-based with random tie-break
            if (_score < _best_score || (_score == _best_score && irandom(1) == 0))
            {
                _best_score = _score;
                _best       = [_gx, _gy];
            }
        }
    }

    return _best;
}

/// @func scr_barracks_fits(_v, _gx, _gy)
/// @desc 3x3 fit test for a barracks site.
function scr_barracks_fits(_v, _gx, _gy)
{
    if (!scr_rect_can_place_building(_v, _gx, _gy, _gx + 2, _gy + 2)) return false;
    return !scr_bpad_hit(_gx, _gy, _gx + 2, _gy + 2);
}

/// @func scr_find_barracks_spot(_village_id)
/// @desc Returns [gx, gy] top-left of a 3x3 barracks plot, or [-1,-1].
function scr_find_barracks_spot(_village_id)
{
    var _v = global.villages[_village_id];

    var _best       = [-1, -1];
    var _best_score = 999999;
    var _ring = 6;

    for (var _gy = _v.top; _gy <= _v.bottom - 2; _gy++)
    {
        for (var _gx = _v.left; _gx <= _v.right - 2; _gx++)
        {
            if (!scr_barracks_fits(_v, _gx, _gy)) continue;

            var _d     = point_distance(_gx + 1, _gy + 1, _v.cx, _v.cy);
            var _score = abs(_d - _ring);

            if (_score < _best_score || (_score == _best_score && irandom(1) == 0))
            {
                _best_score = _score;
                _best       = [_gx, _gy];
            }
        }
    }

    return _best;
}
/// @desc Sprite rotation (degrees) for a port facing. A port is always 2x2
///       tiles; only which half is ocean changes.
///         0 = ocean south (pier points down)  ->   0 deg
///         1 = ocean east  (pier points right) ->  90 deg
///         2 = ocean north (pier points up)    -> 180 deg
///         3 = ocean west  (pier points left)  -> 270 deg
/// @func scr_farm_fits(_v, _gx, _gy)
/// @desc 2x2 fit test for a farm site.
function scr_farm_fits(_v, _gx, _gy)
{
    if (!scr_rect_can_place_building(_v, _gx, _gy, _gx + 1, _gy + 1)) return false;
    return !scr_bpad_hit(_gx, _gy, _gx + 1, _gy + 1);
}

/// @func scr_find_farm_spot(_village_id)
/// @desc Returns [gx, gy] top-left of a 2x2 farm plot, or [-1,-1].
function scr_find_farm_spot(_village_id)
{
    var _v = global.villages[_village_id];

    var _best       = [-1, -1];
    var _best_score = 999999;
    var _ring = 6;

    for (var _gy = _v.top; _gy <= _v.bottom - 1; _gy++)
    {
        for (var _gx = _v.left; _gx <= _v.right - 1; _gx++)
        {
            if (!scr_farm_fits(_v, _gx, _gy)) continue;

            var _d     = point_distance(_gx + 0.5, _gy + 0.5, _v.cx, _v.cy);
            var _score = abs(_d - _ring);

            if (_score < _best_score || (_score == _best_score && irandom(1) == 0))
            {
                _best_score = _score;
                _best       = [_gx, _gy];
            }
        }
    }

    return _best;
}

function scr_port_dir_angle(_dir)
{
    switch (_dir)
    {
        case 1: return 90;
        case 2: return 180;
        case 3: return 270;
    }
    return 0;
}

/// @func scr_port_house_anchor(_dir, _gx, _gy, _w, _h)
/// @desc Bottom-centre screen position for the upright port house. The house
///       always sits on the shoreline and extends inland, so it never rotates.
///       _gx/_gy are the port's top-left tile; _w/_h the house sprite size.
function scr_port_house_anchor(_dir, _gx, _gy, _w, _h)
{
    var _ts    = obj_world.tile_size;
    var _mid_x = _gx * _ts + _ts;   // shoreline between the two tile columns
    var _mid_y = _gy * _ts + _ts;   // shoreline between the two tile rows

    switch (_dir)
    {
        case 1: // ocean east: house right edge on the shore, body extends west
            return [_mid_x - _w * 0.5, _mid_y + _h * 0.5];

        case 2: // ocean north: house top edge on the shore, body extends south
            return [_mid_x, _mid_y + _h];

        case 3: // ocean west: house left edge on the shore, body extends east
            return [_mid_x + _w * 0.5, _mid_y + _h * 0.5];
    }

    // ocean south: house bottom edge on the shore, body extends north
    return [_mid_x, _mid_y];
}

/// @func scr_port_pier_anchor(_dir, _gx, _gy)
/// @desc Centre screen position for the port pier sprite (origin = centre).
///       The pier fills the ocean half of the 2x2 footprint.
function scr_port_pier_anchor(_dir, _gx, _gy)
{
    var _ts    = obj_world.tile_size;
    var _mid_x = _gx * _ts + _ts;
    var _mid_y = _gy * _ts + _ts;
    var _q     = _ts * 0.5;         // centre of one footprint half

    switch (_dir)
    {
        case 1: return [_mid_x + _q, _mid_y]; // ocean east
        case 2: return [_mid_x, _mid_y - _q]; // ocean north
        case 3: return [_mid_x - _q, _mid_y]; // ocean west
    }

    return [_mid_x, _mid_y + _q];         // ocean south
}

/// @func scr_port_water_tiles(_gx, _gy, _dir)
/// @desc Returns the two ocean tiles of a port footprint as [[x0,y0],[x1,y1]],
///       given its top-left tile and facing. Land tiles are the other half.
function scr_port_water_tiles(_gx, _gy, _dir)
{
    switch (_dir)
    {
        case 1: return [[_gx + 1, _gy],     [_gx + 1, _gy + 1]]; // east
        case 2: return [[_gx,     _gy],     [_gx + 1, _gy]];     // north
        case 3: return [[_gx,     _gy],     [_gx,     _gy + 1]]; // west
    }
    return [[_gx, _gy + 1], [_gx + 1, _gy + 1]];                 // south
}

/// @func scr_port_water_ok(_v, _wx, _wy)
/// @desc True if a tile can be the water half of a port: open ocean that is
///       not owned by another village. Villages only claim a thin fringe of
///       coast (and often never reach it), so the tile does not have to be
///       pre-claimed — scr_try_place_port() claims it on placement.
function scr_port_water_ok(_v, _wx, _wy)
{
    var _w = obj_world.world_width;

    if (_wx < 0 || _wx >= _w)                        return false;
    if (_wy < 0 || _wy >= obj_world.world_height)    return false;

    var _idx = _wx + _wy * _w;
    if (obj_world.terrain_grid[_idx] != TERRAIN.WATER) return false;
    if (obj_world.block_grid[_idx]   != 0)             return false;

    var _owner = obj_world.territory_grid[_idx];
    return (_owner == -1 || _owner == _v.id);
}

/// @func scr_port_fits(_v, _gx, _gy, _dir)
/// @desc True if a 2x2 boat port fits with its top-left tile at (_gx, _gy)
///       and its ocean half facing _dir. One half of the footprint must be
///       buildable land inside the village, the other half open ocean, plus
///       a 1-tile gap from every other building.
function scr_port_fits(_v, _gx, _gy, _dir = 0)
{
    var _lx0, _ly0, _lx1, _ly1;
    var _wx0, _wy0, _wx1, _wy1;

    switch (_dir)
    {
        case 1: // ocean east
            _lx0 = _gx;     _ly0 = _gy;     _lx1 = _gx;     _ly1 = _gy + 1;
            _wx0 = _gx + 1; _wy0 = _gy;     _wx1 = _gx + 1; _wy1 = _gy + 1;
            break;

        case 2: // ocean north
            _lx0 = _gx;     _ly0 = _gy + 1; _lx1 = _gx + 1; _ly1 = _gy + 1;
            _wx0 = _gx;     _wy0 = _gy;     _wx1 = _gx + 1; _wy1 = _gy;
            break;

        case 3: // ocean west
            _lx0 = _gx + 1; _ly0 = _gy;     _lx1 = _gx + 1; _ly1 = _gy + 1;
            _wx0 = _gx;     _wy0 = _gy;     _wx1 = _gx;     _wy1 = _gy + 1;
            break;

        default: // ocean south
            _lx0 = _gx;     _ly0 = _gy;     _lx1 = _gx + 1; _ly1 = _gy;
            _wx0 = _gx;     _wy0 = _gy + 1; _wx1 = _gx + 1; _wy1 = _gy + 1;
            break;
    }

    // Ocean first: it is the rarest condition, so non-shore tiles fail fast.
    if (!scr_port_water_ok(_v, _wx0, _wy0)) return false;
    if (!scr_port_water_ok(_v, _wx1, _wy1)) return false;

    // Land half: normal buildable territory.
    if (!scr_rect_can_place_building(_v, _lx0, _ly0, _lx0, _ly0)) return false;
    if (!scr_rect_can_place_building(_v, _lx1, _ly1, _lx1, _ly1)) return false;

    // 1-tile gap from every other building: one lookup over the 2x2 footprint
    // (the padding is the same for every facing, so the test is too).
    return !scr_bpad_hit(_gx, _gy, _gx + 1, _gy + 1);
}

/// @func scr_find_port_spot(_village_id)
/// @desc Returns [gx, gy, dir] for the best boat-port top-left tile, or
///       [-1, -1, 0]. Any of the four shoreline directions qualifies; the
///       spot closest to the village centre wins with a random tie-break.
function scr_find_port_spot(_village_id)
{
    var _v = global.villages[_village_id];

    var _w = obj_world.world_width;
    var _h = obj_world.world_height;

    var _min_x = max(0, _v.left);
    var _max_x = min(_w - 2, _v.right);
    var _min_y = max(0, _v.top);
    var _max_y = min(_h - 2, _v.bottom);

    var _best      = [-1, -1, 0];
    var _best_dist = 999999;

    for (var _gy = _min_y; _gy <= _max_y; _gy++)
    {
        for (var _gx = _min_x; _gx <= _max_x; _gx++)
        {
            for (var _dir = 0; _dir < 4; _dir++)
            {
                if (!scr_port_fits(_v, _gx, _gy, _dir)) continue;

                var _d = point_distance(_gx + 0.5, _gy + 0.5, _v.cx, _v.cy);

                if (_d < _best_dist || (_d == _best_dist && irandom(1) == 0))
                {
                    _best_dist = _d;
                    _best      = [_gx, _gy, _dir];
                }
            }
        }
    }

    return _best;
}

/// @func scr_village_can_host_port(_v)
/// @desc True if this village can currently fit a boat port anywhere on its
///       shore in any direction: a 2x2 footprint split into 2 in-territory
///       land tiles and 2 open ocean tiles, with a 1-tile gap from buildings.
///       This is the same predicate placement uses, so it answers "could a
///       port be built here at all?" — used to decide whether the port gate
///       applies to era advancement. Returns on the first fitting spot.
function scr_village_can_host_port(_v)
{
    var _w = obj_world.world_width;
    var _h = obj_world.world_height;

    var _min_x = max(0, _v.left);
    var _max_x = min(_w - 2, _v.right);
    var _min_y = max(0, _v.top);
    var _max_y = min(_h - 2, _v.bottom);

    for (var _gy = _min_y; _gy <= _max_y; _gy++)
    {
        for (var _gx = _min_x; _gx <= _max_x; _gx++)
        {
            for (var _dir = 0; _dir < 4; _dir++)
            {
                if (scr_port_fits(_v, _gx, _gy, _dir)) return true;
            }
        }
    }

    return false;
}