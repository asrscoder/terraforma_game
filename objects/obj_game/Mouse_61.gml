// World position under the mouse, before zoom changes
var _cam  = view_camera[0];
var _vw   = view_wport[0];
var _vh   = view_hport[0];
var _gx   = device_mouse_x_to_gui(0) - view_xport[0];
var _gy   = device_mouse_y_to_gui(0) - view_yport[0];

var _old_sx = (camera_base_w / camera_zoom) / _vw;
var _old_sy = (camera_base_h / camera_zoom) / _vh;

var _mouse_world_x = camera_x + _gx * _old_sx;
var _mouse_world_y = camera_y + _gy * _old_sy;

// Apply zoom
camera_zoom = clamp(camera_zoom / 1.1, camera_zoom_min, camera_zoom_max);

var _new_sx = (camera_base_w / camera_zoom) / _vw;
var _new_sy = (camera_base_h / camera_zoom) / _vh;

// Re-anchor camera so the same world point stays under the mouse
camera_x = _mouse_world_x - _gx * _new_sx;
camera_y = _mouse_world_y - _gy * _new_sy;