// R2-referenced world grapple for R1Delta. Server-authoritative prototype.
if ( !( "R1Grapple" in getroottable() ) )
{
    ::R1Grapple <- {
        enabled = false, generation = 0, commandsRegistered = false,
        maxRange = 1100.0, shootSpeed = 3000.0,
        initialImpulse = 350.0, groundImpulse = 50.0,
        pullDelay = 0.2, pullAccel = 1000.0,
        rampMin = 50.0, rampMax = 800.0, rampTime = 1.5,
        tangentDecel = 425.0, airAccel = 650.0, airSpeedMax = 420.0,
        gravityMin = 0.25, gravityMax = 0.7,
        detachDistance = 33.0, lowSpeed = 250.0,
        lowSpeedGroundTime = 0.7, lowSpeedAirTime = 1.5,
        impactBoost = 300.0,
        // Prototype simplifications, not a recreation of R2's charge meter.
        cooldown = 3.0, maxDuration = 4.0
    }
}

// v0.5 slingshot prototype. R2 reference motor/launch values, custom tether
// constraint and swing steering. This is not native R2 prediction or physics.
// Refresh on hot reload too; increasing pull strength alone was insufficient.
R1Grapple.initialImpulse = 350.0
R1Grapple.groundImpulse = 200.0
R1Grapple.pullDelay = 0.45
R1Grapple.maxRange = 1650.0
R1Grapple.launchRamp <- 0.35
R1Grapple.releaseReturnTime <- 0.16
R1Grapple.pullAccel = 1000.0
R1Grapple.rampMin = 50.0
R1Grapple.rampMax = 800.0
R1Grapple.rampTime = 1.5
// Preserve swing momentum instead of braking the entire tangent every frame.
R1Grapple.tangentDecel = 0.0
R1Grapple.airAccel = 650.0
R1Grapple.airSpeedMax = 420.0
R1Grapple.maxDuration = 10.0
R1Grapple.constraintTime <- 0.15
R1Grapple.detachAwaySpeed <- 500.0
R1Grapple.cableWidth <- 0.55
R1Grapple.visualSegments <- 32
R1Grapple.missReturnTime <- 0.30
// Unlimited retries for the user's local testing profile, including misses.
R1Grapple.cooldown = 0.0

// v0.6: bounded brush-corner routing. This is a custom R1 implementation,
// not R2's native rope solver. If no clear route is found, detach safely.
R1Grapple.wrapEnabled <- true
R1Grapple.wrapMaxBends <- 4
R1Grapple.wrapClearance <- 0.4
R1Grapple.wrapSearchRadius <- 256.0
// Use physical map/prop surfaces, not invisible player/NPC clip volumes.
// Characters remain outside this static-anchor implementation.
R1Grapple.surfaceMask <- TRACE_MASK_SHOT & ~(CONTENTS_MONSTER | CONTENTS_HITBOX | CONTENTS_PLAYERCLIP | CONTENTS_MONSTERCLIP)

::R1Grapple_CableOrigin <- function( player )
{
    // Camera-relative bottom-center outlet; recomputed as the pilot moves.
    // The eye-based targeting and physics tether remain independent.
    local f=player.GetViewVector()
    local r=Vector(f.y,-f.x,0)
    if(r.Length()<0.001)r=Vector(0,-1,0)
    else r*=1.0/r.Length()
    local u=Vector(r.y*f.z-r.z*f.y,r.z*f.x-r.x*f.z,r.x*f.y-r.y*f.x)
    return player.EyePosition()+f*32.0-u*32.0

}

::R1Grapple_State <- function( player )
{
    if ( !( "r1Grapple" in player.s ) )
    {
        player.s.r1Grapple <- {
            active = false, held = false, phase = "idle",
            anchor = Vector(0,0,0), launch = Vector(0,0,0),
            started = 0.0, attachAt = 0.0, pullAt = 0.0,
            readyAt = 0.0, lowSince = -1.0,
            ropeStart = null, ropeEnd = null,
            initialDistance = 0.0, attachCount = 0,
            ropeLength = 0.0, closestDistance = 0.0,
            lastReason = "idle"
        }
    }
    // Migrate an existing player state when reloading the previous prototype.
    if (!("ropeLength" in player.s.r1Grapple)) player.s.r1Grapple.ropeLength <- 0.0
    if (!("closestDistance" in player.s.r1Grapple)) player.s.r1Grapple.closestDistance <- 0.0
    if (!("wrapPoints" in player.s.r1Grapple)) player.s.r1Grapple.wrapPoints <- []
    if (!("wrapRopes" in player.s.r1Grapple)) player.s.r1Grapple.wrapRopes <- []
    if (!("wrapAdds" in player.s.r1Grapple)) player.s.r1Grapple.wrapAdds <- 0
    if (!("wrapRemoves" in player.s.r1Grapple)) player.s.r1Grapple.wrapRemoves <- 0
    if (!("lastClearEye" in player.s.r1Grapple)) player.s.r1Grapple.lastClearEye <- null
    if (!("visualNodes" in player.s.r1Grapple)) player.s.r1Grapple.visualNodes <- []
    if (!("visualOrigin" in player.s.r1Grapple)) player.s.r1Grapple.visualOrigin <- null
    if (!("missActive" in player.s.r1Grapple)) player.s.r1Grapple.missActive <- false
    if (!("missEnd" in player.s.r1Grapple)) player.s.r1Grapple.missEnd <- Vector(0,0,0)
    if (!("missOutTime" in player.s.r1Grapple)) player.s.r1Grapple.missOutTime <- 0.0
    if (!("weaponHolstered" in player.s.r1Grapple)) player.s.r1Grapple.weaponHolstered <- false
    local g=player.s.r1Grapple
    if(!("cameraRope" in g))g.cameraRope <- null
    if(!("hookNodes" in g))g.hookNodes <- []
    if(!("hookNormal" in g))g.hookNormal <- Vector(0,0,1)
    if(!("connectionMarker" in g))g.connectionMarker <- null
    if(!("returnDuration" in g))g.returnDuration <- R1Grapple.missReturnTime
    if(!("releaseMode" in g))g.releaseMode <- false
    if(!("launchRemaining" in g))g.launchRemaining <- 0.0
    return player.s.r1Grapple
}

::R1Grapple_IsActive <- function( player )
{
    return R1Grapple.enabled && ( "r1Grapple" in player.s ) && player.s.r1Grapple.active
}

::R1Grapple_Dot <- function( a, b )
{
    return a.x*b.x + a.y*b.y + a.z*b.z
}

