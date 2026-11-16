/// @func scr_weapon_stats(_weapon_id)
/// @desc Returns a struct { damage, range, cooldown, is_ranged } for a weapon.
///       Era-gated weapons for soldiers. Unknown ids fall back to a weak club.
function scr_weapon_stats(_weapon_id)
{
    switch (_weapon_id)
    {
        case "club":     return { damage: 10, range: 1, cooldown: 30, is_ranged: false };
        case "sling":    return { damage: 6,  range: 4, cooldown: 45, is_ranged: true  };
        case "sword":    return { damage: 18, range: 1, cooldown: 25, is_ranged: false };
        case "bow":      return { damage: 12, range: 6, cooldown: 40, is_ranged: true  };
        case "spear":    return { damage: 22, range: 2, cooldown: 30, is_ranged: false };
        case "crossbow": return { damage: 18, range: 7, cooldown: 50, is_ranged: true  };
    }
    return { damage: 5, range: 1, cooldown: 30, is_ranged: false };
}