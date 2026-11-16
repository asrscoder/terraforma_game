/// @func scr_try_place_houses(_only_village)
/// @desc For each village, if the pop is at 80% of housing cap and no
///       construction (new build or upgrade) is in progress, place a new
///       house site. New houses also wait until the town hall has reached
///       the kingdom's era. _only_village restricts the scan to one village.
///       Returns true if a site was placed.
function scr_try_place_houses(_only_village = -1)
{
    var _placed = false;

    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        if (_only_village != -1 && _i != _only_village) continue;

        var _v = global.villages[_i];

        // Town hall must be complete first
        var _town_hall = noone;
        for (var _bi = 0; _bi < array_length(_v.building_list); _bi++)
        {
            var _b = _v.building_list[_bi];
            if (!instance_exists(_b)) continue;
            if (_b.building_type != "town_hall") continue;
            if (_b.state != "complete") continue;
            _town_hall = _b;
            break;
        }
        if (_town_hall == noone) continue;

        // House count cap
        var _kingdom = global.kingdoms[_v.kingdom_id];
        var _max_houses = scr_era_max_houses(_kingdom.advancement_level);
        var _current_houses = scr_village_house_count(_v);
        if (_current_houses >= _max_houses) continue;

        // Don't crowd the village while the town hall awaits its era upgrade.
        if (_town_hall.level < _kingdom.advancement_level) continue;

        // Population threshold (80% of housing cap)
        var _pop = array_length(_v.member_ids);
        var _cap = scr_village_housing_cap(_v);
        if (_pop < _cap * 0.8) continue;

        // One construction job at a time (new houses wait for upgrades).
        var _pending_construction = false;
        with (obj_building)
        {
            if (village_id != _v.id) continue;
            if (state != "construction") continue;
            _pending_construction = true;
        }
        if (_pending_construction) continue;

        // Find a spot
        var _spot = scr_find_house_spot(_i);
        if (_spot[0] == -1) continue;

        var _w = obj_world.world_width;
        var _h = obj_world.world_height;
        if (_spot[0] < 0 || _spot[0] + 1 >= _w) continue;
        if (_spot[1] < 0 || _spot[1] + 1 >= _h) continue;
        if (obj_world.terrain_grid[_spot[0] + _spot[1] * _w] == TERRAIN.WATER) continue;
        if (obj_world.terrain_grid[(_spot[0] + 1) + _spot[1] * _w] == TERRAIN.WATER) continue;
        if (obj_world.terrain_grid[_spot[0] + (_spot[1] + 1) * _w] == TERRAIN.WATER) continue;
        if (obj_world.terrain_grid[(_spot[0] + 1) + (_spot[1] + 1) * _w] == TERRAIN.WATER) continue;

        // Place the house site.
        // Sprites use a bottom-centre origin (same as the town hall), so a
        // 2-tile-wide house is centred at (spot_x + 1) * ts, bottom at (spot_y + 2) * ts.
        // If your house sprite origin is bottom-LEFT, change the x back to _spot[0] * _ts.
        var _ts = obj_world.tile_size;
        var _inst = instance_create_depth(
            (_spot[0] + 1) * _ts,
            (_spot[1] + 2) * _ts,
            DEPTH.BUILDINGS,
            obj_building
        );

        _inst.building_type = "house_a";
        _inst.building_size = 16;
        _inst.sprite_index  = scr_construction_sprite(_inst.building_type);
        _inst.state         = "construction";
        _inst.village_id    = _v.id;
        _inst.level         = _kingdom.advancement_level;

        // Footprint (2x2)
        _inst.footprint_left   = _spot[0];
        _inst.footprint_top    = _spot[1];
        _inst.footprint_right  = _spot[0] + 1;
        _inst.footprint_bottom = _spot[1] + 1;

        for (var _dy = 0; _dy <= 1; _dy++)
        {
            for (var _dx = 0; _dx <= 1; _dx++)
            {
                obj_world.block_grid[(_spot[0] + _dx) + (_spot[1] + _dy) * _w] = 1;
            }
        }

        scr_bpad_add(_inst);

        _placed = true;
        _v.construction_id = _inst;
        global.villages[_i] = _v;
    }

    return _placed;
}

