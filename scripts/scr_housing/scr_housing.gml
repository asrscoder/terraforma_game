/// Housing: units live inside buildings.
///
/// A housed unit keeps its instance, so every member_ids array and every
/// instance_exists() check in the game keeps working untouched. What it loses
/// is cost: obj_unit's Step event exits immediately, its path is dropped and it
/// is not drawn. AI dispatch, pathfinding, movement and the sprite draw are
/// where the per-unit frame time actually goes, so that is the whole win.
///
/// Beds come from the same numbers that decide the village housing cap, so
/// there is a single source of truth (scr_housing_beds_for).
///
/// Note: instance_deactivate_instance() would be cheaper still, but GameMaker's
/// instance_exists() returns false for deactivated instances — and this game
/// uses that call as its "is this villager still alive?" check everywhere. A
/// housed villager would look dead to scr_village_pop_count, role assignment,
/// expansion and migration. Hiding the work instead keeps all of that intact.

/// @func scr_housing_beds_for(_building_type, _level)
/// @desc How many residents a completed building can hold. These are the exact
///       numbers the village housing cap is built from, so tuning one tunes
///       both. Era 3+ reuses the era-2 numbers (same convention as
///       scr_building_cost), so an upgrade never evicts anyone.
function scr_housing_beds_for(_building_type, _level)
{
    if (_level >= 2)
    {
        switch (_building_type)
        {
            case "town_hall": return 50;
            case "house_a":   return 20;
            case "house_b":   return 30;
            case "barracks":  return 30;
        }
    }
    else
    {
        switch (_building_type)
        {
            case "town_hall": return 20;
            case "house_a":   return 10;
            case "house_b":   return 20;
            case "barracks":  return 30;
        }
    }

    return 0;
}

/// @func scr_housing_type_allowed(_type)
/// @desc Which unit types may use the villager bed system (houses, town hall).
///       Builders and miners are deliberately excluded: they shelter in a
///       workshop instead (scr_housing_tick), because freezing them in a bed
///       would stop the resource and construction work.
///       Add "farmer" and/or "soldier" here to hide those too.
function scr_housing_type_allowed(_type)
{
    switch (_type)
    {
        case "villager": return true;
        case "leader":   return true;
    }

    return false;
}

/// @func scr_housing_bed_allowed(_building_type, _unit_type)
/// @desc Which unit types may take a bed in a given building type. Barracks
///       house soldiers only; everything else houses villagers and the leader.
function scr_housing_bed_allowed(_building_type, _unit_type)
{
    if (_building_type == "barracks") return (_unit_type == "soldier");
    return (_unit_type == "villager" || _unit_type == "leader");
}

/// @func scr_housing_is_worker(_type)
/// @desc Builders and miners never use the villager bed system: their Step
///       event is what earns resources and finishes sites, so freezing them
///       indoors would stall the village. They shelter in a workshop only
///       while they have NO job at all (see scr_housing_tick), and the tick
///       wakes them the moment work exists again.
function scr_housing_is_worker(_type)
{
    return (_type == "builder" || _type == "miner");
}

/// @func scr_village_has_open_site(_v)
/// @desc True if the village owns any construction site (new build or upgrade).
///       Builders must be awake whenever this is true.
///
///       Scans obj_building rather than _v.building_list: a NEW site is only
///       pushed onto building_list when it finishes, so a list scan would miss
///       exactly the site the builders are supposed to build. That is a
///       deadlock: builders read "no work" and go indoors, and the completion
///       gate (which only counts awake builders) then never sees a crew.
function scr_village_has_open_site(_v)
{
    var _vid = _v.id;
    var _has = false;

    with (obj_building)
    {
        if (_has) continue;
        if (state != "construction") continue;
        if (village_id != _vid)      continue;

        _has = true;
    }

    return _has;
}