::R1Grapple_DestroyRope <- function( s, preserveClamp = false )
{
    R1Grapple_ClearFlightState(s)
    if(!preserveClamp && "clampJoint" in s)s.clampJoint=null
    // Remove the world rope before its camera endpoint disappears.
    if("cameraRope" in s && IsValid(s.cameraRope))s.cameraRope.Kill()
    if("cameraRope" in s)s.cameraRope=null
    if ("visualNodes" in s && s.visualNodes.len()>0)
    {
        foreach(node in s.visualNodes)if(IsValid(node))node.Kill()
        s.visualNodes.clear()
    }
    else
    {
        if ( IsValid( s.ropeStart ) ) s.ropeStart.Kill()
        if ( IsValid( s.ropeEnd ) ) s.ropeEnd.Kill()
    }
    s.ropeStart = null
    s.ropeEnd = null
    if("hookNodes" in s){foreach(n in s.hookNodes)if(IsValid(n))n.Kill();s.hookNodes.clear()}
    if("connectionMarker" in s && IsValid(s.connectionMarker))s.connectionMarker.Kill()
    if("connectionMarker" in s)s.connectionMarker=null
    if("visualOrigin" in s && IsValid(s.visualOrigin))s.visualOrigin.Kill()
    if("visualOrigin" in s)s.visualOrigin=null
    if ("wrapRopes" in s)
    {
        foreach (rope in s.wrapRopes) if (IsValid(rope)) rope.Kill()
        s.wrapRopes.clear()
    }
}

::R1Grapple_HideWeapon <- function(player,s)
{
    if(!s.weaponHolstered)
    {
        player.HolsterWeapon()
        s.weaponHolstered=true
    }
}

::R1Grapple_RestoreWeapon <- function(player,s)
{
    if(!s.weaponHolstered)return
    s.weaponHolstered=false
    // Let death, Titan and traversal transitions manage their own weapons.
    if(IsValid(player) && IsAlive(player) && !player.IsTitan() && !player.IsMantling() && !player.IsZiplining())
        player.DeployWeapon()
}

::R1Grapple_Detach <- function( player, reason )
{
    local s = R1Grapple_State( player )
    if ( !s.active && !s.missActive )
    {
        R1Grapple_DestroyRope(s)
        R1Grapple_RestoreWeapon(player,s)
        return
    }
    // Cosmetic return relinquishes physics immediately, including on Shift.
    // A completed attachment earns one native air-jump reset on detach. Misses
    // and repeated cosmetic-return cleanup cannot replenish it again.
    if(s.active && (s.phase=="clamped" || s.phase=="pulling") && IsAlive(player) && !player.IsTitan() && !player.IsOnGround() && !player.IsMantling() && !player.IsZiplining())
    {
        local before=player.GetVelocity()
        local power=player.GetSuitJumpPower()
        player.TouchGround()
        s.lastJumpReset <- {time=Time(),powerBefore=power,powerAfter=player.GetSuitJumpPower(),velocityBefore=before,velocityAfter=player.GetVelocity(),groundedAfter=player.IsOnGround()}
    }
    local canReturn=s.active && IsAlive(player) && !player.IsTitan() && !player.IsMantling() && !player.IsZiplining()
    canReturn=canReturn && (reason=="cancelled" || reason=="shift release" || reason=="duration" || reason=="passed anchor")
    if(canReturn && IsValid(s.ropeEnd))
    {
        s.missEnd=s.ropeEnd.GetOrigin()
        s.launch=R1Grapple_CableOrigin(player)
        s.started=Time()
        s.missOutTime=0.0
        s.returnDuration=R1Grapple.releaseReturnTime
        s.releaseMode=true
        s.active=false
        s.missActive=true
        s.phase="release_return"
        s.lastReason=reason
        if(IsValid(s.ropeStart))s.ropeStart.ClearParent()
        if(IsValid(s.connectionMarker))s.connectionMarker.Kill()
        s.connectionMarker=null
        foreach(n in s.wrapRopes)if(IsValid(n))n.Kill()
        s.wrapRopes.clear()
        s.wrapPoints.clear()
        return
    }
    s.active = false
    s.missActive = false
    s.phase = "idle"
    s.lastReason = reason
    s.readyAt = Time() + R1Grapple.cooldown
    R1Grapple_DestroyRope( s )
    s.wrapPoints.clear()
    R1Grapple_RestoreWeapon(player,s)
    // Manual release preserves all momentum for a slide landing or slingshot.
    // Only arrival applies the reference's impact vertical assist.
    if ( reason == "arrived" && IsAlive( player ) && !player.IsTitan() )
    {
        local v = player.GetVelocity()
        if ( v.z < R1Grapple.impactBoost )
            player.SetVelocity( Vector(v.x,v.y,min(v.z+R1Grapple.impactBoost,R1Grapple.impactBoost)) )
    }
    printt( "[R1Grapple] Detached:", reason )
}

// Independent pairs avoid R1 recursively drawing a shared NextKey chain.
::R1Grapple_VisualPair <- function(player,origin,width)
{
    local name=UniqueString("r1grapple_end")
    local finish=CreateEntity("keyframe_rope")
    finish.SetName(name)
    finish.SetOrigin(origin)
    finish.kv.Width=width.tostring()
    finish.kv.RopeMaterial="cable/r1pm_grapple.vmt"
    finish.kv.TextureScale="1"
    finish.kv.Slack=0
    local start=CreateEntity("move_rope")
    start.SetOrigin(origin)
    start.kv.NextKey=name
    start.kv.Width=width.tostring()
    start.kv.RopeMaterial="cable/r1pm_grapple.vmt"
    start.kv.TextureScale="1"
    start.kv.Slack=0
    start.kv.NoWind=1
    start.kv.MoveSpeed=64
    start.kv.PositionInterpolator=2
    // Two constrained endpoints per short span: native interior sag otherwise
    // creates a little kink in every span of our smooth scripted curve.
    start.kv.Type=2
    start.kv.Subdiv=8
    DispatchSpawn(start)
    DispatchSpawn(finish)
    AddOwnedEntity(player,start)
    AddOwnedEntity(player,finish)
    return [start,finish]
}

