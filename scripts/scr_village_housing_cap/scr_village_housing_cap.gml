/// @func scr_village_housing_cap(_v)
/// @desc Max population for a village: the 50 base plus one bed per bed-granting
///       building. The bed counts come from scr_housing_beds_for(), the same
///       numbers scr_housing_tick() hands out as beds, so the cap and the
///       ledger can never disagree.
function scr_village_housing_cap(_v)
{
    var _cap = 50;

    for (var _i = 0; _i < array_length(_v.building_list); _i++)
    {
        var _b = _v.building_list[_i];
        if (!instance_exists(_b)) continue;

        // Watchtowers, mines, workshops and ports return 0 beds.
        _cap += scr_housing_beds_for(_b.building_type, _b.level);
    }

    return _cap;
}

function scr_village_house_count(_v)
{
    var _count = 0;
    for (var _i = 0; _i < array_length(_v.building_list); _i++)
    {
        var _b = _v.building_list[_i];
        if (!instance_exists(_b)) continue;
        if (_b.building_type == "house_a" || _b.building_type == "house_b")
        {
            _count++;
        }
    }
    return _count;
}

/// @func scr_village_watchtower_count(_v, _complete_only)
/// @desc Counts watchtowers listed for a village. Upgrading towers stay in
///       the list, so _complete_only = true is used for era requirements.
function scr_village_watchtower_count(_v, _complete_only = false)
{
    var _count = 0;
    for (var _i = 0; _i < array_length(_v.building_list); _i++)
    {
        var _b = _v.building_list[_i];
        if (!instance_exists(_b)) continue;
        if (_b.building_type != "watchtower") continue;
        if (_complete_only && _b.state != "complete") continue;
        _count++;
    }
    return _count;
}

/// @func scr_village_mine_count(_v)
/// @desc Counts mines listed for a village (completed sites are added to the
///       building list, pending ones are not).
function scr_village_mine_count(_v)
{
    var _count = 0;
    for (var _i = 0; _i < array_length(_v.building_list); _i++)
    {
        var _b = _v.building_list[_i];
        if (!instance_exists(_b)) continue;
        if (_b.building_type == "mine") _count++;
    }
    return _count;
}

/// @func scr_village_workshop_count(_v)
/// @desc Counts workshops listed for a village (completed sites are added to
///       the building list, pending ones are not).
function scr_village_workshop_count(_v)
{
    var _count = 0;
    for (var _i = 0; _i < array_length(_v.building_list); _i++)
    {
        var _b = _v.building_list[_i];
        if (!instance_exists(_b)) continue;
        if (_b.building_type == "workshop") _count++;
    }
    return _count;
}

/// @func scr_village_barracks_count(_v)
/// @desc Counts barracks listed for a village (completed sites are added to
///       the building list, pending ones are not).
function scr_village_barracks_count(_v)
{
    if (_v == undefined || !variable_struct_exists(_v, "building_list")) return 0;

    var _count = 0;
    for (var _i = 0; _i < array_length(_v.building_list); _i++)
    {
        var _b = _v.building_list[_i];
        if (!instance_exists(_b)) continue;
        if (_b.building_type == "barracks") _count++;
    }
    return _count;
}
/// @desc Counts boat ports listed for a village (completed sites are added to
///       the building list, pending ones are not).
function scr_village_port_count(_v)
{
    // Villages always initialise building_list (scr_create_village); the
    // guard just keeps a malformed/half-built village from crashing here.
    if (_v == undefined || !variable_struct_exists(_v, "building_list")) return 0;

    var _count = 0;
    for (var _i = 0; _i < array_length(_v.building_list); _i++)
    {
        var _b = _v.building_list[_i];
        if (!instance_exists(_b)) continue;
        if (_b.building_type == "boat_port") _count++;
    }
    return _count;
}