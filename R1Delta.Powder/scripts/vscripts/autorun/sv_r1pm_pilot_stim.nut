// Double Stim's extra speed: native 1.35 -> 1.70. No velocity injection.
// Native player classes are locked after instantiation; keep methods intact.
if("R1Stim" in getroottable())
{
    R1Stim.enabled=false
    if("actors" in R1Stim)foreach(entry in R1Stim.actors)
        if(IsValid(entry.actor) && entry.boosted)entry.actor.UpdateMoveSpeedScale()
}
::R1Stim <- {generation=UniqueString("stim"),enabled=true,error=null,scale=1.70,actors=[],boostFrames=0,resets=0}
::R1Stim_Run <- function(generation)
{
    try
    {
        while(!("PlayerHasServerFlag" in getroottable()) || !("IsPrivateMatch" in getroottable()) || !("SFLAG_STIM_OFFHAND" in getroottable()))wait 0.1
        R1Stim.scale=1.0+(getconsttable()["ABILITY_STIM_SPEED_MOD"]-1.0)*2.0
        while(R1Stim.enabled && R1Stim.generation==generation)
        {
            foreach(p in GetPlayerArray())
            {
                if(!IsValid(p))continue
                local state=null
                foreach(entry in R1Stim.actors)if(entry.actor==p)state=entry
                if(state==null){state={actor=p,boosted=false};R1Stim.actors.append(state)}
                local active=IsPrivateMatch() && IsAlive(p) && p.IsHuman() && PlayerHasServerFlag(p,SFLAG_STIM_OFFHAND)
                if(active)
                {
                    p.SetMoveSpeedScale(R1Stim.scale)
                    state.boosted=true;R1Stim.boostFrames++
                }
                else if(state.boosted)
                {
                    p.UpdateMoveSpeedScale()
                    state.boosted=false;R1Stim.resets++
                }
            }
            for(local i=R1Stim.actors.len()-1;i>=0;i--)
                if(!IsValid(R1Stim.actors[i].actor))R1Stim.actors.remove(i)
            WaitFrame()
        }
        if(R1Stim.generation==generation)
            foreach(entry in R1Stim.actors)if(IsValid(entry.actor) && entry.boosted)entry.actor.UpdateMoveSpeedScale()
    }
    catch(err)
    {
        R1Stim.error=err.tostring();R1Stim.enabled=false
        foreach(entry in R1Stim.actors)if(IsValid(entry.actor) && entry.boosted)entry.actor.UpdateMoveSpeedScale()
        printt("[R1Stim] Native fallback after error:",err)
    }
}
thread R1Stim_Run(R1Stim.generation)