::R1Grapple_CameraConnection <- function(player,s)
{
    if(!("cameraRope" in s))s.cameraRope <- null
    if(!("visualOrigin" in s))s.visualOrigin <- null
    local vm=player.GetViewModelEntity()
    if(!IsValid(vm) || vm.LookupAttachment("CAMERA_BASE")<=0)
    {
        if(IsValid(s.cameraRope))s.cameraRope.Kill()
        s.cameraRope=null
        if(IsValid(s.visualOrigin))s.visualOrigin.Kill()
        s.visualOrigin=null
        return false
    }
    if(!IsValid(s.visualOrigin))
    {
        s.visualOrigin=CreateEntity("info_target")
        s.visualOrigin.SetName(UniqueString("r1grapple_camera_origin"))
        s.visualOrigin.SetOwner(player)
        s.visualOrigin.kv.spawnflags=1
        DispatchSpawn(s.visualOrigin)
        AddOwnedEntity(player,s.visualOrigin)
    }
    if(s.visualOrigin.GetParent()!=vm)
    {
        s.visualOrigin.SetParent(vm,"CAMERA_BASE",false,0.0)
        s.visualOrigin.SetLocalOrigin(Vector(32,0,-32))
        s.visualOrigin.SetLocalAngles(Vector(0,0,0))
    }
    if(!IsValid(s.cameraRope))
    {
        // Render entity stays UNPARENTED. Only its generic NextKey endpoint
        // follows the predicted first-person camera. Never parent the renderer.
        s.cameraRope=CreateEntity("move_rope")
        s.cameraRope.SetName(UniqueString("r1grapple_camera_span"))
        s.cameraRope.SetOrigin(R1Grapple_CableOrigin(player))
        s.cameraRope.kv.NextKey=s.visualOrigin.GetName()
        s.cameraRope.kv.Width=R1Grapple.cableWidth.tostring()
        s.cameraRope.kv.TextureScale="1"
        s.cameraRope.kv.RopeMaterial="cable/r1pm_grapple.vmt"
        s.cameraRope.kv.Slack=0
        s.cameraRope.kv.NoWind=1
        s.cameraRope.kv.MoveSpeed=64
        s.cameraRope.kv.PositionInterpolator=2
        s.cameraRope.kv.Type=2
        s.cameraRope.kv.Subdiv=8
        DispatchSpawn(s.cameraRope)
        AddOwnedEntity(player,s.cameraRope)
    }
    return true
}

::R1Grapple_CreateRope <- function(player,s)
{
    if(!("visualNodes" in s))s.visualNodes <- []
    if(!("hookNodes" in s))s.hookNodes <- []
    for(local i=0;i<R1Grapple.visualSegments;i++)
        s.visualNodes.extend(R1Grapple_VisualPair(player,s.launch,R1Grapple.cableWidth))
    // Shaft plus three two-piece claws; procedural R1 geometry, not an R2 mesh.
    for(local i=0;i<7;i++)s.hookNodes.extend(R1Grapple_VisualPair(player,s.launch,1.25))
    s.ropeStart=s.visualNodes[0]
    s.ropeEnd=s.visualNodes.top()
    if(s.active && !IsValid(s.connectionMarker))
        R1Grapple_CreateConnectionMarker(player,s)

    // Each extra bend gets a real rendered rope segment to the previous pivot.
    local previous = R1Grapple_HookBase(player,s,s.anchor,false)
    foreach (point in s.wrapPoints)
    {
        local segmentName = UniqueString("r1grapple_bend")
        local finish = CreateEntity("keyframe_rope")
        s.wrapRopes.append(finish)
        finish.SetName(segmentName)
        finish.SetOrigin(previous)
        finish.kv.Width = R1Grapple.cableWidth.tostring()
        finish.kv.RopeMaterial = "cable/r1pm_grapple.vmt"
        finish.kv.Slack = 0
        DispatchSpawn(finish)
        AddOwnedEntity(player,finish)
        local start = CreateEntity("move_rope")
        s.wrapRopes.append(start)
        start.SetOrigin(point)
        start.kv.NextKey = segmentName
        start.kv.Width = R1Grapple.cableWidth.tostring()
        start.kv.RopeMaterial = "cable/r1pm_grapple.vmt"
        start.kv.Slack = 0
        start.kv.Type = 2
        start.kv.NoWind = 1
        start.kv.PositionInterpolator = 2
        start.kv.Subdiv = 4
        DispatchSpawn(start)
        AddOwnedEntity(player,start)
        previous = point
    }
}

::R1Grapple_AnimateNativeCable <- function(player,s,endpoint,now,loose)
{
    if(s.visualNodes.len()<2)return
    local cameraConnected=R1Grapple_CameraConnection(player,s)
    local hookTip=loose ? endpoint : s.anchor
    // The visual cable terminates at the swivel eyelet, not through the claws.
    if(loose || s.wrapPoints.len()==0)endpoint=R1Grapple_HookBase(player,s,hookTip,loose)
    if(s.active && IsValid(s.connectionMarker))
    {
        local tag=loose ? "r1grapple_active_deployed" : "r1grapple_active_attached"
        if(s.connectionMarker.GetName().find(tag)!=0)s.connectionMarker.SetName(UniqueString(tag))
    }
    local origin=R1Grapple_CableOrigin(player)
    local forward=player.GetViewVector()
    local right=Vector(forward.y,-forward.x,0)
    if(right.Length()<0.001)right=Vector(0,-1,0)
    else right*=1.0/right.Length()
    local up=Vector(right.y*forward.z-right.z*forward.y,right.z*forward.x-right.x*forward.z,right.x*forward.y-right.y*forward.x)
    local distance=(endpoint-origin).Length()
    local age=now-s.started
    // A forward lead keeps the near cable in view even while looking away
    // from the anchor. Visual bow/waves never alter the physics rope length.
    local lead=min(80.0,max(12.0,distance*0.20))
    local control1=origin+forward*lead+right*4.0-up*3.0
    local control2=origin+(endpoint-origin)*0.65
    local amplitude=loose ? min(36.0,distance*0.07) : 0.0
    local points=[]
    for(local i=0;i<=R1Grapple.visualSegments;i++)
    {
        local t=i.tofloat()/R1Grapple.visualSegments
        // More samples near the camera, where angular joints are most visible.
        local u=loose ? pow(t,1.5) : t
        local a=1.0-u
        local point=origin*(a*a*a)+control1*(3.0*a*a*u)+control2*(3.0*a*u*u)+endpoint*(u*u*u)
        local envelope=sin(3.14159265*u)
        point+=right*(envelope*amplitude*sin(age*7.0-u*4.0))
        point+=up*(envelope*amplitude*0.40*cos(age*6.0-u*3.5))
        if(!loose)point=origin+(endpoint-origin)*u // taut: no artificial bow or waves
        points.append(point)
    }
    // Straight attached line uses one world rope from the existing hook eyelet
    // (or nearest bend) to the camera endpoint. Loose animation retains its far
    // Bezier/waves, with a longer near span so the visible entry follows camera.
    local join=cameraConnected ? (loose ? min(12,R1Grapple.visualSegments) : R1Grapple.visualSegments) : 0
    for(local i=0;i<R1Grapple.visualSegments;i++)
    {
        local a=i<join ? points[join] : points[i]
        local b=i<join ? points[join] : points[i+1]
        if(IsValid(s.visualNodes[i*2]))s.visualNodes[i*2].SetOrigin(a)
        if(IsValid(s.visualNodes[i*2+1]))s.visualNodes[i*2+1].SetOrigin(b)
    }
    if(cameraConnected)s.cameraRope.SetAbsOrigin(points[join])
    R1Grapple_AnimateHook(player,s,hookTip,now,loose)
}