/// @func scr_village_has_era_mine(_v)
/// @desc True when the village owns a COMPLETE mine at the kingdom's current
///       era. Era 1 has no mines at all (scr_era_max_mines(1) = 0), so this is
///       always false there and era-1 miners never take a rest break.
function scr_village_has_era_mine(_v)
{
    var _level = 1;
    if (_v.kingdom_id >= 0 && _v.kingdom_id < array_length(global.kingdoms))
        _level = global.kingdoms[_v.kingdom_id].advancement_level;

    var _vid = _v.id;
    var _has = false;

    with (obj_building)
    {
        if (_has) continue;
        if (building_type != "mine") continue;
        if (state != "complete")     continue;
        if (village_id != _vid)      continue;
        if (level != _level)         continue;

        _has = true;
    }

    return _has;
}

/// @func scr_village_mining_rest_ok(_v)
/// @desc Every resource the kingdom can actually gather is at or above 40% of
///       its cap. Iron is ignored until the kingdom can mine it (era 2+).
///       Tune the fraction here.
function scr_village_mining_rest_ok(_v)
{
    var _pct = 0.40;

    if (_v.resources.wood  < _v.resource_caps.wood  * _pct) return false;
    if (_v.resources.stone < _v.resource_caps.stone * _pct) return false;

    if (scr_kingdom_can_mine_iron(_v.kingdom_id)
     && _v.resources.iron < _v.resource_caps.iron * _pct) return false;

    return true;
}

/// @func scr_village_needs_mining(_v)
/// @desc Miners stay at work unless BOTH are true:
///       1) the village owns a completed mine at the kingdom's current era,
///       2) every gatherable stock is at least 40% of its cap.
///       No mine => always true (era 1 miners never rest).
function scr_village_needs_mining(_v)
{
    if (!scr_village_has_era_mine(_v)) return true;
    return !scr_village_mining_rest_ok(_v);
}

/// @func scr_village_worker_has_work(_type, _open_site, _needs_mining)
/// @desc Does this worker role have something to do right now? Precomputed
///       per village so the tick does not rescan the building list per unit.
function scr_village_worker_has_work(_type, _open_site, _needs_mining)
{
    if (_type == "builder") return _open_site;
    if (_type == "miner")   return _needs_mining;
    return true;
}

/// @func scr_worker_has_job(_u, _open_site, _needs_mining)
/// @desc Village work check plus one per-unit exception: a miner whose
///       scr_find_harvest_target() came back empty has nothing left to mine
///       even though the stockpile is below its cap (the map ran out of
///       reachable resource tiles). It stays off duty until its retry timer
///       runs out, otherwise the tick would wake it every scan just to fail
///       the same search again.
function scr_worker_has_job(_u, _open_site, _needs_mining)
{
    // A miner that searched and found nothing rests for a while instead of
    // re-running the (expensive) ring scan every scan. The timer is ignored
    // when the village has LOST its era mine (e.g. warfare destroyed it):
    // surface harvesting is the fallback then, so the miner must come back
    // immediately instead of waiting out the retry timer.
    if (_u.unit_type == "miner" && _u.mine_dry_scans > 0)
    {
        var _v = noone;
        if (_u.village_id >= 0 && _u.village_id < array_length(global.villages))
            _v = global.villages[_u.village_id];

        if (_v != noone && scr_village_has_era_mine(_v)) return false;
    }

    return scr_village_worker_has_work(_u.unit_type, _open_site, _needs_mining);
}

/// @func scr_find_rest_workshop(_u)
/// @desc Nearest completed workshop in the unit's village, or noone. Used by
///       the builder/miner AI as the off-duty destination.
function scr_find_rest_workshop(_u)
{
    if (_u.village_id == -1) return noone;
    if (_u.village_id < 0 || _u.village_id >= array_length(global.villages)) return noone;

    var _v  = global.villages[_u.village_id];
    var _ts = obj_world.tile_size;

    var _best   = noone;
    var _best_d = 999999;

    for (var _i = 0; _i < array_length(_v.building_list); _i++)
    {
        var _b = _v.building_list[_i];
        if (!instance_exists(_b))        continue;
        if (_b.building_type != "workshop") continue;
        if (_b.state != "complete")      continue;

        var _d = point_distance(
            _u.x, _u.y,
            (_b.footprint_left + 1) * _ts,
            (_b.footprint_top  + 1) * _ts
        );

        if (_d < _best_d) { _best_d = _d; _best = _b; }
    }

    return _best;
}

