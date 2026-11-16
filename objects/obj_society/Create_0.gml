// Free cached territory surfaces from a previous world (room restart / reload)
if (variable_global_exists("villages"))
{
    for (var _i = 0; _i < array_length(global.villages); _i++)
    {
        var _old = global.villages[_i];

        if (variable_struct_exists(_old, "territory_fill_surf")
         && surface_exists(_old.territory_fill_surf))
        {
            surface_free(_old.territory_fill_surf);
        }

        if (variable_struct_exists(_old, "territory_border_surf")
         && surface_exists(_old.territory_border_surf))
        {
            surface_free(_old.territory_border_surf);
        }
    }
}

global.villages = [];
global.kingdoms = [];

// Founding beacon.
global.village_founder_id = noone;
global.village_founder_x  = -1;
global.village_founder_y  = -1;

// How often to scan for new villages (in frames)
scan_interval = 60;   // once per second at 60fps
scan_timer    = scan_interval;
reproduction_timer = 0;

depth = DEPTH.BORDERS;