::R1Grapple_ClampJoint <- function(s,target,tip)
{
    // Surface-attached geometry must not chase the player's simulation origin.
    // Capture the accepted rear joint once at contact. The native camera span
    // still follows its separate predicted endpoint, below the viewport.
    if(!("clampJoint" in s) || s.clampJoint==null ||
       (s.clampJointTip-tip).Length()>0.1 ||
       (s.clampJointNormal-s.hookNormal).Length()>0.001)
    {
        s.clampJoint <- target
        s.clampJointTip <- tip
        s.clampJointNormal <- s.hookNormal
    }
    return s.clampJoint
}

::R1Grapple_HookBase <- function(player,s,tip,loose)
{
    if(loose)
    {
        local axis=tip-R1Grapple_CableOrigin(player)
        local length=axis.Length()
        if(length<0.001)return tip
        return tip-axis*(min(10.0,length)/length)
    }
    // Compute the initial rear joint with the accepted surface clearance.
    // Capture only at/after contact, not the preliminary CreateRope call.
    // Fixed claws retain their existing surface-normal frame and animation.
    local incoming=s.wrapPoints.len()>0 ? s.wrapPoints[0] : R1Grapple_CableOrigin(player)
    local direction=incoming-tip
    if(direction.Length()<0.001)direction=s.hookNormal
    else direction*=1.0/direction.Length()
    local normal=s.hookNormal
    local outward=R1Grapple_Dot(direction,normal)
    if(outward<0.25)direction+=normal*(0.25-outward)
    direction*=1.0/direction.Length()
    local joint=tip+direction*10.0
    if(s.phase=="clamped" || s.phase=="pulling")
        return R1Grapple_ClampJoint(s,joint,tip)
    return joint
}

::R1Grapple_AnimateHook <- function(player,s,tip,now,loose)
{
    if(s.hookNodes.len()!=14)return
    local base=R1Grapple_HookBase(player,s,tip,loose)
    local axis=loose ? tip-base : s.hookNormal*(-1.0)
    if(axis.Length()<0.001)axis=player.GetViewVector()
    else axis*=1.0/axis.Length()
    local side=Vector(axis.y,-axis.x,0)
    if(side.Length()<0.001)side=Vector(0,1,0)
    else side*=1.0/side.Length()
    local up=Vector(side.y*axis.z-side.z*axis.y,side.z*axis.x-side.x*axis.z,side.x*axis.y-side.y*axis.x)
    local hub=loose ? tip : tip+s.hookNormal*3.0
    local points=[base,hub]
    local close=loose ? 0.0 : min(1.0,max(0.0,(now-s.attachAt)/0.12))
    for(local arm=0;arm<3;arm++)
    {
        local angle=arm*2.0943951
        local radial=side*cos(angle)+up*sin(angle)
        local root=loose ? base+axis*4.0 : hub+radial*0.75
        local elbow=tip-axis*(2.0+close*2.0)+radial*(6.0-close*2.0)
        local claw=tip+axis*(close*0.75)+radial*(5.0-close*1.5)
        points.extend([root,elbow,elbow,claw])
    }
    for(local i=0;i<14;i++)if(IsValid(s.hookNodes[i]))s.hookNodes[i].SetAbsOrigin(points[i])
    if(!loose && s.wrapRopes.len()>0 && IsValid(s.wrapRopes[0]))s.wrapRopes[0].SetAbsOrigin(base)
}

::R1Grapple_CreateConnectionMarker <- function(player,s)
{
    s.connectionMarker=CreateEntity("info_target")
    s.connectionMarker.SetName(UniqueString((s.phase=="clamped" || s.phase=="pulling") ? "r1grapple_active_attached" : "r1grapple_active_deployed"))
    s.connectionMarker.SetOwner(player)
    s.connectionMarker.kv.spawnflags=1
    s.connectionMarker.SetOrigin(player.EyePosition())
    DispatchSpawn(s.connectionMarker)
    AddOwnedEntity(player,s.connectionMarker)
}

::R1Grapple_AttachCue <- function(player,s)
{
    s.phase="clamped"
    s.attachCount++
    s.pullAt=Time()+R1Grapple.pullDelay
    s.launchRemaining=R1Grapple.initialImpulse
    if(!IsValid(s.connectionMarker))R1Grapple_CreateConnectionMarker(player,s)
    try{PlayFX("P_impact_rodeo_damage",s.anchor,s.hookNormal.GetAngles())}
    catch(error){s.lastCueError <- error.tostring()}
    printt("[R1Grapple] Clamped: reaction pause",R1Grapple.pullDelay)
}

::R1Grapple_StartMiss <- function(player,s,endpoint)
{
    R1Grapple_DestroyRope(s)
    s.wrapPoints.clear()
    s.active=false // Never give a visual-only miss ownership of velocity.
    s.missActive=true
    s.releaseMode=false
    s.returnDuration=R1Grapple.missReturnTime
    s.phase="miss_out"
    s.lastReason="miss"
    s.lastError <- null
    s.started=Time()
    s.launch=R1Grapple_CableOrigin(player)
    s.missEnd=endpoint
    s.missOutTime=max(0.12,(endpoint-s.launch).Length()/R1Grapple.shootSpeed)
    R1Grapple_HideWeapon(player,s)
    R1Grapple_CreateRope(player,s)
}

