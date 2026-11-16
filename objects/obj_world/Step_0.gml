anim_timer += anim_speed

// Resource regrowth + capped spread (no-op while paused)
scr_tick_resource_respawn();

// Completed mines pay out stone + iron to their village (no-op while paused)
scr_tick_mine_income();

if (keyboard_check_pressed(vk_space))
{
    global.is_paused = !global.is_paused;
}