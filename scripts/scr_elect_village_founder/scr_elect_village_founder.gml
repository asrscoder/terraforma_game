/// @func scr_beacon_is_eligible(_u)
/// @desc True if this unit is allowed to participate in founding elections.
function scr_beacon_is_eligible(_u)
{
    if (!instance_exists(_u))              return false;
    if (_u.village_id != -1)               return false;

    // Only villagers can be beacons. Promoted leaders must not become beacons,
    // otherwise the beacon flips every scan and causes churn.
    if (_u.unit_type != "villager") return false;

    // Skip colonists actively marching to a rally point.
    if (_u.kingdom_id != -1)
    {
        var _k = global.kingdoms[_u.kingdom_id];
        if (_k.expansion_rally_active)     return false;
    }

    // Skip units that are clearly broken / not yet placed.
    if (_u.x <= 0 && _u.y <= 0)             return false;
    if (_u.grid_x <= 0 && _u.grid_y <= 0)   return false;
    if (_u.walk_path == undefined)          return false;

    return true;
}

/// @func scr_elect_village_founder(_units, _count)
/// @desc Elects the lowest-id eligible unaffiliated villager/leader as the
///       founding beacon. Stranded groups are handled by the promotion and
///       reconciliation pass in scr_try_form_villages.
function scr_elect_village_founder(_units, _count)
{
    var _lead = noone;

    for (var _i = 0; _i < _count; _i++)
    {
        var _u = _units[_i];
        if (!scr_beacon_is_eligible(_u)) continue;

        if (_lead == noone || _u.id < _lead.id) _lead = _u;
    }

    return _lead;
}