/// @func scr_rest_stand_tile(_u, _b)
/// @desc Walkable tile a worker should stand on to enter the workshop. The
///       doorway below the footprint is preferred (that is where
///       scr_unit_wake drops the worker again), then a 1-tile ring around it.
///       Everything returned is within 2 tiles of the footprint, so it always
///       satisfies scr_unit_can_rest_at(). Returns [-1, -1] when walled in.
function scr_rest_stand_tile(_u, _b)
{
    if (!instance_exists(_b)) return [-1, -1];

    var _w = obj_world.world_width;
    var _h = obj_world.world_height;

    var _cx = _b.footprint_left;
    var _cy = _b.footprint_bottom + 1;

    if (_cx >= 0 && _cx < _w && _cy >= 0 && _cy < _h
     && scr_tile_allowed_for_unit(_u, _cx, _cy)) return [_cx, _cy];

    // The doorway itself is blocked: try its 8 neighbours, nearest first.
    var _ring = [
        [0, -1], [0, 1], [-1, 0], [1, 0],
        [-1, -1], [1, -1], [-1, 1], [1, 1]
    ];

    for (var _i = 0; _i < array_length(_ring); _i++)
    {
        var _gx = _cx + _ring[_i][0];
        var _gy = _cy + _ring[_i][1];

        if (_gx < 0 || _gx >= _w || _gy < 0 || _gy >= _h) continue;
        if (!scr_tile_allowed_for_unit(_u, _gx, _gy))     continue;

        return [_gx, _gy];
    }

    return [-1, -1];
}

/// @func scr_unit_can_rest_at(_u, _b)
/// @desc True when the unit is standing at the workshop (within 2 tiles of its
///       footprint). The tick only shelters workers that have already walked
///       back, so a resting worker never teleports across the village.
function scr_unit_can_rest_at(_u, _b)
{
    if (!instance_exists(_u) || !instance_exists(_b)) return false;

    var _dx = max(max(_b.footprint_left - _u.grid_x, 0), _u.grid_x - _b.footprint_right);
    var _dy = max(max(_b.footprint_top  - _u.grid_y, 0), _u.grid_y - _b.footprint_bottom);

    return (max(_dx, _dy) <= 2);
}

/// @func scr_unit_house(_u, _b)
/// @desc Puts a unit inside a building. Returns false if it was already housed.
function scr_unit_house(_u, _b)
{
    if (!instance_exists(_u)) return false;
    if (!instance_exists(_b)) return false;
    if (_u.housed)            return false;

    _u.housed        = true;
    _u.home_building = _b;
    _u.visible       = false;

    // Idle on wake: no half-finished route to resume.
    _u.walk_path          = [];
    _u.walk_index         = 0;
    _u.path_allow_res     = false;
    _u.wander_pause_timer = 0;
    _u.path_cooldown      = 0;
    _u.state              = "idle";

    array_push(_b.residents, _u);

    global.housed_units++;

    return true;
}

