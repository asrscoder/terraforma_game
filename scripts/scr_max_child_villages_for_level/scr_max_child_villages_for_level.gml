// DEPRECATED — kept only so nothing breaks if an older call site survives.
// All cap values now live in scr_era_rules.gml.

/// @func scr_max_child_villages_for_level(_level)
/// @desc Alias for scr_era_max_child_villages.
function scr_max_child_villages_for_level(_level)
{
    return scr_era_max_child_villages(_level);
}