/// @func scr_try_place_watchtowers(_only_village)
/// @desc Places a 1x2 watchtower site when a village has a completed town
///       hall, no construction in progress, and fewer towers than its era
///       quota. _only_village restricts the scan to one village.
///       Returns true if a site was placed.
function scr_try_place_watchtowers(_only_village = -1)
{
    var _placed = false;

    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        if (_only_village != -1 && _i != _only_village) continue;

        var _v = global.villages[_i];

        // Town hall must be complete first
        var _town_hall = noone;
        for (var _bi = 0; _bi < array_length(_v.building_list); _bi++)
        {
            var _b = _v.building_list[_bi];
            if (!instance_exists(_b)) continue;
            if (_b.building_type != "town_hall") continue;
            if (_b.state != "complete") continue;
            _town_hall = _b;
            break;
        }
        if (_town_hall == noone) continue;

        var _kingdom = global.kingdoms[_v.kingdom_id];

        // Wait until the town hall matches the kingdom era (same as houses)
        if (_town_hall.level < _kingdom.advancement_level) continue;

        // Watchtower quota for this era
        var _max_towers = scr_era_max_watchtowers(_kingdom.advancement_level);
        if (scr_village_watchtower_count(_v) >= _max_towers) continue;

        // One construction job at a time
        var _pending_construction = false;
        with (obj_building)
        {
            if (village_id != _v.id) continue;
            if (state != "construction") continue;
            _pending_construction = true;
        }
        if (_pending_construction) continue;

        // Find a spot
        var _spot = scr_find_watchtower_spot(_i);
        if (_spot[0] == -1) continue;

        // 8x16 sprite, bottom-centre origin: 1 tile wide, 2 tiles tall,
        // bottom edge on the lower tile of the footprint.
        var _ts = obj_world.tile_size;
        var _w  = obj_world.world_width;
        var _inst = instance_create_depth(
            _spot[0] * _ts + _ts * 0.5,
            (_spot[1] + 2) * _ts,
            DEPTH.BUILDINGS,
            obj_building
        );

        _inst.building_type = "watchtower";
        _inst.building_size = 8;
        _inst.sprite_index  = scr_construction_sprite(_inst.building_type);
        _inst.state         = "construction";
        _inst.village_id    = _v.id;
        _inst.level         = _kingdom.advancement_level;

        // Footprint (1x2, top tile is _spot)
        _inst.footprint_left   = _spot[0];
        _inst.footprint_top    = _spot[1];
        _inst.footprint_right  = _spot[0];
        _inst.footprint_bottom = _spot[1] + 1;

        for (var _dy = 0; _dy <= 1; _dy++)
        {
            obj_world.block_grid[_spot[0] + (_spot[1] + _dy) * _w] = 1;
        }

        scr_bpad_add(_inst);

        _placed = true;
        _v.construction_id = _inst;
        global.villages[_i] = _v;
    }

    return _placed;
}

/// @func scr_try_place_mine(_only_village)
/// @desc Places a 1x1 mine site for an era-2+ village that does not have one
///       yet. Mines are never generated for era-1 kingdoms. The site still
///       goes through the normal construction flow (5 builders + resources).
///       Returns true if a site was placed.
function scr_try_place_mine(_only_village = -1)
{
    var _placed = false;

    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        if (_only_village != -1 && _i != _only_village) continue;

        var _v = global.villages[_i];
        var _kingdom = global.kingdoms[_v.kingdom_id];

        // Era 2+ only — never generate a mine for an era-1 kingdom.
        if (_kingdom.advancement_level < 2) continue;

        // Era-based mine cap (0 at era 1, so the era check above already
        // covers it; tune the numbers in scr_era_rules.gml).
        if (scr_village_mine_count(_v) >= scr_era_max_mines(_kingdom.advancement_level)) continue;

        // Town hall must be complete and already at the kingdom's era.
        var _town_hall = noone;
        for (var _bi = 0; _bi < array_length(_v.building_list); _bi++)
        {
            var _b = _v.building_list[_bi];
            if (!instance_exists(_b)) continue;
            if (_b.building_type != "town_hall") continue;
            if (_b.state != "complete") continue;
            _town_hall = _b;
            break;
        }
        if (_town_hall == noone) continue;
        if (_town_hall.level < _kingdom.advancement_level) continue;

        // One construction job at a time.
        var _pending_construction = false;
        with (obj_building)
        {
            if (village_id != _v.id) continue;
            if (state != "construction") continue;
            _pending_construction = true;
        }
        if (_pending_construction) continue;

        var _spot = scr_find_mine_spot(_i);
        if (_spot[0] == -1) continue;

        // 8x8 sprite, bottom-centre origin: 1 tile wide and tall.
        var _ts = obj_world.tile_size;
        var _w  = obj_world.world_width;
        var _inst = instance_create_depth(
            _spot[0] * _ts + _ts * 0.5,
            (_spot[1] + 1) * _ts,
            DEPTH.BUILDINGS,
            obj_building
        );

        _inst.building_type = "mine";
        _inst.building_size = 8;
        _inst.sprite_index  = scr_construction_sprite(_inst.building_type);
        _inst.state         = "construction";
        _inst.village_id    = _v.id;
        _inst.level         = _kingdom.advancement_level;

        // Footprint (1x1)
        _inst.footprint_left   = _spot[0];
        _inst.footprint_top    = _spot[1];
        _inst.footprint_right  = _spot[0];
        _inst.footprint_bottom = _spot[1];

        obj_world.block_grid[_spot[0] + _spot[1] * _w] = 1;

        scr_bpad_add(_inst);

        _placed = true;
        _v.construction_id = _inst;
        global.villages[_i] = _v;
    }

    return _placed;
}

