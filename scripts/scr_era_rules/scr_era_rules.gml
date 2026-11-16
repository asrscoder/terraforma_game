/// ============================================================================
/// ERA RULES — single tuning file for building caps and era requirements.
///
/// Every function switches on the kingdom's advancement level, so all the
/// numbers you ever need to balance live here and every system that uses them
/// (placement caps, expansion, era advancement) follows automatically.
///
/// Vocabulary
///   scr_era_max_*        hard cap for a village / kingdom at that era.
///   scr_era_required_*   what the CAPITAL must own before the kingdom may
///                        advance FROM that era, i.e. required_*(1) gates
///                        the era 1 -> 2 step.
///
/// All values below are placeholders — edit freely.
/// ============================================================================


// ----------------------------------------------------------------------------
// CAPS PER ERA
// ----------------------------------------------------------------------------

/// @func scr_era_max_houses(_level)
/// @desc How many houses a village may own at this era.
function scr_era_max_houses(_level)
{
    switch (_level)
    {
        case 1: return 10;
        case 2: return 15;
        case 3: return 25;
        case 4: return 40;
    }
    return 5;
}

/// @func scr_era_max_watchtowers(_level)
/// @desc How many watchtowers a village may own at this era.
function scr_era_max_watchtowers(_level)
{
    switch (_level)
    {
        case 1: return 3;
        case 2: return 5;
        case 3: return 8;
        case 4: return 12;
    }
    return 2;
}

/// @func scr_era_max_ports(_level)
/// @desc How many boat ports a village may own at this era.
function scr_era_max_ports(_level)
{
    switch (_level)
    {
        case 1: return 1;
        case 2: return 2;
        case 3: return 2;
        case 4: return 4;
    }
    return 1;
}

/// @func scr_era_max_mines(_level)
/// @desc How many mines a village may own at this era (mines unlock at era 2).
function scr_era_max_mines(_level)
{
    switch (_level)
    {
        case 1: return 0;
        case 2: return 1;
        case 3: return 2;
        case 4: return 3;
    }
    return 0;
}

/// @func scr_era_max_workshops(_level)
/// @desc How many workshops a village may own at this era. Workshops are the
///       shared miners' + builders' building, so they exist from era 1.
///       Era 3+ reuse the era-2 allowance (same convention as the building
///       cost table) until their own art and numbers are authored.
function scr_era_max_workshops(_level)
{
    switch (_level)
    {
        case 1: return 2;
        case 2: return 3;
        case 3: return 3;
        case 4: return 3;
    }
    return 2;
}

/// @func scr_era_workshop_rest_slots(_level)
/// @desc How many builders/miners ONE workshop can shelter while they have no
///       work at all. This is deliberately separate from the bed table: resting
///       workers are not population housing, so a workshop never raises the
///       village population cap and never takes a villager's bed.
///       Era 3+ reuses the era-2 number, like every other per-era table.
function scr_era_workshop_rest_slots(_level)
{
    switch (_level)
    {
        case 1: return 10;
        case 2: return 12;
        case 3: return 12;
        case 4: return 14;
    }
    return 10;
}

/// @func scr_era_max_child_villages(_level)
/// @desc How many child villages a kingdom may found at this era.
function scr_era_max_child_villages(_level)
{
    switch (_level)
    {
        case 1: return 1;
        case 2: return 2;
        case 3: return 2;
        case 4: return 4;
    }
    return 1;
}


// ----------------------------------------------------------------------------
// REQUIREMENTS TO ADVANCE FROM AN ERA (checked against the capital)
// ----------------------------------------------------------------------------

/// @func scr_era_can_advance(_level)
/// @desc Whether advancement rules exist for leaving this era. Eras without
///       art are disabled on purpose: era 3+ buildings currently fall back to
///       era-1/2 sprites, so unlocking them now would visually downgrade a
///       kingdom. Uncomment a case once that era's art exists.
function scr_era_can_advance(_level)
{
    switch (_level)
    {
        case 1: return true;    // era 1 -> era 2
        // case 2: return true; // era 2 -> era 3
        // case 3: return true; // era 3 -> era 4
    }
    return false;
}

/// @func scr_era_required_houses(_level)
/// @desc Completed houses the capital needs before advancing from this era.
function scr_era_required_houses(_level)
{
    switch (_level)
    {
        case 1: return 8;
        case 2: return 12;
        case 3: return 20;
    }
    return 999999;
}

/// @func scr_era_required_watchtowers(_level)
/// @desc Completed watchtowers the capital needs before advancing from this era.
function scr_era_required_watchtowers(_level)
{
    switch (_level)
    {
        case 1: return 2;
        case 2: return 4;
        case 3: return 7;
    }
    return 999999;
}

/// @func scr_era_required_ports(_level)
/// @desc Completed boat ports the capital needs before advancing from this era.
///       0 means "not required". The caller only enforces this when the
///       capital actually has room to build a port, so landlocked capitals are
///       never locked out of advancing.
function scr_era_required_ports(_level)
{
    switch (_level)
    {
        case 1: return 1;
        case 2: return 1;
        case 3: return 2;
    }
    return 0;
}

/// @func scr_era_required_mines(_level)
/// @desc Completed mines the capital needs before advancing from this era.
function scr_era_required_mines(_level)
{
    switch (_level)
    {
        case 1: return 0;
        case 2: return 1;
        case 3: return 2;
    }
    return 999999;
}

/// @func scr_era_required_workshops(_level)
/// @desc Completed workshops the capital needs before advancing from this era.
///       1 means "must own a workshop" (the era-1 shared miners'/builders'
///       hall), which is also what gates the era 1 -> 2 step.
function scr_era_required_workshops(_level)
{
    switch (_level)
    {
        case 1: return 1;
        case 2: return 1;
        case 3: return 1;
    }
    return 999999;
}

/// @func scr_era_max_barracks(_level)
/// @desc How many barracks a village may own at this era.
function scr_era_max_barracks(_level)
{
    switch (_level)
    {
        case 1: return 3;
        case 2: return 4;
        case 3: return 4;
        case 4: return 4;
    }
    return 3;
}

/// @func scr_era_required_barracks(_level)
/// @desc Completed barracks the capital needs before advancing from this era.
function scr_era_required_barracks(_level)
{
    switch (_level)
    {
        case 1: return 1;
        case 2: return 1;
        case 3: return 1;
    }
    return 999999;
}
/// @desc Child villages the kingdom needs before advancing from this era.
function scr_era_required_child_villages(_level)
{
    switch (_level)
    {
        case 1: return 1;
        case 2: return 2;
        case 3: return 2;
    }
    return 999999;
}
