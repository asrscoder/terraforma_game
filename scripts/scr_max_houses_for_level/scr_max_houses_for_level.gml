// DEPRECATED — kept only so nothing breaks if an older call site survives.
// All cap values now live in scr_era_rules.gml.

/// @func scr_max_houses_for_level(_level)
/// @desc Alias for scr_era_max_houses.
function scr_max_houses_for_level(_level)
{
    return scr_era_max_houses(_level);
}

/// @func scr_max_watchtowers_for_level(_level)
/// @desc Alias for scr_era_max_watchtowers.
function scr_max_watchtowers_for_level(_level)
{
    return scr_era_max_watchtowers(_level);
}