::R1Grapple_UpdateMiss <- function(player,s,now)
{
    if(!IsAlive(player) || player.IsTitan() || player.IsMantling() || player.IsZiplining())
    {
        R1Grapple_Detach(player,"miss player state")
        return
    }
    local elapsed=now-s.started
    local endpoint=s.missEnd
    if(elapsed<s.missOutTime)
    {
        local u=min(1.0,elapsed/s.missOutTime)
        local eased=1.0-(1.0-u)*(1.0-u)
        endpoint=s.launch+(s.missEnd-s.launch)*eased
        s.phase="miss_out"
    }
    else
    {
        local u=(elapsed-s.missOutTime)/s.returnDuration
        if(u>=1.0)
        {
            R1Grapple_Detach(player,s.releaseMode ? "release retracted" : "miss retracted")
            return
        }
        local eased=u*u*(3.0-2.0*u)
        endpoint=s.missEnd+(R1Grapple_CableOrigin(player)-s.missEnd)*eased
        s.phase=s.releaseMode ? "release_return" : "miss_return"
    }
    R1Grapple_AnimateCable(player,s,endpoint,now,true)
}

::R1Grapple_ClearSegment <- function( player, start, finish )
{
    local length = (finish-start).Length()
    if (length < 0.001) return true
    // Sweep the cable radius, not the pilot hull. A 24u waypoint clearance
    // floated corners far from the surface; a line with 2u penetration also
    // allowed the cable to cut through small edges.
    local r=R1Grapple.wrapClearance
    local hit=TraceHull(start,finish,Vector(-r,-r,-r),Vector(r,r,r),player,R1Grapple.surfaceMask,TRACE_COLLISION_GROUP_NONE)
    return !hit.startSolid && hit.fraction*length >= length-0.02
}

::R1Grapple_TightenBend <- function(player,eye,target,point)
{
    // Shorten a valid two-leg path against the collision surface. Coarse
    // search is only a seed: never ship its 16/32/64/128/256u grid as the bend.
    local best=point
    local bestLength=(best-eye).Length()+(target-best).Length()
    for(local pass=0;pass<6;pass++)
    {
        local old=best
        local a=eye-best;local b=target-best
        if(a.Length()<0.01 || b.Length()<0.01)break
        local bisector=a*(1.0/a.Length())+b*(1.0/b.Length())
        local destinations=[eye,target]
        if(bisector.Length()>0.001)
            destinations.insert(0,best+bisector*(min(a.Length(),b.Length())/bisector.Length()))
        foreach(destination in destinations)
        {
            local clear=best;local blocked=destination
            for(local i=0;i<16;i++)
            {
                local candidate=(clear+blocked)*0.5
                if(R1Grapple_ClearSegment(player,eye,candidate) && R1Grapple_ClearSegment(player,candidate,target))clear=candidate
                else blocked=candidate
            }
            local length=(clear-eye).Length()+(target-clear).Length()
            if(length<bestLength-0.0001){best=clear;bestLength=length}
        }
        if((best-old).Length()<0.01)break
    }
    return best
}

::R1Grapple_FindBend <- function( player, eye, target, hit, seed=null )
{
    // Search in the blocking face's plane, offset into free space. Both legs
    // MUST pass brush traces. Never invent a pivot behind/inside the obstacle.
    local normal = hit.surfaceNormal
    local normalLength = normal.Length()
    if (normalLength < 0.001 || hit.startSolid || hit.hitSky) return null
    normal *= 1.0/normalLength
    local u = Vector(-normal.y,normal.x,0)
    if (u.Length() < 0.001) u = Vector(1,0,0)
    u *= 1.0/u.Length()
    local v = Vector(normal.y*u.z-normal.z*u.y,normal.z*u.x-normal.x*u.z,normal.x*u.y-normal.y*u.x)
    local center = hit.endPos+normal*(R1Grapple.wrapClearance*1.8+0.03)
    local best = null
    local bestLength = 1000000.0
    // Movement gives us a previously clear rope leg. Use that as a validated
    // seed, then move toward the blocking face while keeping BOTH legs clear.
    // This catches small corner crossings that a radial search can miss.
    if (seed!=null && (seed-eye).Length()>1.0 &&
        R1Grapple_ClearSegment(player,eye,seed) && R1Grapple_ClearSegment(player,seed,target))
    {
        local clear=seed
        local blocked=center
        for(local iteration=0;iteration<8;iteration++)
        {
            local candidate=(clear+blocked)*0.5
            if(R1Grapple_ClearSegment(player,eye,candidate) && R1Grapple_ClearSegment(player,candidate,target))
                clear=candidate
            else blocked=candidate
        }
        best=clear
        bestLength=(clear-eye).Length()+(target-clear).Length()
    }
    // R1 Vector instances support scalar multiplication, not unary negation.
    local negativeU=u*(-1.0)
    local negativeV=v*(-1.0)
    local directions = [u,negativeU,v,negativeV,(u+v)*0.70710678,(u-v)*0.70710678,(negativeU+v)*0.70710678,(negativeU-v)*0.70710678]
    for (local radius=16.0; radius<=R1Grapple.wrapSearchRadius; radius*=2.0)
    {
        foreach (axis in directions)
        {
            local candidate = center+axis*radius
            if ((candidate-eye).Length() < R1Grapple.wrapClearance) continue
            if (!R1Grapple_ClearSegment(player,eye,candidate)) continue
            if (!R1Grapple_ClearSegment(player,candidate,target)) continue
            local length = (candidate-eye).Length()+(target-candidate).Length()
            if (length < bestLength) { best=candidate; bestLength=length }
        }
    }
    return best==null ? null : R1Grapple_TightenBend(player,eye,target,best)
}

::R1Grapple_Path <- function( player, s, eye )
{
    local changed = false
    // Unwind from the player end only, once the previous leg is visible.
    while (s.wrapPoints.len() > 0)
    {
        local previous = s.wrapPoints.len()>1 ? s.wrapPoints[s.wrapPoints.len()-2] : s.anchor
        if (!R1Grapple_ClearSegment(player,eye,previous)) break
        s.wrapPoints.pop()
        s.wrapRemoves++
        changed=true
    }
    local target = s.wrapPoints.len()>0 ? s.wrapPoints.top() : s.anchor
    local length = (target-eye).Length()
    local r=R1Grapple.wrapClearance
    local hit=TraceHull(eye,target,Vector(-r,-r,-r),Vector(r,r,r),player,R1Grapple.surfaceMask,TRACE_COLLISION_GROUP_NONE)
    if (hit.startSolid) return null
    if (hit.fraction*length < length-0.02)
    {
        if (!R1Grapple.wrapEnabled || s.wrapPoints.len()>=R1Grapple.wrapMaxBends) return null
        local bend = R1Grapple_FindBend(player,eye,target,hit,s.lastClearEye)
        if (bend==null) return null
        s.wrapPoints.append(bend)
        s.wrapAdds++
        target=bend
        changed=true
    }
    // Every fixed tail segment remains collision tested, not just the first.
    local tailLength = 0.0
    local previous = s.anchor
    foreach (point in s.wrapPoints)
    {
        if (!R1Grapple_ClearSegment(player,point,previous)) return null
        tailLength+=(point-previous).Length()
        previous=point
    }
    local distance=(target-eye).Length()+tailLength
    if (changed)
    {
        // Rebuilding corner spans does not detach the surface-mounted hook.
        R1Grapple_DestroyRope(s,true)
        R1Grapple_CreateRope(player,s)
        // Topology changes must not be mistaken for passing the anchor.
        s.closestDistance=distance
    }
    s.lastClearEye=eye
    return {target=target,distance=distance,tailLength=tailLength}
}

