// Audio-only observer: never writes movement, grapple, rope or control state.
if("R1MovementAudio_Stop" in getroottable())R1MovementAudio_Stop()
::R1MovementAudio <- {enabled=true,generation=UniqueString("audio"),actors=[],error=null,events={},frames=0}
::R1MovementAudio_Emit <- function(p,event)
{
    EmitSoundOnEntityOnlyToPlayer(p,p,"R1PM."+event)
    if(!(event in R1MovementAudio.events))R1MovementAudio.events[event] <- 0
    R1MovementAudio.events[event]++
}
::R1MovementAudio_StopLoop <- function(p,event)
{
    if(IsValid(p) && event!="")StopSoundOnEntity(p,"R1PM."+event)
}
::R1MovementAudio_Stop <- function()
{
    R1MovementAudio.enabled=false
    foreach(a in R1MovementAudio.actors)if(IsValid(a.player))
    {
        R1MovementAudio_StopLoop(a.player,a.loop)
        R1MovementAudio_StopLoop(a.player,"slide.start."+a.surface)
    }
}
::R1MovementAudio_Surface <- function(name,grapple=false)
{
    name=name.tolower()
    if(name.find("wood")!=null)return "wood"
    if(name.find("sand")!=null)return "sand"
    if(name.find("mud")!=null || name.find("slime")!=null)return "mud"
    if(name.find("water")!=null || name.find("splash")!=null)return grapple ? "default" : "water"
    if(name.find("grass")!=null || name.find("foliage")!=null || name.find("brush")!=null)return grapple ? "dirt" : "grass"
    if(name.find("dirt")!=null || name.find("snow")!=null || name.find("carpet")!=null)return "dirt"
    if(name.find("metal")!=null || name.find("grate")!=null || name.find("vent")!=null || name.find("chain")!=null)return "solidmetal"
    return "concrete"
}
::R1MovementAudio_Ground <- function(p)
{
    local origin=p.GetOrigin()
    local t=TraceLine(origin+Vector(0,0,8),origin-Vector(0,0,48),p,TRACE_MASK_SHOT,TRACE_COLLISION_GROUP_NONE)
    return R1MovementAudio_Surface(t.surfaceName)
}
::R1MovementAudio_HookSurface <- function(p,g)
{
    local normal=("hookNormal" in g) ? g.hookNormal : Vector(0,0,1)
    local t=TraceLine(g.anchor+normal*6,g.anchor-normal*6,p,TRACE_MASK_SHOT,TRACE_COLLISION_GROUP_NONE)
    return R1MovementAudio_Surface(t.surfaceName,true)
}
::R1MovementAudio_State <- function(p)
{
    foreach(a in R1MovementAudio.actors)if(a.player==p)return a
    local a={player=p,phase="idle",shot=-1.0,attach=-1,loop="",slide=false,surface="concrete",hookSurface="concrete",speed=0.0,bumpAt=-10.0,boostAt=-1000.0}
    R1MovementAudio.actors.append(a)
    return a
}
::R1MovementAudio_Update <- function(p)
{
    local a=R1MovementAudio_State(p)
    local eligible=GetMapName()!="mp_lobby" && IsPrivateMatch() && IsAlive(p) && p.IsHuman() && !p.IsTitan()
    if(!eligible)
    {
        R1MovementAudio_StopLoop(p,a.loop)
        if(a.slide)R1MovementAudio_StopLoop(p,"slide.start."+a.surface)
        a.loop="";a.slide=false;a.phase="idle";a.shot=-1.0;a.attach=-1
        return
    }
    local g=("r1Grapple" in p.s) ? p.s.r1Grapple : null
    local phase=g!=null ? g.phase : "idle"
    local deployed=phase!="idle"
    if(g!=null && deployed && g.started!=a.shot)
    {
        // Release-return also updates started; it is not a second shot.
        if(phase!="release_return" && phase!="miss_return")R1MovementAudio_Emit(p,"grapple.fire")
        a.shot=g.started
    }
    if(g!=null && (phase=="clamped" || phase=="pulling") && g.attachCount!=a.attach)
    {
        a.hookSurface=R1MovementAudio_HookSurface(p,g)
        R1MovementAudio_Emit(p,"grapple.impact."+a.hookSurface)
        a.attach=g.attachCount
    }
    local returning=phase=="release_return" || phase=="miss_return"
    local loop=phase=="pulling" ? "grapple.traverse" : (returning ? "grapple.retract" : "")
    if(loop!=a.loop)
    {
        R1MovementAudio_StopLoop(p,a.loop)
        if(loop!="")R1MovementAudio_Emit(p,loop)
        a.loop=loop
    }
    if(returning && (a.phase=="pulling" || a.phase=="clamped"))R1MovementAudio_Emit(p,"grapple.extract."+a.hookSurface)
    if(phase=="idle" && a.phase!="idle")R1MovementAudio_Emit(p,"grapple.reset")
    a.phase=phase

    local slide=("R1Slide" in getroottable()) && R1Slide.enabled && ("r1SlideState" in p.s) && p.s.r1SlideState.active && p.IsOnGround() && !deployed
    if(slide && p.s.r1SlideState.lastBoostTime!=a.boostAt)
    {
        // Observe the actual accepted boost timestamp; never add a second boost.
        if(Time()-p.s.r1SlideState.lastBoostTime<0.1)R1MovementAudio_Emit(p,"slide.boost")
        a.boostAt=p.s.r1SlideState.lastBoostTime
    }
    local speed=p.GetVelocity().Length2D()
    if(slide)
    {
        local surface=R1MovementAudio_Ground(p)
        if(!a.slide)R1MovementAudio_Emit(p,"slide.start."+surface)
        else if(surface!=a.surface)
        {
            R1MovementAudio_StopLoop(p,"slide.start."+a.surface)
            R1MovementAudio_Emit(p,"slide.stop."+a.surface)
            R1MovementAudio_Emit(p,"slide.start."+surface)
        }
        else if(a.speed-speed>100.0 && Time()-a.bumpAt>0.2)
        {
            R1MovementAudio_Emit(p,"slide.bump."+surface);a.bumpAt=Time()
        }
        a.surface=surface
    }
    else if(a.slide)
    {
        R1MovementAudio_StopLoop(p,"slide.start."+a.surface)
        R1MovementAudio_Emit(p,"slide.stop."+a.surface)
    }
    a.slide=slide;a.speed=speed
}
::R1MovementAudio_Run <- function(generation)
{
    while(!("GetPlayerArray" in getroottable()) || !("EmitSoundOnEntityOnlyToPlayer" in getroottable()) || !("IsPrivateMatch" in getroottable()))wait 0.1
    while(R1MovementAudio.enabled && R1MovementAudio.generation==generation)
    {
        foreach(p in GetPlayerArray())if(IsValid(p))
        {
            try{R1MovementAudio_Update(p)}
            catch(err)
            {
                R1MovementAudio.error=err.tostring()
                local a=R1MovementAudio_State(p);R1MovementAudio_StopLoop(p,a.loop);a.loop=""
                R1MovementAudio_StopLoop(p,"slide.start."+a.surface);a.slide=false
            }
        }
        for(local i=R1MovementAudio.actors.len()-1;i>=0;i--)if(!IsValid(R1MovementAudio.actors[i].player))R1MovementAudio.actors.remove(i)
        R1MovementAudio.frames++
        WaitFrame()
    }
}
thread R1MovementAudio_Run(R1MovementAudio.generation)
