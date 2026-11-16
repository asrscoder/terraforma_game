/// @func scr_house_fits(_v, _gx, _gy)
/// @desc Returns true if a 2x2 house can be placed with its bottom-left
///       tile at (_gx, _gy). Checks the 2x2 footprint, then a 1-tile gap
///       from all other buildings.
function scr_house_fits(_v, _gx, _gy)
{
    // 2x2 footprint check
    if (!scr_rect_can_place_building(_v, _gx, _gy, _gx + 1, _gy + 1))
        return false;

    // 1-tile gap check from every other building (one lookup, not a scan)
    return !scr_bpad_hit(_gx, _gy, _gx + 1, _gy + 1);
}