/// @func scr_unit_wake(_u)
/// @desc Takes a unit back out of its building and activates it at the door.
///       Safe to call on an awake unit (does nothing). Every path that gives a
///       unit something to do calls this, so nothing works while invisible.
function scr_unit_wake(_u)
{
    if (!instance_exists(_u)) return false;
    if (!_u.housed)           return false;

    var _b = _u.home_building;

    // Release the bed.
    if (instance_exists(_b) && variable_instance_exists(_b, "residents"))
    {
        for (var _i = 0; _i < array_length(_b.residents); _i++)
        {
            if (_b.residents[_i] == _u.id)
            {
                array_delete(_b.residents, _i, 1);
                break;
            }
        }
    }

    _u.housed        = false;
    _u.home_building = noone;
    _u.visible       = true;

    global.housed_units--;

    // Step out at the door: the tile immediately below the footprint. The
    // footprint itself is blocked, so using its last row would drop the unit
    // inside the walls and force the Step push-out guard to fix it.
    if (instance_exists(_b))
    {
        var _w  = obj_world.world_width;
        var _h  = obj_world.world_height;
        var _gx = clamp(_b.footprint_left,        0, _w - 1);
        var _gy = clamp(_b.footprint_bottom + 1,  0, _h - 1);

        _u.grid_x = _gx;
        _u.grid_y = _gy;
        _u.x      = _gx * obj_world.tile_size;
        _u.y      = _gy * obj_world.tile_size;

        _u.walk_path          = [];
        _u.walk_index         = 0;
        _u.path_allow_res     = false;
        _u.wander_pause_timer = irandom_range(5, 20);
        _u.path_cooldown      = irandom_range(10, 30);
    }

    return true;
}

