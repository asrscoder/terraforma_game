depth = DEPTH.BUILDINGS;
// === Set by scr_place_construction and scr_try_complete_buildings ===
village_id    = -1;
building_type = "";          // "town_hall", "house_a", "house_b", "watchtower", "mine", "workshop", "boat_port"
building_size = 24;          // 24, 16 or 8x16 (watchtower)
level         = 1;           // advancement era at time of construction
state         = "construction";
footprint_left   = 0;
footprint_top    = 0;
footprint_right  = 0;
footprint_bottom = 0;

// === Mine income (mines only; ignored by other building types) ===
mine_income_timer = 0;      // frames since the last payout

// === Boat port facing (boat_port only) ===
// 0 = ocean south, 1 = east, 2 = north, 3 = west (see scr_port_dir_angle).
port_dir = 0;

// === Housing ===
// Unit ids currently living inside this building. The bed count comes from
// scr_housing_beds_for(building_type, level), which is also what
// scr_village_housing_cap adds up, so the two can never disagree.
residents = [];

// === Default sprite ===
sprite_index = spr_building_construction_24;
image_speed  = 1;
image_index  = 0;

show_debug_message("BUILDING CREATED: type=" + string(building_type) + " x=" + string(x) + " y=" + string(y) + " village_id=" + string(village_id));
