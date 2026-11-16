/// @func scr_building_cost(_building_type, _level)
/// @desc Resource cost to build or upgrade _building_type to era _level.
///       Era 3+ currently reuses the era-2 table (no era-3 costs defined yet).
function scr_building_cost(_building_type, _level)
{
    if (_level >= 2)
    {
        switch (_building_type)
        {
            case "town_hall":  return { wood: 500, stone: 300, iron: 100 };
            case "watchtower": return { wood: 150, stone:  80, iron:  50 };
            case "house_a":    return { wood: 100, stone:  40, iron:  20 };
            case "house_b":    return { wood: 180, stone:  90, iron:  40 };
            case "mine":       return { wood: 150, stone: 200, iron:  100 };
            case "workshop":   return { wood: 150, stone: 100, iron:   20 };
            case "boat_port":  return { wood: 350, stone: 200, iron:   50 };
            case "barracks":   return { wood: 200, stone: 300, iron:  100 };
        }
    }
    else
    {
        switch (_building_type)
        {
            case "town_hall":  return { wood: 200, stone: 100, iron: 0 };
            case "watchtower": return { wood:  50, stone:  50, iron: 0 };
            case "house_a":    return { wood:  50, stone:  20, iron: 0 };
            case "house_b":    return { wood:  80, stone:  50, iron: 0 };
            case "workshop":   return { wood: 100, stone:  50, iron: 0 };
            case "boat_port":  return { wood: 150, stone:  80, iron: 0 };
            case "barracks":   return { wood: 100, stone: 150, iron: 0 };
        }
    }

    return { wood: 0, stone: 0, iron: 0 };
}

/// @func scr_try_complete_buildings()
/// @desc Completes any pending construction when the village has 5+ available
///       builders and the resources are available. Builders do NOT have to be
///       standing at the site; the crew count alone is the gate.
function scr_try_complete_buildings()
{
    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        var _v = global.villages[_i];

        // Check for pending construction site owned by this village
        with (obj_building)
        {
            if (state != "construction")     continue;
            if (village_id != _v.id)         continue;

            var _site = id;

            // Cost depends on the era this site is being built/upgraded to.
            var _cost = scr_building_cost(building_type, level);

            if (_v.resources.wood  < _cost.wood)  continue;
            if (_v.resources.stone < _cost.stone) continue;
            if (_v.resources.iron  < _cost.iron)  continue;

            // Count the village's available builders (5 required per site).
            // Resting builders in the workshop do NOT count: they are woken by
            // the housing tick and have to actually come back out to work.
            var _builders_free = 0;

            for (var _ci = 0; _ci < array_length(_v.member_ids); _ci++)
            {
                var _u = _v.member_ids[_ci];
                if (!instance_exists(_u)) continue;
                if (_u.unit_type != "builder") continue;
                if (_u.housed) continue;

                _builders_free++;
                if (_builders_free >= 5) break;
            }

            if (_builders_free < 5) continue;

            _v.resources.wood  -= _cost.wood;
            _v.resources.stone -= _cost.stone;
            _v.resources.iron  -= _cost.iron;

            // A freshly completed mine (or any completion that spent resources
            // and pushed a stock below its mining rest threshold) changes the
            // mining picture: clear the miners' retry timers so they re-evaluate
            // immediately instead of waiting up to 15 scans.
            if (building_type == "mine" || scr_village_needs_mining(_v))
            {
                for (var _mi = 0; _mi < array_length(_v.member_ids); _mi++)
                {
                    var _mu = _v.member_ids[_mi];
                    if (instance_exists(_mu) && _mu.unit_type == "miner")
                        _mu.mine_dry_scans = 0;
                }
            }

            // Complete
            var _body = scr_get_building_sprite(building_type, level, false);
            sprite_index = _body;
            state        = "complete";

            // Clear builder targets for everyone working this site
            for (var _bi = 0; _bi < array_length(_v.member_ids); _bi++)
            {
                var _b = _v.member_ids[_bi];
                if (!instance_exists(_b)) continue;
                if (_b.build_target_id == _site) _b.build_target_id = noone;
            }

            // Remove from pending
            if (_v.construction_id == _site) _v.construction_id = noone;

            // Town hall upgrades/new halls raise this village's storage caps.
            if (building_type == "town_hall")
            {
                _v.resource_caps = scr_resource_caps_for_level(level);
            }

            // Add to village building list (upgrades are already listed)
            var _listed = false;
            for (var _li = 0; _li < array_length(_v.building_list); _li++)
            {
                if (_v.building_list[_li] == _site) { _listed = true; break; }
            }
            if (!_listed) array_push(_v.building_list, _site);

            global.villages[_i] = _v;

        }
    }
}