/// @func scr_try_place_workshop(_only_village, _required_only)
/// @desc Places a 2x2 workshop site for a village that is below its era cap.
///       Workshops exist in every era (era 1 is the thatched shared
///       miners'/builders' hall, era 2+ the stone-and-timber one) and the site
///       still goes through the normal construction flow (5 builders +
///       resources). With _required_only = true it stops once the village owns
///       enough for the era-advancement requirement, which is how the first
///       workshop outranks houses without letting workshops take over.
///       Returns true if a site was placed.
function scr_try_place_workshop(_only_village = -1, _required_only = false)
{
    var _placed = false;

    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        if (_only_village != -1 && _i != _only_village) continue;

        var _v       = global.villages[_i];
        var _kingdom = global.kingdoms[_v.kingdom_id];

        // Era-based workshop cap (tune in scr_era_rules.gml).
        if (scr_village_workshop_count(_v) >= scr_era_max_workshops(_kingdom.advancement_level)) continue;

        // The gate quota only needs the first workshop.
        if (_required_only)
        {
            if (scr_village_workshop_count(_v) >= scr_era_required_workshops(_kingdom.advancement_level)) continue;
        }

        // Town hall must be complete and already at the kingdom's era.
        var _town_hall = noone;
        for (var _bi = 0; _bi < array_length(_v.building_list); _bi++)
        {
            var _b = _v.building_list[_bi];
            if (!instance_exists(_b)) continue;
            if (_b.building_type != "town_hall") continue;
            if (_b.state != "complete") continue;
            _town_hall = _b;
            break;
        }
        if (_town_hall == noone) continue;
        if (_town_hall.level < _kingdom.advancement_level) continue;

        // One construction job at a time.
        var _pending_construction = false;
        with (obj_building)
        {
            if (village_id != _v.id) continue;
            if (state != "construction") continue;
            _pending_construction = true;
        }
        if (_pending_construction) continue;

        var _spot = scr_find_workshop_spot(_i);
        if (_spot[0] == -1) continue;

        // 16x16 sprite, bottom-centre origin: 2 tiles wide, 2 tiles tall.
        var _ts = obj_world.tile_size;
        var _w  = obj_world.world_width;
        var _inst = instance_create_depth(
            (_spot[0] + 1) * _ts,
            (_spot[1] + 2) * _ts,
            DEPTH.BUILDINGS,
            obj_building
        );

        _inst.building_type = "workshop";
        _inst.building_size = 16;
        _inst.sprite_index  = scr_construction_sprite(_inst.building_type);
        _inst.state         = "construction";
        _inst.village_id    = _v.id;
        _inst.level         = _kingdom.advancement_level;

        // Footprint (2x2)
        _inst.footprint_left   = _spot[0];
        _inst.footprint_top    = _spot[1];
        _inst.footprint_right  = _spot[0] + 1;
        _inst.footprint_bottom = _spot[1] + 1;

        for (var _dy = 0; _dy <= 1; _dy++)
        {
            for (var _dx = 0; _dx <= 1; _dx++)
            {
                obj_world.block_grid[(_spot[0] + _dx) + (_spot[1] + _dy) * _w] = 1;
            }
        }

        scr_bpad_add(_inst);

        _placed = true;
        _v.construction_id = _inst;
        global.villages[_i] = _v;
    }

    return _placed;
}

