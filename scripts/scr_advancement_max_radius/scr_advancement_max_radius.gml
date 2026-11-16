/// @func scr_advancement_max_radius(_level)
/// @desc Max claim radius (in tiles) from the village center for a kingdom
///       at the given advancement level.
function scr_advancement_max_radius(_level)
{
    switch (_level)
    {
        case 1: return 20;
        case 2: return 35;
        case 3: return 50;
        case 4: return 100;
    }
    return 20;
}

/// @func scr_check_kingdom_level_up()
/// @desc Advances each kingdom by one era when its requirements are met.
///       All caps and requirements live in scr_era_rules.gml; this function
///       only evaluates them. Requirements are checked against the capital,
///       except the child-village count which is kingdom-wide. The boat port
///       is only demanded when the capital actually has a shoreline it can
///       build on, so landlocked capitals can always advance.
function scr_check_kingdom_level_up()
{
    for (var _k = 0; _k < array_length(global.kingdoms); _k++)
    {
        var _kingdom = global.kingdoms[_k];
        var _level   = _kingdom.advancement_level;

        // Only eras with a defined rule set may advance.
        if (!scr_era_can_advance(_level)) continue;

        // Requirements are measured on the capital.
        var _capital = noone;
        if (_kingdom.capital_village_id >= 0
         && _kingdom.capital_village_id < array_length(global.villages))
        {
            _capital = global.villages[_kingdom.capital_village_id];
        }
        if (_capital == noone) continue;

        // Children exclude the capital itself.
        var _children = array_length(_kingdom.village_ids) - 1;
        if (_children < 0) _children = 0;

        // --- Required buildings (tune in scr_era_rules.gml) ---
        if (_children < scr_era_required_child_villages(_level))                                 continue;
        if (scr_village_house_count(_capital)            < scr_era_required_houses(_level))       continue;
        if (scr_village_watchtower_count(_capital, true) < scr_era_required_watchtowers(_level))  continue;
        if (scr_village_mine_count(_capital)             < scr_era_required_mines(_level))        continue;
        if (scr_village_workshop_count(_capital)         < scr_era_required_workshops(_level))    continue;
        if (scr_village_barracks_count(_capital)         < scr_era_required_barracks(_level))     continue;
        if (scr_village_farm_count(_capital)             < scr_era_required_farms(_level))         continue;

        // Ports only gate kingdoms that could actually build one.
        var _ports_required = scr_era_required_ports(_level);
        if (_ports_required > 0 && scr_village_can_host_port(_capital))
        {
            if (scr_village_port_count(_capital) < _ports_required) continue;
        }

        _kingdom.advancement_level = _level + 1;
        global.kingdoms[_k] = _kingdom;

        show_debug_message(
            "Kingdom " + string(_k) + " advanced to level " + string(_level + 1)
            + " (" + string(_children) + " child village(s))"
        );
    }
}

/// @func scr_kingdom_can_mine_iron(_kingdom_id)
/// @desc Iron is an era-2+ resource. Era-1 kingdoms cannot mine it at all.
function scr_kingdom_can_mine_iron(_kingdom_id)
{
    if (_kingdom_id < 0 || _kingdom_id >= array_length(global.kingdoms)) return false;
    return (global.kingdoms[_kingdom_id].advancement_level >= 2);
}

/// @func scr_resource_caps_for_level(_level)
/// @desc Wood/stone/iron storage capacity for a village whose town hall is
///       at the given era. Levels 3+ are not defined yet, so they keep the
///       level-2 caps instead of dropping back down.
function scr_resource_caps_for_level(_level)
{
    if (_level >= 2) return { wood: 1000, stone: 1000, iron: 600 };
    return { wood: 500, stone: 500, iron: 300 };
}