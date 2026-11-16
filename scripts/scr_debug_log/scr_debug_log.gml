/// @func scr_debug_log(_msg)
/// @desc Development logging helper.
///
///       show_debug_message() is a synchronous write to the Output window and
///       is genuinely expensive when it fires per scan. Per-second diagnostics
///       therefore go through here and are silent unless global.debug_logs is
///       explicitly turned on while debugging.
///
///       Set global.debug_logs = true (obj_world Create) to re-enable them.
function scr_debug_log(_msg)
{
    if (variable_global_exists("debug_logs") && global.debug_logs)
    {
        show_debug_message(_msg);
    }
}