/// @func scr_try_place_port(_only_village)
/// @desc Places a boat port on any shoreline (2 in-territory land tiles next
///       to 2 open ocean tiles, in any of the four directions). Requires a
///       completed town hall at the kingdom's era, no other construction in
///       progress, and room under the era's port cap.
///       Returns true if a site was placed.
function scr_try_place_port(_only_village = -1)
{
    var _placed = false;

    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        if (_only_village != -1 && _i != _only_village) continue;

        var _v = global.villages[_i];

        // Town hall must be complete first.
        var _town_hall = noone;
        for (var _bi = 0; _bi < array_length(_v.building_list); _bi++)
        {
            var _b = _v.building_list[_bi];
            if (!instance_exists(_b)) continue;
            if (_b.building_type != "town_hall") continue;
            if (_b.state != "complete") continue;
            _town_hall = _b;
            break;
        }
        if (_town_hall == noone) continue;

        var _kingdom = global.kingdoms[_v.kingdom_id];

        // Wait until the town hall matches the kingdom era.
        if (_town_hall.level < _kingdom.advancement_level) continue;

        // Era-based port cap (tune in scr_era_rules.gml).
        if (scr_village_port_count(_v) >= scr_era_max_ports(_kingdom.advancement_level)) continue;

        // One construction job at a time.
        var _pending_construction = false;
        with (obj_building)
        {
            if (village_id != _v.id) continue;
            if (state != "construction") continue;
            _pending_construction = true;
        }
        if (_pending_construction) continue;

        // Don't rescan every frame while waiting for a shoreline. A village
        // that cannot host a port would otherwise run the full 4-way scan
        // forever; a short cooldown keeps placement responsive without the
        // per-frame cost.
        if (variable_struct_exists(_v, "port_search_wait") && _v.port_search_wait > 0)
        {
            _v.port_search_wait--;
            global.villages[_i] = _v;
            continue;
        }

        var _spot = scr_find_port_spot(_i);
        if (_spot[0] == -1)
        {
            // Surfaced once per village so a village that can never find a
            // shoreline is visible in the Output window instead of failing
            // silently.
            if (!variable_struct_exists(_v, "port_spot_warned") || !_v.port_spot_warned)
            {
                _v.port_spot_warned = true;
                show_debug_message(
                    "PORT: village " + string(_i) + " found no shoreline spot "
                    + "(needs 2 in-territory land tiles beside 2 open ocean tiles)."
                );
            }

            _v.port_search_wait = 30; // ~0.5s at 60 fps
            global.villages[_i]  = _v;
            continue;
        }

        var _dir = _spot[2];

        // 16x16 sprite, bottom-centre origin: 2 tiles wide, 2 tiles tall.
        var _ts = obj_world.tile_size;
        var _w  = obj_world.world_width;
        var _inst = instance_create_depth(
            (_spot[0] + 1) * _ts,
            (_spot[1] + 2) * _ts,
            DEPTH.BUILDINGS,
            obj_building
        );

        _inst.building_type = "boat_port";
        _inst.building_size = 16;
        _inst.sprite_index  = scr_construction_sprite(_inst.building_type);
        _inst.state         = "construction";
        _inst.village_id    = _v.id;
        _inst.level         = _kingdom.advancement_level;
        _inst.port_dir      = _dir;

        // Footprint (2x2; one half sits on water)
        _inst.footprint_left   = _spot[0];
        _inst.footprint_top    = _spot[1];
        _inst.footprint_right  = _spot[0] + 1;
        _inst.footprint_bottom = _spot[1] + 1;

        for (var _dy = 0; _dy <= 1; _dy++)
        {
            for (var _dx = 0; _dx <= 1; _dx++)
            {
                obj_world.block_grid[(_spot[0] + _dx) + (_spot[1] + _dy) * _w] = 1;
            }
        }

        scr_bpad_add(_inst);

        // The ocean half was not necessarily owned yet: claim it so the whole
        // 2x2 footprint sits inside the village.
        var _water = scr_port_water_tiles(_spot[0], _spot[1], _dir);
        for (var _wt = 0; _wt < array_length(_water); _wt++)
        {
            var _px   = _water[_wt][0];
            var _py   = _water[_wt][1];
            var _pidx = _px + _py * _w;

            if (obj_world.territory_grid[_pidx] == -1)
                obj_world.territory_grid[_pidx] = _v.id;
        }

        // Extend the cached bounds to cover the whole footprint.
        if (_spot[0]     < _v.left)   _v.left   = _spot[0];
        if (_spot[0] + 1 > _v.right)  _v.right  = _spot[0] + 1;
        if (_spot[1]     < _v.top)    _v.top    = _spot[1];
        if (_spot[1] + 1 > _v.bottom) _v.bottom = _spot[1] + 1;

        _v.territory_dirty = true;

        _placed = true;
        _v.construction_id = _inst;
        global.villages[_i] = _v;
    }

    return _placed;
}