/// @func scr_start_building_upgrade(_building, _to_level)
/// @desc Turns a completed building into an upgrade construction site.
///       scr_try_complete_buildings() finishes it and the Draw event then
///       renders the new era's sprite from _building.level.
function scr_start_building_upgrade(_building, _to_level)
{
    if (!instance_exists(_building)) return;

    _building.level       = _to_level;
    _building.state       = "construction";
    _building.image_index = 0;

    _building.sprite_index = scr_construction_sprite(_building.building_type);

    show_debug_message(
        "UPGRADE STARTED: " + _building.building_type
        + " in village " + string(_building.village_id)
        + " -> era " + string(_to_level)
    );
}

/// @func scr_try_upgrade_buildings()
/// @desc Starts era upgrades one building at a time per village:
///       1. the town hall must reach the kingdom's era first,
///       2. only then may watchtowers, boat ports and houses upgrade.
///       Upgrades reuse the normal construction flow (5 builders + cost).
function scr_try_upgrade_buildings()
{
    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        var _v = global.villages[_i];
        var _kingdom = global.kingdoms[_v.kingdom_id];
        var _target_level = _kingdom.advancement_level;

        // One construction job at a time per village.
        var _busy = false;
        with (obj_building)
        {
            if (village_id == _v.id && state == "construction")
            {
                _busy = true;
            }
        }
        if (_busy) continue;

        // Locate the completed town hall.
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

        // 1) Town hall upgrades first.
        if (_town_hall != noone && _town_hall.level < _target_level)
        {
            scr_start_building_upgrade(_town_hall, _target_level);
            continue;
        }

        // 2) No town hall yet: nothing else may upgrade.
        if (_town_hall == noone) continue;

        // 3) Watchtowers, one per scan (small quota, keeps defences current).
        var _tower_started = false;
        for (var _ti = 0; _ti < array_length(_v.building_list); _ti++)
        {
            var _tower = _v.building_list[_ti];
            if (!instance_exists(_tower)) continue;
            if (_tower.state != "complete") continue;
            if (_tower.building_type != "watchtower") continue;
            if (_tower.level >= _target_level) continue;

            scr_start_building_upgrade(_tower, _target_level);
            _tower_started = true;
            break;
        }
        if (_tower_started) continue;

        // 4) Boat ports, one per scan.
        var _port_started = false;
        for (var _pi = 0; _pi < array_length(_v.building_list); _pi++)
        {
            var _port = _v.building_list[_pi];
            if (!instance_exists(_port)) continue;
            if (_port.state != "complete") continue;
            if (_port.building_type != "boat_port") continue;
            if (_port.level >= _target_level) continue;

            scr_start_building_upgrade(_port, _target_level);
            _port_started = true;
            break;
        }
        if (_port_started) continue;

        // 5) Workshops, one per scan (era-1 hall upgrades to the stone build).
        var _workshop_started = false;
        for (var _wi = 0; _wi < array_length(_v.building_list); _wi++)
        {
            var _workshop = _v.building_list[_wi];
            if (!instance_exists(_workshop)) continue;
            if (_workshop.state != "complete") continue;
            if (_workshop.building_type != "workshop") continue;
            if (_workshop.level >= _target_level) continue;

            scr_start_building_upgrade(_workshop, _target_level);
            _workshop_started = true;
            break;
        }
        if (_workshop_started) continue;

        // 6) Barracks, one per scan (era-1 hall upgrades to the stone build).
        var _barracks_started = false;
        for (var _bri = 0; _bri < array_length(_v.building_list); _bri++)
        {
            var _barracks = _v.building_list[_bri];
            if (!instance_exists(_barracks)) continue;
            if (_barracks.state != "complete") continue;
            if (_barracks.building_type != "barracks") continue;
            if (_barracks.level >= _target_level) continue;

            scr_start_building_upgrade(_barracks, _target_level);
            _barracks_started = true;
            break;
        }
        if (_barracks_started) continue;

        // 7) Houses, one per scan.
        for (var _hi = 0; _hi < array_length(_v.building_list); _hi++)
        {
            var _house = _v.building_list[_hi];
            if (!instance_exists(_house)) continue;
            if (_house.state != "complete") continue;
            if (_house.building_type != "house_a" && _house.building_type != "house_b") continue;
            if (_house.level >= _target_level) continue;

            scr_start_building_upgrade(_house, _target_level);
            break;
        }
    }
}