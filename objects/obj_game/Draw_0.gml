// obj_game/Draw
// Housed units still exist as instances (so Units counts them); "Out" is how
// many actually run their Step and draw.
draw_text(10, 10, "FPS: " + string(fps)
                + "  Units: " + string(instance_number(obj_unit))
                + "  Out: "   + string(instance_number(obj_unit) - global.housed_units));

// --- Housing / shelter debug breakdown ---
// Global totals across every village: total capacity vs. units currently inside.
var _bed_house = 0, _in_house = 0;
var _bed_bar   = 0, _in_bar   = 0;
var _slot_ws   = 0, _in_ws    = 0;

for (var _vi = 0; _vi < array_length(global.villages); _vi++)
{
    var _v = global.villages[_vi];
    if (!variable_struct_exists(_v, "building_list")) continue;

    var _level = 1;
    if (_v.kingdom_id >= 0 && _v.kingdom_id < array_length(global.kingdoms))
        _level = global.kingdoms[_v.kingdom_id].advancement_level;

    for (var _bi = 0; _bi < array_length(_v.building_list); _bi++)
    {
        var _b = _v.building_list[_bi];
        if (!instance_exists(_b)) continue;
        if (_b.state != "complete") continue;

        var _bt = _b.building_type;
        if (_bt == "town_hall" || _bt == "house_a" || _bt == "house_b")
        {
            _bed_house += scr_housing_beds_for(_bt, _b.level);
            for (var _ri = 0; _ri < array_length(_b.residents); _ri++)
                if (instance_exists(_b.residents[_ri])) _in_house++;
        }
        else if (_bt == "barracks")
        {
            _bed_bar += scr_housing_beds_for(_bt, _b.level);
            for (var _ri = 0; _ri < array_length(_b.residents); _ri++)
                if (instance_exists(_b.residents[_ri])) _in_bar++;
        }
        else if (_bt == "workshop")
        {
            _slot_ws += scr_era_workshop_rest_slots(_level);
            for (var _ri = 0; _ri < array_length(_b.residents); _ri++)
                if (instance_exists(_b.residents[_ri])) _in_ws++;
        }
    }
}

var _yy = 26;
draw_text(10, _yy, "Houses/TH: " + string(_in_house) + " / " + string(_bed_house) + "  (villager+leader)");
_yy += 14;
draw_text(10, _yy, "Barracks:  " + string(_in_bar) + " / " + string(_bed_bar) + "  (soldier)");
_yy += 14;
draw_text(10, _yy, "Workshop:  " + string(_in_ws) + " / " + string(_slot_ws) + "  (builder+miner)");