::R1Grapple_Fire <- function( player )
{
    local s = R1Grapple_State( player )
    if ( !R1Grapple.enabled || s.active || s.missActive || !IsAlive(player) || player.IsTitan() || player.IsZiplining() || player.IsMantling() )
        return
    if ( Time() < s.readyAt )
    {
        printt( "[R1Grapple] Recharging:", s.readyAt-Time(), "seconds" )
        return
    }
    local eye = player.EyePosition()
    local forward = player.GetViewVector()
    local hit = TraceLine( eye, eye + forward*R1Grapple.maxRange, player, R1Grapple.surfaceMask, TRACE_COLLISION_GROUP_NONE )
    if ( hit.fraction >= 1.0 || hit.startSolid || hit.hitSky || (hit.endPos-eye).Length() < R1Grapple.detachDistance )
    {
        local visualDistance=R1Grapple.maxRange
        if(hit.fraction<1.0 && !hit.hitSky)visualDistance=max(8.0,(hit.endPos-eye).Length())
        R1Grapple_StartMiss(player,s,eye+forward*visualDistance)
        return
    }
    s.launch = R1Grapple_CableOrigin(player)
    s.anchor = hit.endPos + hit.surfaceNormal*1.0
    s.hookNormal=hit.surfaceNormal
    s.initialDistance = (s.anchor-eye).Length()
    s.ropeLength = s.initialDistance
    s.wrapPoints.clear()
    s.lastClearEye=eye
    s.closestDistance = s.initialDistance
    s.started = Time()
    s.attachAt = s.started + s.initialDistance/R1Grapple.shootSpeed
    s.pullAt = s.attachAt + R1Grapple.pullDelay
    s.lowSince = -1.0
    s.phase = "flying"
    s.active = true
    s.lastReason = "fired"
    s.lastError <- null
    s.missActive=false
    R1Grapple_HideWeapon(player,s)
    R1Grapple_CreateRope( player, s )
    printt( "[R1Grapple] Hook fired:", s.initialDistance, "units." )
}

::R1Grapple_Down <- function( player, ... )
{
    local s = R1Grapple_State( player )
    if ( s.held )
        return true
    s.held = true
    if (s.active || s.missActive)
    {
        R1Grapple_Detach(player,"cancelled")
        return true
    }
    try { R1Grapple_Fire( player ) }
    catch ( error )
    {
        s.lastError <- error.tostring()
        R1Grapple_Detach( player, "fire error" )
        R1Grapple_DestroyRope( s )
        printt( "[R1Grapple] Fire error:", error )
    }
    return true
}

::R1Grapple_Up <- function( player, ... )
{
    local s = R1Grapple_State( player )
    s.held = false
    // The button releases, not the tether. A second press cancels attachment.
    return true
}

::R1Grapple_Cancel <- function( player )
{
    R1Grapple_State(player).held = false
    R1Grapple_Detach(player,"cancelled")
}

