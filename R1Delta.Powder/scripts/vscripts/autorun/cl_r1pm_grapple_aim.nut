// Camera-attached HUD ring; world debug lines trail during camera rotation.
if("R1GrappleAim_Stop" in getroottable())R1GrappleAim_Stop()
if(!("R1GrappleAim" in getroottable()))
    ::R1GrappleAim <- {generation=0,enabled=false,validTarget=false,error=null}
if(!("screen" in R1GrappleAim))R1GrappleAim.screen <- null
if(!("circle" in R1GrappleAim))R1GrappleAim.circle <- null
if(!("cockpit" in R1GrappleAim))R1GrappleAim.cockpit <- null
R1GrappleAim.xScreen <- null
R1GrappleAim.xIcon <- null
R1GrappleAim.generation++
R1GrappleAim.enabled=true
R1GrappleAim.error=null
R1GrappleAim.stage <- "starting"
R1GrappleAim.xScale <- 1.0
R1GrappleAim.lastTime <- Time()
R1GrappleAim.connected <- false
R1GrappleAim.attached <- false
R1GrappleAim.phase <- "idle"
R1GrappleAim.enemyInSight <- false
R1GrappleAim.enemyTarget <- null
::R1GrappleAim_IsEnemy <- function(player,target)
{
    if(!IsValid(target) || target==player)return false
    if(!target.IsNPC() && !target.IsPlayer())return false
    if(!IsAlive(target))return false
    // cl_player's IsEnemyTeam is file-local, so use its native relationship
    // rule directly instead of calling an unavailable root function.
    if("IsFFABased" in getroottable() && IsFFABased() && "ShouldPreventFriendlyFire" in getroottable())
        return !ShouldPreventFriendlyFire(player,target)
    local ownTeam=player.GetTeam();local otherTeam=target.GetTeam()
    return (ownTeam==TEAM_IMC && otherTeam==TEAM_MILITIA) || (ownTeam==TEAM_MILITIA && otherTeam==TEAM_IMC)
}
::R1GrappleAim_Stop <- function()
{
    R1GrappleAim.enabled=false
    R1GrappleAim.generation++
    if(IsValid(R1GrappleAim.screen))R1GrappleAim.screen.Destroy()
    if("xScreen" in R1GrappleAim && IsValid(R1GrappleAim.xScreen))R1GrappleAim.xScreen.Destroy()
    R1GrappleAim.screen=null
    R1GrappleAim.circle=null
    R1GrappleAim.cockpit=null
    R1GrappleAim.xScreen=null
    R1GrappleAim.xIcon=null
    R1GrappleAim.enemyInSight=false
    R1GrappleAim.enemyTarget=null
}
::R1GrappleAim_Run <- function(generation)
{
    try
    {
        R1GrappleAim.stage="precache"
        PrecacheHUDMaterial("HUD/crosshairs/titan_shotgun_circle_single")
        PrecacheHUDMaterial("HUD/crosshairs/hit_indicator")
        R1GrappleAim.stage="waiting for pilot"
        while(R1GrappleAim.enabled && R1GrappleAim.generation==generation)
        {
            local p=GetLocalClientPlayer()
            if(IsValid(p) && IsAlive(p) && !p.IsTitan() && IsValid(p.GetCockpit()))
            {
                local cockpit=p.GetCockpit()
                if(!IsValid(R1GrappleAim.screen) || R1GrappleAim.cockpit!=cockpit)
                {
                    if(IsValid(R1GrappleAim.screen))R1GrappleAim.screen.Destroy()
                    if(IsValid(R1GrappleAim.xScreen))R1GrappleAim.xScreen.Destroy()
                    R1GrappleAim.stage="create screen"
                    R1GrappleAim.screen=Create_PilotVGUI("vgui_icon",cockpit,p,3.0,3.0)
                    R1GrappleAim.cockpit=cockpit
                    R1GrappleAim.stage="get circle"
                    R1GrappleAim.circle=HudElement("CenterIcon",R1GrappleAim.screen.GetPanel())
                    R1GrappleAim.circle.SetImage("HUD/crosshairs/titan_shotgun_circle_single")
                    R1GrappleAim.xScreen=Create_PilotVGUI("vgui_icon",cockpit,p,30.0,30.0)
                    R1GrappleAim.xIcon=HudElement("CenterIcon",R1GrappleAim.xScreen.GetPanel())
                    R1GrappleAim.xIcon.SetImage("HUD/crosshairs/hit_indicator")
                    R1GrappleAim.xIcon.SetColor(255,255,255,255)
                    R1GrappleAim.xBaseWidth <- R1GrappleAim.xIcon.GetWidth().tofloat()
                    R1GrappleAim.xBaseHeight <- R1GrappleAim.xIcon.GetHeight().tofloat()
                    R1GrappleAim.xBasePos <- R1GrappleAim.xIcon.GetPos()
                    R1GrappleAim.xScale=1.0
                }
                local eye=p.EyePosition()
                local forward=p.GetViewVector()
                local connected=false
                local attached=false
                local phase="idle"
                local phaseTime=-1.0
                foreach(target in GetClientEntArrayBySignifier("info_target"))
                {
                    if(target.GetOwner()!=p)continue
                    local name=target.GetName()
                    if(name.find("r1grapple_active")==0)
                    {
                        connected=true
                        if(name.find("r1grapple_active_attached")==0)attached=true
                    }
                    if(name.find("r1grapple_anim:")==0)
                    {
                        local fields=split(name,":")
                        if(fields.len()>=6 && fields[2].tofloat()>=phaseTime)
                        {
                            phaseTime=fields[2].tofloat()
                            phase=fields[1]
                        }
                    }
                }
                // Use the cable's coherent phase record first. In particular,
                // a release record wins over an older replicated active marker.
                if(phaseTime>=0)
                {
                    connected=phase=="hit" || phase=="attached"
                    attached=phase=="attached"
                }
                else phase=attached ? "attached" : (connected ? "hit" : "idle")
                R1GrappleAim.connected <- connected
                R1GrappleAim.attached <- attached
                R1GrappleAim.phase=phase
                local now=Time()
                local dt=max(0.0,min(0.1,now-R1GrappleAim.lastTime))
                R1GrappleAim.lastTime=now
                // Deployed retains its accepted size; clamp draws inward over .10s.
                local targetScale=attached ? 0.65 : 1.0
                if(!attached)R1GrappleAim.xScale=1.0
                else R1GrappleAim.xScale=max(targetScale,R1GrappleAim.xScale-dt*3.5)
                local width=R1GrappleAim.xBaseWidth*R1GrappleAim.xScale
                local height=R1GrappleAim.xBaseHeight*R1GrappleAim.xScale
                R1GrappleAim.xIcon.SetSize(width,height)
                R1GrappleAim.xIcon.SetPos(R1GrappleAim.xBasePos[0]+(R1GrappleAim.xBaseWidth-width)*0.5,R1GrappleAim.xBasePos[1]+(R1GrappleAim.xBaseHeight-height)*0.5)
                local surfaceMask=TRACE_MASK_SHOT & ~(CONTENTS_MONSTER | CONTENTS_HITBOX | CONTENTS_PLAYERCLIP | CONTENTS_MONSTERCLIP)
                local hit=TraceLine(eye,eye+forward*1650.0,p,surfaceMask,TRACE_COLLISION_GROUP_NONE)
                local valid=hit.fraction<1.0 && !hit.startSolid && !hit.hitSky && (hit.endPos-eye).Length()>=33.0
                R1GrappleAim.validTarget=valid
                // Enemy targeting needs character hitboxes, independently of
                // the grapple surface trace that deliberately ignores them.
                // The first shot obstruction wins: never mark through a wall.
                local camera=p.CameraPosition()
                local sight=TraceLine(camera,camera+p.CameraAngles().AnglesToForward()*32768.0,p,TRACE_MASK_SHOT,TRACE_COLLISION_GROUP_NONE)
                local enemy=!sight.startSolid && R1GrappleAim_IsEnemy(p,sight.hitEnt)
                R1GrappleAim.enemyInSight=enemy
                R1GrappleAim.enemyTarget=enemy ? sight.hitEnt : null
                R1GrappleAim.circle.SetColor(enemy ? 255 : (valid ? 50 : 255),enemy ? 45 : (valid ? 240 : 255),enemy ? 45 : (valid ? 70 : 255),255)
                R1GrappleAim.xIcon.SetColor(255,enemy ? 45 : 255,enemy ? 45 : 255,255)
                if(connected)
                {
                    R1GrappleAim.circle.Hide()
                    R1GrappleAim.xIcon.Show()
                }
                else
                {
                    R1GrappleAim.circle.Show()
                    R1GrappleAim.xIcon.Hide()
                }
                R1GrappleAim.stage="running"
            }
            else
            {
                R1GrappleAim.connected=false
                R1GrappleAim.attached=false
                R1GrappleAim.phase="idle"
                R1GrappleAim.enemyInSight=false
                R1GrappleAim.enemyTarget=null
                if(R1GrappleAim.circle!=null)R1GrappleAim.circle.Hide()
                if(R1GrappleAim.xIcon!=null)R1GrappleAim.xIcon.Hide()
            }
            wait 0.016
        }
    }
    catch(error)
    {
        R1GrappleAim.error=error.tostring()
        R1GrappleAim.enabled=false
        if(IsValid(R1GrappleAim.screen))R1GrappleAim.screen.Destroy()
        if(IsValid(R1GrappleAim.xScreen))R1GrappleAim.xScreen.Destroy()
        R1GrappleAim.screen=null
        R1GrappleAim.circle=null
        printt("[R1GrappleAim] Disabled after error:",R1GrappleAim.stage,error)
    }
}
thread R1GrappleAim_Run(R1GrappleAim.generation)

