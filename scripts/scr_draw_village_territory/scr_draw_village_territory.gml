/// @func scr_draw_village_territory(_village_id, _color)
/// @desc Draws the village's territory from cached surfaces: a translucent fill
///       plus a 4-pixel perimeter outline. Each surface is rebuilt only when the
///       territory changes (expansion) or after a surface loss, so the normal
///       per-frame cost is two draw calls per visible village instead of a full
///       bounding-box tile scan.
///
///       Both surfaces are baked in solid white (alpha 1) so no alpha-squaring
///       happens when rendering into them. The kingdom colour and the per-layer
///       alpha are applied at draw time with draw_surface_ext().
function scr_draw_village_territory(_village_id, _color)
{
    var _ts = obj_world.tile_size;
    var _v  = global.villages[_village_id];

    // === Camera cull (pixel bounds vs view) ===
    var _cam   = view_camera[0];
    var _cam_x = camera_get_view_x(_cam);
    var _cam_y = camera_get_view_y(_cam);
    var _cam_w = camera_get_view_width(_cam);
    var _cam_h = camera_get_view_height(_cam);

    var _pad = _ts * 4;

    var _vl = _v.left         * _ts;
    var _vt = _v.top          * _ts;
    var _vr = (_v.right  + 1) * _ts;
    var _vb = (_v.bottom + 1) * _ts;

    // === Defensive init for villages created before the cache fields existed ===
    if (!variable_struct_exists(_v, "territory_fill_surf"))
    {
        _v.territory_fill_surf     = -1;
        _v.territory_border_surf   = -1;
        _v.territory_surf_left     = -1;
        _v.territory_surf_top      = -1;
        _v.territory_surf_right    = -1;
        _v.territory_surf_bottom   = -1;
        _v.territory_surf_seen     = 0;
        _v.territory_dirty         = true;
    }
    if (!variable_struct_exists(_v, "territory_surf_seen"))
    {
        _v.territory_surf_seen = 0;
    }

    var _visible = !(_vr < _cam_x - _pad
                  || _vl > _cam_x + _cam_w + _pad
                  || _vb < _cam_y - _pad
                  || _vt > _cam_y + _cam_h + _pad);

    if (!_visible)
    {
        // Free surfaces that have been off-screen for a while so VRAM stays bounded
        if (current_time - _v.territory_surf_seen > 30000)
        {
            if (surface_exists(_v.territory_fill_surf))   surface_free(_v.territory_fill_surf);
            if (surface_exists(_v.territory_border_surf)) surface_free(_v.territory_border_surf);

            _v.territory_fill_surf   = -1;
            _v.territory_border_surf = -1;
            _v.territory_dirty       = true;
        }
        return;
    }

    _v.territory_surf_seen = current_time;

    var _pw = _vr - _vl;
    var _ph = _vb - _vt;
    if (_pw <= 0 || _ph <= 0) return;

    // Maximum surface edge. Era 4 caps at 201 tiles = 1608 px, but fall back
    // to direct drawing if a future era ever exceeds the safe limit.
    var _max_dim = 2048;

    if (_pw > _max_dim || _ph > _max_dim)
    {
        scr_draw_village_territory_direct(_v, _color, _cam_x, _cam_y, _cam_w, _cam_h);
        return;
    }

    // === Validate the cache ===
    var _fill   = _v.territory_fill_surf;
    var _border = _v.territory_border_surf;

    var _valid = surface_exists(_fill)
              && surface_exists(_border)
              && !_v.territory_dirty
              && _v.territory_surf_left   == _v.left
              && _v.territory_surf_top    == _v.top
              && _v.territory_surf_right  == _v.right
              && _v.territory_surf_bottom == _v.bottom;

    // === Rebuild when stale ===
    if (!_valid)
    {
        if (surface_exists(_fill))   surface_free(_fill);
        if (surface_exists(_border)) surface_free(_border);

        _fill   = surface_create(_pw, _ph);
        _border = surface_create(_pw, _ph);

        if (!surface_exists(_fill) || !surface_exists(_border))
        {
            // Out of VRAM / device lost: draw uncached this frame.
            if (surface_exists(_fill))   surface_free(_fill);
            if (surface_exists(_border)) surface_free(_border);
            _v.territory_fill_surf   = -1;
            _v.territory_border_surf = -1;
            scr_draw_village_territory_direct(_v, _color, _cam_x, _cam_y, _cam_w, _cam_h);
            return;
        }

        // surface_set_target() switches to the default camera. Point a
        // temporary camera at the village bounds and apply it (documented
        // way to choose the camera used when drawing to a surface) so the
        // geometry is transformed exactly like normal world drawing.
        var _surf_cam = camera_create_view(_vl, _vt, _pw, _ph);

        // --- Membership bitmap: one ownership lookup per tile ---
        // Both passes below need the same "is this tile claimed" answer, and
        // the border pass needs it for four neighbours too. Resolving it once
        // into a local bitmap turns ~6 scr_tile_in_union() calls per tile into
        // one, which is what made each rebuild of a large village hitch.
        var _gw = _v.right  - _v.left + 1;
        var _gh = _v.bottom - _v.top  + 1;

        var _union = array_create(_gw * _gh, 0);

        for (var _iy = 0; _iy < _gh; _iy++)
        {
            var _ury = _iy * _gw;
            var _ugy = _v.top + _iy;

            for (var _ix = 0; _ix < _gw; _ix++)
            {
                if (!scr_tile_in_union(_v, _v.left + _ix, _ugy)) continue;
                _union[_ix + _ury] = 1;
            }
        }

        // --- Fill surface: solid white tiles ---
        if (!surface_set_target(_fill))
        {
            camera_destroy(_surf_cam);
            surface_free(_fill);
            surface_free(_border);
            _v.territory_fill_surf   = -1;
            _v.territory_border_surf = -1;
            scr_draw_village_territory_direct(_v, _color, _cam_x, _cam_y, _cam_w, _cam_h);
            return;
        }
        camera_apply(_surf_cam);

        draw_clear_alpha(c_black, 0);
        draw_set_colour(c_white);
        draw_set_alpha(1);

        for (var _iy2 = 0; _iy2 < _gh; _iy2++)
        {
            var _ly = (_v.top + _iy2) * _ts;
            var _frow = _iy2 * _gw;

            for (var _ix2 = 0; _ix2 < _gw; _ix2++)
            {
                if (_union[_ix2 + _frow] == 0) continue;

                var _lx = (_v.left + _ix2) * _ts;
                draw_rectangle(_lx, _ly, _lx + _ts, _ly + _ts, false);
            }
        }

        surface_reset_target();

        // --- Border surface: solid white perimeter strips ---
        if (!surface_set_target(_border))
        {
            camera_apply(view_camera[0]);
            camera_destroy(_surf_cam);

            surface_free(_fill);
            surface_free(_border);
            _v.territory_fill_surf   = -1;
            _v.territory_border_surf = -1;
            scr_draw_village_territory_direct(_v, _color, _cam_x, _cam_y, _cam_w, _cam_h);
            return;
        }
        camera_apply(_surf_cam);

        draw_clear_alpha(c_black, 0);
        draw_set_colour(c_white);
        draw_set_alpha(1);

        var _th = 4;   // border thickness in pixels

        for (var _iy3 = 0; _iy3 < _gh; _iy3++)
        {
            var _ly2 = (_v.top + _iy3) * _ts;
            var _brow = _iy3 * _gw;

            for (var _ix3 = 0; _ix3 < _gw; _ix3++)
            {
                var _bidx = _ix3 + _brow;
                if (_union[_bidx] == 0) continue;

                var _lx2 = (_v.left + _ix3) * _ts;

                // Neighbour lookups in the bitmap; a neighbour outside the
                // bounds box is unclaimed, which is how the old code behaved.
                var _n_up    = (_iy3 > 0)       && (_union[_bidx - _gw] != 0);
                var _n_down  = (_iy3 < _gh - 1) && (_union[_bidx + _gw] != 0);
                var _n_left  = (_ix3 > 0)       && (_union[_bidx - 1]   != 0);
                var _n_right = (_ix3 < _gw - 1) && (_union[_bidx + 1]   != 0);

                if (!_n_up)
                    draw_rectangle(_lx2, _ly2, _lx2 + _ts, _ly2 + _th, false);

                if (!_n_down)
                    draw_rectangle(_lx2, _ly2 + _ts - _th, _lx2 + _ts, _ly2 + _ts, false);

                if (!_n_left)
                    draw_rectangle(_lx2, _ly2, _lx2 + _th, _ly2 + _ts, false);

                if (!_n_right)
                    draw_rectangle(_lx2 + _ts - _th, _ly2, _lx2 + _ts, _ly2 + _ts, false);
            }
        }

        surface_reset_target();

        camera_apply(view_camera[0]);
        camera_destroy(_surf_cam);

        draw_set_alpha(1);
        draw_set_colour(c_white);

        _v.territory_fill_surf     = _fill;
        _v.territory_border_surf   = _border;
        _v.territory_surf_left     = _v.left;
        _v.territory_surf_top      = _v.top;
        _v.territory_surf_right    = _v.right;
        _v.territory_surf_bottom   = _v.bottom;
        _v.territory_dirty         = false;

        // Structs are references, but store back to match the codebase pattern
        global.villages[_village_id] = _v;
    }

    // === Draw the cached surfaces tinted with the kingdom colour ===
    draw_surface_ext(_fill,   _vl, _vt, 1, 1, 0, _color, 0.15);
    draw_surface_ext(_border, _vl, _vt, 1, 1, 0, _color, 1);
}