::R1Grapple_Update <- function( player, dt, now )
{
    local s = R1Grapple_State( player )
    if(s.missActive)
    {
        R1Grapple_UpdateMiss(player,s,now)
        return
    }
    if ( !s.active )
        return
    if ( !IsAlive(player) || player.IsTitan() || player.IsZiplining() || player.IsMantling() )
    {
        R1Grapple_Detach( player, "player state" )
        return
    }
    if ( now-s.started > R1Grapple.maxDuration )
    {
        R1Grapple_Detach( player, "duration" )
        return
    }
    local eye = player.EyePosition()
    local delta = s.anchor-eye
    local distance = delta.Length()
    if ( s.wrapPoints.len()==0 && distance < R1Grapple.detachDistance )
    {
        R1Grapple_Detach( player, "arrived" )
        return
    }
    if ( distance > R1Grapple.maxRange*1.5 )
    {
        R1Grapple_Detach( player, "range" )
        return
    }
    if ( IsValid(s.ropeStart) )
        s.ropeStart.SetOrigin( R1Grapple_CableOrigin(player) )
    if ( now < s.attachAt )
    {
        // A flying hook cannot route through a newly blocked straight path.
        if (!R1Grapple_ClearSegment(player,eye,s.anchor))
        {
            R1Grapple_Detach(player,"hook path obstructed")
            return
        }
        local endpoint=s.launch+(s.anchor-s.launch)*min(1.0,(now-s.started)/(s.attachAt-s.started))
        R1Grapple_AnimateCable(player,s,endpoint,now,true)
        return
    }
    if(s.phase=="flying")R1Grapple_AttachCue(player,s)
    if(IsValid(s.connectionMarker))s.connectionMarker.SetOrigin(eye)
    local route = R1Grapple_Path(player,s,eye)
    if (route==null)
    {
        R1Grapple_Detach(player,"no clear wrap route")
        return
    }
    distance=route.distance
    if (distance > R1Grapple.maxRange*1.5)
    {
        R1Grapple_Detach(player,"wrapped range")
        return
    }
    delta=route.target-eye
    local firstLength=delta.Length()
    if (firstLength < 0.001)
    {
        R1Grapple_Detach(player,"bend reached without clear next leg")
        return
    }
    if ( IsValid(s.ropeStart) ) s.ropeStart.SetOrigin(R1Grapple_CableOrigin(player))
    if ( IsValid(s.ropeEnd) ) s.ropeEnd.SetOrigin(route.target)
    R1Grapple_AnimateCable(player,s,route.target,now,false)
    if(now<s.pullAt)return // no grapple force, impulse or gravity compensation during the cue
    local direction = delta*(1.0/firstLength)
    local velocity = player.GetVelocity()
    if ( s.phase == "clamped" )
    {
        s.phase = "pulling"
        if ( player.IsOnGround() )
        {
            // R1 otherwise keeps the player grounded and discards the upward
            // launch velocity. Clear ground contact by a collision-tested 4u
            // separation, not by moving through the route to the anchor.
            local origin = player.GetOrigin()
            local lift = TraceHull(origin,origin+Vector(0,0,4),player.GetBoundingMins(),player.GetBoundingMaxs(),player,TRACE_MASK_PLAYERSOLID_BRUSHONLY,TRACE_COLLISION_GROUP_PLAYER)
            if ( !lift.startSolid && lift.fraction == 1.0 ) player.SetOrigin(lift.endPos)
            velocity.z = max(velocity.z,R1Grapple.groundImpulse)
        }
        player.SetVelocity( velocity )
        printt( "[R1Grapple] Attached." )
    }
    if ( now < s.pullAt )
        return

    local launch=min(s.launchRemaining,R1Grapple.initialImpulse*dt/R1Grapple.launchRamp)
    s.launchRemaining-=launch
    velocity+=direction*launch

    // Steering follows the camera in 3D; flattening it removed the upward part
    // of an aimed swing. Input adds velocity in the plane around the anchor.
    local forward = player.GetViewVector()
    local right = Vector( forward.y, -forward.x, 0 )
    local rlen = right.Length()
    if (rlen>0.001) right *= 1.0/rlen
    local wish = Vector(0,0,0)
    if ( "gameUI" in player.s && IsValid(player.s.gameUI) && "XAxis" in player.s.gameUI.s && "YAxis" in player.s.gameUI.s )
        wish = forward*GetInput_YAxis(player) + right*GetInput_XAxis(player)
    local wishLength = wish.Length()
    if ( wishLength > 1.0 ) wish *= 1.0/wishLength
    local away = max(0.0,-R1Grapple_Dot(wish,direction))
    local gravityFraction = R1Grapple.gravityMin+(R1Grapple.gravityMax-R1Grapple.gravityMin)*away
    velocity.z += GetConVarFloat("sv_gravity")*(1.0-gravityFraction)*dt

    local radial = R1Grapple_Dot(velocity,direction)
    local tangent = velocity-direction*radial
    local tangentWish = wish-direction*R1Grapple_Dot(wish,direction)
    local tangentWishLength = tangentWish.Length()
    if ( tangentWishLength > 0.001 )
    {
        tangentWish *= 1.0/tangentWishLength
        local alongWish = R1Grapple_Dot(tangent,tangentWish)
        // Do not normalize away steering angle: tiny off-axis inputs should
        // produce tiny corrections. This cap only limits added input speed.
        tangent += tangentWish*min(R1Grapple.airAccel*dt*min(1.0,tangentWishLength),max(0.0,R1Grapple.airSpeedMax-alongWish))
    }

    // Passing the anchor can release a slingshot instead of turning the pilot
    // back around. Use measured outward motion, before applying rope tension.
    s.closestDistance = min(s.closestDistance,distance)
    if (s.wrapPoints.len()==0 && distance>s.closestDistance+16.0 && radial < -R1Grapple.detachAwaySpeed)
    {
        R1Grapple_Detach(player,"passed anchor")
        return
    }

    // A winch shortens the tether while the existing tangent creates the arc.
    // The old controller always chased an inward target and had no changing
    // rope length. Take up slack without lengthening the tether on the way out.
    local ramp = min(1.0,max(0.0,(now-s.pullAt)/R1Grapple.rampTime))
    local reelSpeed = R1Grapple.rampMin+(R1Grapple.rampMax-R1Grapple.rampMin)*ramp
    s.ropeLength = max(R1Grapple.detachDistance,min(s.ropeLength,distance)-reelSpeed*dt)
    local stretch = max(0.0,distance-s.ropeLength)
    local target = stretch/max(dt,R1Grapple.constraintTime)
    // Tension acts inward only. Never replace tangent with a vector aimed at
    // the anchor, or clamp existing total speed to the winch/input speed caps.
    radial += min(R1Grapple.pullAccel*dt,max(0.0,target-radial))
    velocity = tangent+direction*radial
    player.SetVelocity( velocity )

    if ( velocity.Length() < R1Grapple.lowSpeed )
    {
        if ( s.lowSince < 0.0 ) s.lowSince = now
        local timeout = player.IsOnGround() ? R1Grapple.lowSpeedGroundTime : R1Grapple.lowSpeedAirTime
        if ( now-s.lowSince > timeout ) R1Grapple_Detach(player,"stalled")
    }
    else s.lowSince = -1.0
}

::R1Grapple_Run <- function( generation )
{
    local last = Time()
    while ( R1Grapple.enabled && R1Grapple.generation == generation )
    {
        local now = Time()
        // The previous 50ms cap halved force at 10Hz while native gravity kept
        // integrating the whole frame. Cover normal low-FPS frames; bound hitches.
        local dt = min(0.25,max(0.0,now-last))
        last = now
        foreach ( player in GetPlayerArray() )
        {
            if ( !IsValid(player) ) continue
            try { R1Grapple_Update(player,dt,now) }
            catch ( error )
            {
                R1Grapple_State(player).lastError <- error.tostring()
                R1Grapple_Detach(player,"update error")
                printt("[R1Grapple] Update error:",error)
            }
        }
        wait 0.016
    }
}

