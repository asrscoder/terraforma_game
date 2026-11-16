/// @func scr_get_building_sprite(_type, _era, _is_roof)
/// @desc Returns the sprite for a building type at a given era.
///       _is_roof = false → body sprite
///       _is_roof = true  → tint mask sprite (drawn with the kingdom colour)
///       Era 1 generally has no roof mask (natural thatch).
///       The watchtower is the exception: its pennant is tinted in both eras.
///       Falls back to era 1 if the era-specific sprite doesn't exist.
function scr_get_building_sprite(_type, _era, _is_roof = false)
{
    switch (_type)
    {
        case "town_hall":
            switch (_era)
            {
                case 2:
                    return _is_roof
                        ? spr_building_town_hall_era2_roof
                        : spr_building_town_hall_era2;
                default:
                    // Era 1 — no roof mask
                    return _is_roof ? -1 : spr_building_town_hall_era1;
            }
            break;

        case "house_a":
            switch (_era)
            {
                case 2:
                    return _is_roof
                        ? spr_building_house_era2_a_roof
                        : spr_building_house_era2_a;
                default:
                    return _is_roof ? -1 : spr_building_house_era1_a;
            }
            break;

        case "house_b":
            switch (_era)
            {
                case 2:
                    return _is_roof
                        ? spr_building_house_era2_b_roof
                        : spr_building_house_era2_b;
                default:
                    return _is_roof ? -1 : spr_building_house_era1_b;
            }
            break;

        case "watchtower":
            switch (_era)
            {
                case 2:
                    // Mask tints the pennant + slate roof
                    return _is_roof
                        ? spr_building_watchtower_era2_roof
                        : spr_building_watchtower_era2;
                default:
                    // Era 1: mask tints only the pennant
                    return _is_roof
                        ? spr_building_watchtower_era1_roof
                        : spr_building_watchtower_era1;
            }
            break;

        case "mine":
            // Mines only exist from era 2 onward; era 3+ reuse the era-2 art.
            if (_era < 2) return -1;
            return _is_roof ? -1 : spr_building_mine_era2;
            break;

        case "workshop":
            // Workshops exist in every era and have their own art; era 3+
            // reuse the era-2 building. No roof mask: the thatch (era 1) and
            // the slate roof (era 2) are already kingdom-neutral.
            if (_is_roof) return -1;
            return (_era >= 2) ? spr_building_workshop_era2 : spr_building_workshop_era1;
            break;

        case "barracks":
            // Barracks exist in every era; era 3+ reuse the era-2 building.
            // No roof mask: art is kingdom-neutral.
            if (_is_roof) return -1;
            return (_era >= 2) ? spr_building_barracks_era2 : spr_building_barracks_era1;
            break;

        case "boat_port":
            // Ports exist in every era; era 3+ reuse the era-2 art.
            // Only the shoreline house is returned here — the pier is drawn
            // separately so it can point at the water in any direction
            // (see scr_get_port_pier_sprite).
            if (_is_roof) return -1;
            return (_era >= 2) ? spr_building_boat_port_house_era2 : spr_building_boat_port_house_era1;
            break;

        default:
            return -1;
    }
}

/// @func scr_get_port_pier_sprite(_era)
/// @desc Pier/deck sprite for a boat port, drawn separately from the upright
///       house. Era 3+ reuse the era-2 art. The sprite is authored horizontal
///       (for an ocean to the south) and rotated by scr_port_dir_angle().
function scr_get_port_pier_sprite(_era)
{
    return (_era >= 2) ? spr_building_boat_port_pier_era2 : spr_building_boat_port_pier_era1;
}

/// @func scr_construction_sprite(_type)
/// @desc Construction-site sprite for a building type. One neutral site is
///       used across all eras. Sizes: town hall 24, watchtower 8x16, else 16.
function scr_construction_sprite(_type)
{
    switch (_type)
    {
        case "town_hall":  return spr_building_construction_24;
        case "barracks":   return spr_building_construction_24;
        case "watchtower": return spr_building_construction_8x16;
        case "mine":       return spr_building_construction_8;
        case "workshop":   return spr_building_construction_16;
        case "boat_port":  return spr_building_construction_16;
        default:           return spr_building_construction_16;
    }
}