/// @func scr_draw_village_territory_direct(_v, _color, _cam_x, _cam_y, _cam_w, _cam_h)
/// @desc Uncached fallback used only when the territory is too large for a
///       surface or surface creation fails. Camera-clipped and alpha-batched.
function scr_draw_village_territory_direct(_v, _color, _cam_x, _cam_y, _cam_w, _cam_h)
{
    var _ts  = obj_world.tile_size;
    var _pad = _ts * 4;

    var _gx0 = max(_v.left,   floor((_cam_x - _pad) / _ts));
    var _gx1 = min(_v.right,  ceil ((_cam_x + _cam_w + _pad) / _ts));
    var _gy0 = max(_v.top,    floor((_cam_y - _pad) / _ts));
    var _gy1 = min(_v.bottom, ceil ((_cam_y + _cam_h + _pad) / _ts));

    draw_set_colour(_color);

    // Fill
    draw_set_alpha(0.15);
    for (var _gy = _gy0; _gy <= _gy1; _gy++)
    {
        for (var _gx = _gx0; _gx <= _gx1; _gx++)
        {
            if (!scr_tile_in_union(_v, _gx, _gy)) continue;

            var _px = _gx * _ts;
            var _py = _gy * _ts;
            draw_rectangle(_px, _py, _px + _ts, _py + _ts, false);
        }
    }

    // Outline
    draw_set_alpha(1);
    var _th = 4;

    for (var _gy2 = _gy0; _gy2 <= _gy1; _gy2++)
    {
        for (var _gx2 = _gx0; _gx2 <= _gx1; _gx2++)
        {
            if (!scr_tile_in_union(_v, _gx2, _gy2)) continue;

            var _qx = _gx2 * _ts;
            var _qy = _gy2 * _ts;

            if (!scr_tile_in_union(_v, _gx2, _gy2 - 1))
                draw_rectangle(_qx, _qy, _qx + _ts, _qy + _th, false);

            if (!scr_tile_in_union(_v, _gx2, _gy2 + 1))
                draw_rectangle(_qx, _qy + _ts - _th, _qx + _ts, _qy + _ts, false);

            if (!scr_tile_in_union(_v, _gx2 - 1, _gy2))
                draw_rectangle(_qx, _qy, _qx + _th, _qy + _ts, false);

            if (!scr_tile_in_union(_v, _gx2 + 1, _gy2))
                draw_rectangle(_qx + _ts - _th, _qy, _qx + _ts, _qy + _ts, false);
        }
    }

    draw_set_alpha(1);
    draw_set_colour(c_white);
}