::R1Grapple_FrameRendererReady <- function(player,...)
{
    player.s.r1FrameRendererUntil <- (vargc>0 && vargv[0]=="1") ? Time()+12.0 : 0.0
    return true
}
::R1Grapple_ClearFlightState <- function(s)
{
    if("pathMarkers" in s)
    {
        foreach(e in s.pathMarkers)if(IsValid(e))e.Kill()
        s.pathMarkers.clear()
    }
    s.pathSignature <- ""
    foreach(key in ["animState","animLaunch"])
    {
        if(key in s && IsValid(s[key]))s[key].Kill()
        if(key in s)s[key]=null
    }
    if("animSignature" in s)s.animSignature=""
}
::R1Grapple_PublishFlightState <- function(player,s)
{
    local attached=s.active && (s.phase=="clamped" || s.phase=="pulling")
    local mode=attached ? "attached" : (s.missActive ? (s.releaseMode ? "release" : "miss") : "hit")
    local outTime=s.missActive ? s.missOutTime : s.attachAt-s.started
    local returnTime=s.missActive ? s.returnDuration : 0.0
    local signature="r1grapple_anim:"+mode+":"+s.started+":"+outTime+":"+returnTime+":v20"
    if(attached)signature+=":"+s.wrapPoints.len()+":"+s.wrapAdds+":"+s.wrapRemoves
    local destination=attached ? R1Grapple_HookBase(player,s,s.anchor,false) : (s.missActive ? s.missEnd : s.anchor)
    if(!("animState" in s) || !IsValid(s.animState) || !IsValid(s.animLaunch))
    {
        R1Grapple_ClearFlightState(s)
        foreach(key in ["animLaunch","animState"])
        {
            local e=CreateEntity("info_target")
            s[key] <- e
            e.SetName(key=="animLaunch" ? UniqueString("r1grapple_anim_launch") : signature)
            e.SetOwner(player)
            e.kv.spawnflags=1
            e.SetOrigin(key=="animLaunch" ? s.launch : destination)
            DispatchSpawn(e)
            AddOwnedEntity(player,e)
        }
        s.animSignature <- signature
    }
    else if(s.animSignature!=signature)
    {
        // Change a compact phase/time record, not dozens of animated vertices.
        s.animLaunch.SetOrigin(s.launch)
        s.animState.SetOrigin(destination)
        s.animState.SetName(signature)
        s.animSignature=signature
    }
    if(attached && (!("pathSignature" in s) || s.pathSignature!=signature))
    {
        if(!("pathMarkers" in s))s.pathMarkers <- []
        foreach(e in s.pathMarkers)if(IsValid(e))e.Kill()
        s.pathMarkers.clear()
        for(local i=0;i<s.wrapPoints.len();i++)
        {
            local e=CreateEntity("info_target")
            e.SetName("r1grapple_path:"+i+":"+s.started+":"+s.wrapAdds+":"+s.wrapRemoves)
            e.SetOwner(player);e.kv.spawnflags=1;e.SetOrigin(s.wrapPoints[i])
            DispatchSpawn(e);AddOwnedEntity(player,e);s.pathMarkers.append(e)
        }
        s.pathSignature <- signature
    }
}
::R1Grapple_AnimateCable <- function(player,s,endpoint,now,loose)
{
    local ready="r1FrameRendererUntil" in player.s && now<player.s.r1FrameRendererUntil
    if(ready)
    {
        s.clientCableWasActive <- true
        R1Grapple_PublishFlightState(player,s)
        // Keep authoritative state/physics intact. Collapse native loose spans
        // while client-owned world geometry renders the same phase each frame.
        if(IsValid(s.cameraRope))s.cameraRope.Kill()
        s.cameraRope=null
        local base=R1Grapple_HookBase(player,s,endpoint,true)
        foreach(e in s.visualNodes)if(IsValid(e))e.SetOrigin(base)
        if(loose)foreach(e in s.hookNodes)if(IsValid(e))e.SetAbsOrigin(base)
        else
        {
            // Hook/clamp stays native and surface-fixed. Only the cable moves
            // to client render time, like the accepted loose presentation.
            R1Grapple_AnimateHook(player,s,s.anchor,now,false)
            foreach(e in s.wrapRopes)if(IsValid(e))e.SetAbsOrigin(base)
            if(IsValid(s.connectionMarker) && s.connectionMarker.GetName().find("r1grapple_active_attached")!=0)
                s.connectionMarker.SetName(UniqueString("r1grapple_active_attached"))
        }
        return
    }
    if("clientCableWasActive" in s && s.clientCableWasActive)
    {
        // Restore fixed native tail spans after a client failure/timeout;
        // they were collapsed while the client owned cable presentation.
        local previous=R1Grapple_HookBase(player,s,s.anchor,false)
        for(local i=0;i<s.wrapPoints.len();i++)
        {
            if(i*2+1<s.wrapRopes.len())
            {
                if(IsValid(s.wrapRopes[i*2]))s.wrapRopes[i*2].SetAbsOrigin(previous)
                if(IsValid(s.wrapRopes[i*2+1]))s.wrapRopes[i*2+1].SetAbsOrigin(s.wrapPoints[i])
            }
            previous=s.wrapPoints[i]
        }
        s.clientCableWasActive=false
    }
    R1Grapple_ClearFlightState(s)
    R1Grapple_AnimateNativeCable(player,s,endpoint,now,loose)
}

::R1Grapple_Enable <- function()
{
    if(!("frameRendererCommandRegistered" in R1Grapple))R1Grapple.frameRendererCommandRegistered <- false
    if(!R1Grapple.frameRendererCommandRegistered)
    {
        AddClientCommandCallback("r1grapple_frame_renderer",R1Grapple_FrameRendererReady)
        R1Grapple.frameRendererCommandRegistered=true
    }
    if ( R1Grapple.enabled ) return
    if(!("releaseCommandRegistered" in R1Grapple))R1Grapple.releaseCommandRegistered <- false
    if(!R1Grapple.releaseCommandRegistered)
    {
        AddClientCommandCallback("r1grapple_release",function(player,...){
            local s=R1Grapple_State(player)
            if(s.active)R1Grapple_Detach(player,"shift release")
            return true
        })
        R1Grapple.releaseCommandRegistered=true
    }
    if ( !R1Grapple.commandsRegistered )
    {
        AddClientCommandCallback("r1grapple_down",R1Grapple_Down)
        AddClientCommandCallback("r1grapple_up",R1Grapple_Up)
        R1Grapple.commandsRegistered = true
    }
    R1Grapple.generation++
    R1Grapple.enabled = true
    thread R1Grapple_Run(R1Grapple.generation)
    printt("[R1Grapple] Enabled: tap R or Mouse 4 to fire; tap again to detach; E reloads; no test cooldown.")
}

::R1Grapple_Disable <- function()
{
    R1Grapple.enabled = false
    R1Grapple.generation++
    foreach ( player in GetPlayerArray() )
    {
        if ( !IsValid(player) ) continue
        R1Grapple_Detach(player,"disabled")
        R1Grapple_State(player).held = false
    }
}

::R1Grapple_AutoStart <- function()
{
    while ( !("AddClientCommandCallback" in getroottable()) || !("GetPlayerArray" in getroottable()) ) wait 0.1
    // Native default 10 Hz quantized launch/return into only a few positions.
    // This is a server-wide script scheduler setting, not a render FPS limit.
    if(IsPrivateMatch() && GetConVarInt("script_server_fps")<60)ServerCommand("script_server_fps 60")
    if ("PrecacheMaterial" in getroottable()) PrecacheMaterial("cable/r1pm_grapple")
    // RopeMaterial is also registered in the model table by rope entities.
    if ("PrecacheModel" in getroottable()) PrecacheModel("cable/r1pm_grapple.vmt")
    PrecacheParticleSystem("P_impact_rodeo_damage")
    wait 0.2
    R1Grapple_Enable()
}
thread R1Grapple_AutoStart()




