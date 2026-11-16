// rm_world — Creation Code
var _mon_w = display_get_width();
var _mon_h = display_get_height();

// Set viewport before any instance exists
view_wport[0] = _mon_w;
view_hport[0] = _mon_h;

// Resize window
window_set_size(_mon_w, _mon_h);
window_center();

// Resize application surface to match
surface_resize(application_surface, _mon_w, _mon_h);

// Crisp pixels from frame one
gpu_set_texfilter(false);