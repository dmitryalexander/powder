// Define namespaced commands after sign-on; never assign the user's keys/cvars.
::R1PM_LoadCommands <- function()
{
    while(!("GetLocalClientPlayer" in getroottable()))wait 0.1
    local p=GetLocalClientPlayer()
    while(!IsValid(p)){wait 0.1;p=GetLocalClientPlayer()}
    wait 0.5
    p.ClientCommand("exec r1pm_commands")
    IncludeScript("autorun/cl_r1pm_grapple_aim",getroottable())
    IncludeScript("autorun/cl_r1pm_grapple_flight",getroottable())
}
thread R1PM_LoadCommands()
