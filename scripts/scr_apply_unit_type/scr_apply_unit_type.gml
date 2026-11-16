/// @func scr_apply_unit_type(_unit, _type)
/// @desc Sets sprites, speed, behavior, and stats based on unit type.
function scr_apply_unit_type(_unit, _type)
{
    // A unit that is being given a type must be active: this is also the path
    // role assignment takes when it promotes a villager to a working role, so
    // an indoors unit steps out here before it is told what to do.
    scr_unit_wake(_unit);

    _unit.unit_type = _type;

    // ==========================================
    // 1. BASE DEFAULTS (Every unit starts as a land villager)
    // ==========================================
    _unit.unit_class            = scr_unit_class_for_type(_type);  // "land", "water", "air"
    _unit.can_leave_territory   = false;       // Can they cross the purple border?
    _unit.can_walk_on_resources = false;       // Can they step on trees/rocks?
    _unit.can_walk_on_water     = false;       // Can they swim?
    _unit.can_harvest           = false;
    _unit.can_build             = false;
    _unit.is_leader             = false;
    
    _unit.hp                    = 10;
    _unit.max_hp                = 10;
    _unit.damage                = 0;
    _unit.attack_range          = 0;
    _unit.can_attack_air        = false;

    // ==========================================
    // 2. SPECIFIC OVERRIDES
    // ==========================================
    switch (_type)
    {
        case "villager":
            _unit.spr_idle = spr_human_villager_idle;
            _unit.spr_walk = spr_human_villager_walk;
            _unit.move_speed       = 1.5;
            _unit.wander_radius    = 10;
            _unit.wander_pause_min = 15;
            _unit.wander_pause_max = 30;
            break;

        case "soldier":
            _unit.spr_idle = spr_human_soldier_idle;
            _unit.spr_walk = spr_human_soldier_walk;
            _unit.move_speed       = 2.0;
            _unit.wander_radius    = 25;
            _unit.wander_pause_min = 5;
            _unit.wander_pause_max = 15;
            
            _unit.can_leave_territory = true; // Soldiers can patrol outside
            _unit.hp      = 50;
            _unit.max_hp  = 50;
            _unit.damage  = 10;
            _unit.attack_range = 1; // Melee
            break;

        case "farmer":
            _unit.spr_idle = spr_human_farmer_idle;
            _unit.spr_walk = spr_human_farmer_walk;
            _unit.move_speed       = 1.3;
            _unit.wander_radius    = 8;
            _unit.wander_pause_min = 20;
            _unit.wander_pause_max = 45;
            break;

        case "miner":
            _unit.spr_idle = spr_human_miner_idle;
            _unit.spr_walk = spr_human_miner_walk;
            _unit.move_speed       = 1.4;
            _unit.wander_radius    = 12;
            _unit.wander_pause_min = 15;
            _unit.wander_pause_max = 35;
            
            _unit.can_leave_territory   = true; // Miners leave to gather
            _unit.can_walk_on_resources = true; // Miners can walk on trees/rocks
            _unit.can_harvest           = true;
            break;

        case "builder":
            _unit.spr_idle = spr_human_builder_idle;
            _unit.spr_walk = spr_human_builder_walk;
            _unit.move_speed       = 1.4;
            _unit.wander_radius    = 12;
            _unit.wander_pause_min = 15;
            _unit.wander_pause_max = 35;
            
            _unit.can_build = true;
            break;

        case "leader":
            _unit.spr_body_idle  = spr_human_leader_body_idle;
            _unit.spr_body_walk  = spr_human_leader_body_walk;
            _unit.spr_tunic_idle = spr_human_leader_tunic_idle;
            _unit.spr_tunic_walk = spr_human_leader_tunic_walk;
            _unit.spr_idle = spr_human_leader_body_idle;
            _unit.spr_walk = spr_human_leader_body_walk;
            
            _unit.move_speed       = 1.3;
            _unit.wander_radius    = 5;
            _unit.wander_pause_min = 20;
            _unit.wander_pause_max = 45;
            
            _unit.is_leader = true;
            _unit.hp        = 100;
            _unit.max_hp    = 100;
            break;
            
        // ==========================================
        // FUTURE UNITS GO HERE
        // ==========================================
        case "ship":
        {
            // Water unit: spawns and sails on ocean tiles only — the opposite
            // of a land unit. Era 3+ reuse the era-2 art.
            var _era = 1;
            if (_unit.kingdom_id >= 0
             && variable_global_exists("kingdoms")
             && _unit.kingdom_id < array_length(global.kingdoms))
            {
                _era = global.kingdoms[_unit.kingdom_id].advancement_level;
            }

            var _ship_spr = (_era >= 2) ? spr_ship_era2 : spr_ship_era1;
            _unit.spr_idle = _ship_spr;
            _unit.spr_walk = _ship_spr;

            _unit.move_speed       = 2.5;
            _unit.wander_radius    = 12;
            _unit.wander_pause_min = 20;
            _unit.wander_pause_max = 45;

            _unit.unit_class          = "water"; // Water tiles only
            _unit.can_leave_territory = true;
            _unit.can_walk_on_water   = true;

            _unit.hp = 200;
            _unit.max_hp = 200;
            _unit.damage = 25;
            _unit.attack_range = 4;
            break;
        }

        case "plane":
            _unit.spr_idle = spr_plane_idle;
            _unit.spr_walk = spr_plane_walk;
            _unit.move_speed = 5.0;
            _unit.unit_class = "air"; // Ignores terrain entirely
            _unit.can_leave_territory = true;
            _unit.hp = 150;
            _unit.max_hp = 150;
            _unit.damage = 50;
            _unit.attack_range = 3;
            _unit.can_attack_air = true;
            break;

        default:
            _unit.spr_idle = spr_human_villager_idle;
            _unit.spr_walk = spr_human_villager_walk;
            _unit.move_speed       = 1.5;
            _unit.wander_radius    = 10;
            _unit.wander_pause_min = 15;
            _unit.wander_pause_max = 30;
            break;
    }

    // ==========================================
    // 3. FINAL SETUP
    // ==========================================
    _unit.sprite_index = _unit.spr_idle;
    _unit.image_index  = 0;

    _unit.harvest_target_x = -1;
    _unit.harvest_target_y = -1;
    _unit.harvest_timer    = 0;
    _unit.mine_dry_scans   = 0;

    _unit.build_target_id  = noone;
    
    // Reset pathing so they don't get stuck on an old path
    _unit.walk_path = [];
    _unit.walk_index = 0;
    _unit.path_allow_res = false;
}

/// @func scr_unit_class_for_type(_type)
/// @desc Terrain class owned by a unit type, known before the instance exists.
///       This is what lets spawners check the tile before creating the unit.
///         "land"  — walks on land, water is impassable
///         "water" — sails on water, land is impassable (ships)
///         "air"   — ignores terrain (planes)
function scr_unit_class_for_type(_type)
{
    switch (_type)
    {
        case "ship":  return "water";
        case "plane": return "air";
    }
    return "land";
}