/// @func scr_housing_tick()
/// @desc Runs once per society scan, after scr_assign_roles().
///
///       Two independent passes, both built so that nothing ever keeps a job
///       while hidden:
///
///       1) VILLAGERS / LEADER: every free bed in a complete building is filled
///          immediately, whatever the unit is currently doing. A free bed is
///          enough: the unit is hidden and its Step skipped, and its route is
///          dropped. No "must be idle" rule — that only made villagers walk
///          laps between scans for no gameplay reason.
///
///       2) BUILDERS / MINERS: workers are WOKEN whenever their job is back
///          (an open construction site, or a stock below the mining rest
///          threshold). Miners are sheltered instantly when the village has a
///          mine at its current era and every gatherable stock is at least 40%
///          full. Builders walk back to the door first. They never take beds,
///          so the population cap never moves.
///          A miner whose harvest-target search came back empty counts as
///          having no work until its retry timer expires (scr_worker_has_job),
///          so "no resource left in reach" also sends it to the workshop.
function scr_housing_tick()
{
    if (global.is_paused) return;

    // Recounted from the buildings themselves at the end, so the debug readout
    // cannot drift if anything ever destroys or reassigns a resident.
    var _total = 0;

    for (var _vi = 0; _vi < array_length(global.villages); _vi++)
    {
        var _v = global.villages[_vi];

        // A worker only shelters when its role has no work at all. Both are
        // computed once per village so the building list is not rescanned per
        // unit.
        var _open_site    = scr_village_has_open_site(_v);
        var _needs_mining = scr_village_needs_mining(_v);

        // === Wake workers whose job has come back ===
        for (var _wi = 0; _wi < array_length(_v.member_ids); _wi++)
        {
            var _au = _v.member_ids[_wi];
            if (!instance_exists(_au)) continue;
            if (!_au.housed)           continue;
            if (!scr_housing_is_worker(_au.unit_type)) continue;

            var _ahome = _au.home_building;

            // A workshop that was upgraded/destroyed cannot shelter anyone:
            // the worker was indoors when it stopped being a finished building.
            var _ahome_broken = !instance_exists(_ahome)
                             || _ahome.building_type != "workshop"
                             || _ahome.state != "complete";

            if (_ahome_broken
             || scr_worker_has_job(_au, _open_site, _needs_mining))
            {
                scr_unit_wake(_au);
            }
        }

        // === Mining retry timers ===
        // A miner that searched for a harvest target and found nothing is off
        // duty until this reaches 0. Counted in scans, so it re-probes the map
        // every 15 society scans (~15 s) instead of every frame.
        for (var _ti = 0; _ti < array_length(_v.member_ids); _ti++)
        {
            var _tu = _v.member_ids[_ti];
            if (!instance_exists(_tu)) continue;
            if (_tu.unit_type != "miner") continue;
            if (_tu.mine_dry_scans > 0) _tu.mine_dry_scans--;
        }

        // === Pass 1: villager / leader / soldier beds ===
        // Each building is filled independently so a barracks only ever takes
        // soldiers and houses/town hall never steal a soldier's bed slot.
        for (var _bi = 0; _bi < array_length(_v.building_list); _bi++)
        {
            var _b = _v.building_list[_bi];
            if (!instance_exists(_b))    continue;
            if (_b.state != "complete")  continue;

            var _beds_here = scr_housing_beds_for(_b.building_type, _b.level);
            if (_beds_here <= 0) continue;

            // === Prune stale resident ids ===
            var _kept = [];

            for (var _ri = 0; _ri < array_length(_b.residents); _ri++)
            {
                var _r = _b.residents[_ri];
                if (!instance_exists(_r))          continue;
                if (!_r.housed)                    continue;
                if (_r.home_building != _b)        continue;
                array_push(_kept, _r);
            }

            if (array_length(_kept) != array_length(_b.residents)) _b.residents = _kept;

            var _taken = array_length(_kept);
            _total += _taken;

            var _free_beds = _beds_here - _taken;
            if (_free_beds <= 0) continue;

            for (var _mi = 0; _mi < array_length(_v.member_ids); _mi++)
            {
                if (_free_beds <= 0) break;

                var _u = _v.member_ids[_mi];
                if (!instance_exists(_u))          continue;
                if (_u.housed)                     continue;
                if (_u.village_id != _v.id)        continue;
                if (!scr_housing_bed_allowed(_b.building_type, _u.unit_type)) continue;

                if (scr_unit_house(_u, _b)) { _free_beds--; _total++; }
            }
        }

        // === Pass 2: builders / miners shelter in the workshop ===
        var _level = 1;
        if (_v.kingdom_id >= 0 && _v.kingdom_id < array_length(global.kingdoms))
            _level = global.kingdoms[_v.kingdom_id].advancement_level;

        var _slots = scr_era_workshop_rest_slots(_level);

        for (var _si = 0; _si < array_length(_v.building_list); _si++)
        {
            var _ws = _v.building_list[_si];
            if (!instance_exists(_ws))              continue;
            if (_ws.building_type != "workshop")    continue;
            if (_ws.state != "complete")            continue;

            // Same self-healing prune as the bed buildings.
            var _wkept = [];

            for (var _wri = 0; _wri < array_length(_ws.residents); _wri++)
            {
                var _wr2 = _ws.residents[_wri];
                if (!instance_exists(_wr2))        continue;
                if (!_wr2.housed)                  continue;
                if (_wr2.home_building != _ws)     continue;
                array_push(_wkept, _wr2);
            }

            if (array_length(_wkept) != array_length(_ws.residents)) _ws.residents = _wkept;

            var _wtaken = array_length(_wkept);
            _total += _wtaken;

            var _free = _slots - _wtaken;
            if (_free <= 0) continue;

            for (var _wmi = 0; _wmi < array_length(_v.member_ids); _wmi++)
            {
                if (_free <= 0) break;

                var _wu = _v.member_ids[_wmi];
                if (!instance_exists(_wu))          continue;
                if (_wu.housed)                     continue;
                if (_wu.village_id != _v.id)        continue;
                if (!scr_housing_is_worker(_wu.unit_type)) continue;
                if (scr_worker_has_job(_wu, _open_site, _needs_mining)) continue;

                // Miners go inside the moment they have nothing to mine, the
                // same way a villager takes a free bed — no walk-back needed.
                // Builders still walk to the workshop first, so the return
                // trip stays visible.
                if (_wu.unit_type == "builder" && !scr_unit_can_rest_at(_wu, _ws)) continue;

                if (scr_unit_house(_wu, _ws)) { _free--; _total++; }
            }
        }
    }

    global.housed_units = _total;
}


/// @func scr_village_housed_count(_v)
/// @desc How many of this village's members are currently indoors. Used by the
///       debug readout; safe to call at any time.
function scr_village_housed_count(_v)
{
    var _count = 0;

    for (var _i = 0; _i < array_length(_v.member_ids); _i++)
    {
        var _u = _v.member_ids[_i];
        if (!instance_exists(_u)) continue;
        if (_u.housed) _count++;
    }

    return _count;
}