/// @func scr_try_place_buildings()
/// @desc Picks the next new building for each village: the single boat port
///       first, then the single era-2 mine, then the workshop the era gate
///       demands, then a 70/30 roll (houses / watchtowers) that falls back to
///       the other type and finally to spare workshops when the preferred one
///       cannot be placed. Upgrades are handled separately and keep priority
///       over new sites.
/// @func scr_try_place_barracks(_only_village, _required_only)
/// @desc Places a 3x3 barracks site. Mirrors scr_try_place_workshop.
function scr_try_place_barracks(_only_village = -1, _required_only = false)
{
    var _placed = false;

    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        if (_only_village != -1 && _i != _only_village) continue;

        var _v       = global.villages[_i];
        var _kingdom = global.kingdoms[_v.kingdom_id];

        if (scr_village_barracks_count(_v) >= scr_era_max_barracks(_kingdom.advancement_level)) continue;

        if (_required_only)
        {
            if (scr_village_barracks_count(_v) >= scr_era_required_barracks(_kingdom.advancement_level)) continue;
        }

        var _town_hall = noone;
        for (var _bi = 0; _bi < array_length(_v.building_list); _bi++)
        {
            var _b = _v.building_list[_bi];
            if (!instance_exists(_b)) continue;
            if (_b.building_type != "town_hall") continue;
            if (_b.state != "complete") continue;
            _town_hall = _b;
            break;
        }
        if (_town_hall == noone) continue;
        if (_town_hall.level < _kingdom.advancement_level) continue;

        var _pending_construction = false;
        with (obj_building)
        {
            if (village_id != _v.id) continue;
            if (state != "construction") continue;
            _pending_construction = true;
        }
        if (_pending_construction) continue;

        var _spot = scr_find_barracks_spot(_i);
        if (_spot[0] == -1) continue;

        var _ts = obj_world.tile_size;
        var _w  = obj_world.world_width;
        var _inst = instance_create_depth(
            (_spot[0] + 1) * _ts + _ts * 0.5,
            (_spot[1] + 3) * _ts,
            DEPTH.BUILDINGS,
            obj_building
        );

        _inst.building_type = "barracks";
        _inst.building_size = 24;
        _inst.sprite_index  = scr_construction_sprite(_inst.building_type);
        _inst.state         = "construction";
        _inst.village_id    = _v.id;
        _inst.level         = _kingdom.advancement_level;

        _inst.footprint_left   = _spot[0];
        _inst.footprint_top    = _spot[1];
        _inst.footprint_right  = _spot[0] + 2;
        _inst.footprint_bottom = _spot[1] + 2;

        for (var _dy = 0; _dy <= 2; _dy++)
        {
            for (var _dx = 0; _dx <= 2; _dx++)
            {
                obj_world.block_grid[(_spot[0] + _dx) + (_spot[1] + _dy) * _w] = 1;
            }
        }

        scr_bpad_add(_inst);

        _placed = true;
        _v.construction_id = _inst;
        global.villages[_i] = _v;
    }

    return _placed;
}

function scr_try_place_buildings()
{
    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        // Coastal villages place their one boat port first.
        if (scr_try_place_port(_i)) continue;

        // Era-2+ villages get their one mine before other new buildings.
        if (scr_try_place_mine(_i)) continue;

        // The workshop required for era advancement outranks houses/towers.
        if (scr_try_place_workshop(_i, true)) continue;

        // The barracks required for era advancement (soldiers) outranks houses.
        if (scr_try_place_barracks(_i, true)) continue;

        if (random_range(0, 1) <= 0.7)
        {
            if (!scr_try_place_houses(_i))
            {
                if (!scr_try_place_watchtowers(_i))
                    if (!scr_try_place_workshop(_i))
                        scr_try_place_barracks(_i);
            }
        }
        else
        {
            if (!scr_try_place_watchtowers(_i))
            {
                if (!scr_try_place_houses(_i))
                    if (!scr_try_place_workshop(_i))
                        scr_try_place_barracks(_i);
            }
        }
    }
}
