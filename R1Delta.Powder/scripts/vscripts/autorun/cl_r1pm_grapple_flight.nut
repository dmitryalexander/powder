// All cable phases use one WORLD projection with a camera-derived outlet.
// Attached cable also renders each client frame; the accepted clamp stays native.
if("R1GrappleFlight_Stop" in getroottable())R1GrappleFlight_Stop()
::R1GrappleFlight <- {enabled=true,generation=UniqueString("flight"),screens=[],marker=null,launchMarker=null,
    signature="",mode="",started=0.0,outTime=0.0,returnTime=0.0,error=null,
    frames=0,movingFrames=0,phaseFrames={hit=0,miss=0,release=0,attached=0},lastFrame=-1.0,minDt=1.0,maxDt=0.0,heartbeat=-10.0,segments=48,
    nearSegments=12,cockpit=null,nearFrames=0,maxJoinError=0.0,lastLocalOutlet=null,worldOnly=false,poolWorldOnly=false}

::R1GrappleFlight_Dot <- function(a,b){return a.x*b.x+a.y*b.y+a.z*b.z}
::R1GrappleFlight_Cross <- function(a,b){return Vector(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x)}
::R1GrappleFlight_Clear <- function()
{
    foreach(screen in R1GrappleFlight.screens)if(IsValid(screen))screen.Destroy()
    R1GrappleFlight.screens.clear()
    R1GrappleFlight.marker=null
    R1GrappleFlight.launchMarker=null
    R1GrappleFlight.signature=""
    R1GrappleFlight.cockpit=null
}
::R1GrappleFlight_Stop <- function()
{
    R1GrappleFlight.enabled=false
    local p=GetLocalClientPlayer()
    if(IsValid(p))p.ClientCommand("r1grapple_frame_renderer 0")
    R1GrappleFlight_Clear()
}
::R1GrappleFlight_ToView <- function(point,camera,angles)
{
    local d=point-camera
    return Vector(R1GrappleFlight_Dot(d,angles.AnglesToForward()),-R1GrappleFlight_Dot(d,angles.AnglesToRight()),R1GrappleFlight_Dot(d,angles.AnglesToUp()))
}
::R1GrappleFlight_FromView <- function(point,camera,angles)
{
    return camera+angles.AnglesToForward()*point.x-angles.AnglesToRight()*point.y+angles.AnglesToUp()*point.z
}
::R1GrappleFlight_Pool <- function(count,cockpit)
{
    local f=R1GrappleFlight
    if(f.cockpit!=cockpit || f.poolWorldOnly!=f.worldOnly)
    {
        foreach(screen in f.screens)if(IsValid(screen))screen.Destroy()
        f.screens.clear()
        f.cockpit=cockpit
        f.poolWorldOnly=f.worldOnly
    }
    while(R1GrappleFlight.screens.len()<count)
    {
        local index=f.screens.len()
        local screen=!f.worldOnly && index<f.nearSegments ? Create_PilotVGUI("vgui_icon",cockpit,GetLocalClientPlayer(),0.001,0.001) :
            CreateClientsideVGuiScreen("vgui_icon",VGUI_SCREEN_PASS_WORLD,Vector(0,0,0),Vector(0,0,0),0.001,0.001)
        // Register resource before touching its panel, so failure cleanup owns it.
        R1GrappleFlight.screens.append(screen)
        local icon=HudElement("CenterIcon",screen.GetPanel())
        icon.SetImage("HUD/r1pm_grapple_world")
        icon.SetColor(255,255,255,255)
        icon.SetSize(150,150);icon.SetPos(0,0);icon.Show()
    }
}
::R1GrappleFlight_Segment <- function(index,a,b,width,camera,viewAngles=null)
{
    local screen=R1GrappleFlight.screens[index]
    local firstPerson=!R1GrappleFlight.worldOnly && index<R1GrappleFlight.nearSegments
    if(firstPerson)
    {
        a=R1GrappleFlight_ToView(a,camera,viewAngles)
        b=R1GrappleFlight_ToView(b,camera,viewAngles)
        camera=Vector(0,0,0)
    }
    local d=b-a
    local length=d.Length()
    if(length<0.001){screen.SetSize(0.001,0.001);return}
    local forward=d*(1.0/length)
    local normal=camera-(a+b)*0.5
    normal-=forward*R1GrappleFlight_Dot(normal,forward)
    local angles=forward.GetAngles()
    if(normal.Length()<0.001)normal=angles.AnglesToUp()
    else normal*=1.0/normal.Length()
    angles.z=atan2(R1GrappleFlight_Dot(normal,angles.AnglesToRight()),R1GrappleFlight_Dot(normal,angles.AnglesToUp()))*57.2957795
    local right=angles.AnglesToRight()
    // Physical screen X follows the segment; physical Y is -Right().
    local origin=a+right*(width*0.5)-forward*0.015
    if(firstPerson)
    {
        screen.SetAttachOffsetOrigin(origin)
        screen.SetAttachOffsetAngles(angles)
    }
    else
    {
        screen.SetOrigin(origin)
        screen.SetAngles(angles)
    }
    screen.SetSize(length+0.03,width)
}
::R1GrappleFlight_Find <- function(p)
{
    local f=R1GrappleFlight
    if(IsValid(f.marker) && IsValid(f.launchMarker))return true
    f.marker=null;f.launchMarker=null
    foreach(e in GetClientEntArrayBySignifier("info_target"))
    {
        if(e.GetOwner()!=p)continue
        local name=e.GetName()
        if(name.find("r1grapple_anim:")==0)f.marker=e
        else if(name.find("r1grapple_anim_launch")==0)f.launchMarker=e
    }
    return IsValid(f.marker) && IsValid(f.launchMarker)
}
::R1GrappleFlight_Tip <- function(mode,launch,destination,origin,age,outTime,returnTime)
{
    if(mode=="hit")return launch+(destination-launch)*min(1.0,max(0.0,age/max(0.001,outTime)))
    if(age<outTime)
    {
        local t=max(0.0,age/max(0.001,outTime))
        return launch+(destination-launch)*(1.0-(1.0-t)*(1.0-t))
    }
    local t=min(1.0,max(0.0,(age-outTime)/max(0.001,returnTime)))
    return destination+(origin-destination)*(t*t*(3.0-2.0*t))
}
::R1GrappleFlight_AttachedPoints <- function(p,origin,fields)
{
    local f=R1GrappleFlight
    if(fields.len()<9)return null
    local count=fields[6].tointeger()
    if(count<0 || count>4)throw "invalid attached path count"
    local bends=[];bends.resize(count)
    local suffix=fields[2]+":"+fields[7]+":"+fields[8]
    if(count>0)foreach(e in GetClientEntArrayBySignifier("info_target"))
    {
        if(e.GetOwner()!=p)continue
        local name=e.GetName()
        if(name.find("r1grapple_path:")!=0)continue
        local parts=split(name,":")
        if(parts.len()!=5 || parts[2]+":"+parts[3]+":"+parts[4]!=suffix)continue
        local i=parts[1].tointeger()
        if(i>=0 && i<count)bends[i]=e.GetOrigin()
    }
    foreach(point in bends)if(point==null)return null // wait for one coherent topology
    local path=[origin]
    for(local i=count-1;i>=0;i--)path.append(bends[i])
    path.append(f.marker.GetOrigin())
    return R1GrappleFlight_TautPoints(path)
}
::R1GrappleFlight_TautPoints <- function(path)
{
    local f=R1GrappleFlight
    local origin=path[0]
    // Reserve the near section for the first 48u. Include each actual corner
    // explicitly; uniform samples across the whole polyline would cut corners.
    local d=path[1]-origin;local length=d.Length()
    local nearEnd=length>0.001 ? origin+d*(min(48.0,length*0.25)/length) : origin
    local points=[origin]
    for(local i=1;i<=f.nearSegments;i++)points.append(origin+(nearEnd-origin)*(i.tofloat()/f.nearSegments))
    local previous=nearEnd;local remaining=f.segments-f.nearSegments
    for(local leg=1;leg<path.len();leg++)
    {
        local spans=remaining/(path.len()-leg)
        for(local i=1;i<=spans;i++)points.append(previous+(path[leg]-previous)*(i.tofloat()/spans))
        previous=path[leg];remaining-=spans
    }
    if(points.len()!=f.segments+1)throw "attached segment allocation mismatch"
    return points
}
::R1GrappleFlight_Draw <- function(p,now)
{
    local f=R1GrappleFlight
    local name=f.marker.GetName()
    if(name!=f.signature)
    {
        local fields=split(name,":")
        if(fields.len()<6)throw "invalid flight state"
        f.mode=fields[1];f.started=fields[2].tofloat();f.outTime=fields[3].tofloat();f.returnTime=fields[4].tofloat()
        f.signature=name
    }
    local camera=p.CameraPosition()
    local angles=p.CameraAngles()
    local forward=angles.AnglesToForward();local right=angles.AnglesToRight();local up=angles.AnglesToUp()
    local origin=camera+forward*32.0-up*32.0
    if(f.mode=="attached")
    {
        local points=R1GrappleFlight_AttachedPoints(p,origin,split(name,":"))
        if(points==null)return
        local cockpit=p.GetCockpit()
        if(!IsValid(cockpit))return
        // A taut line must use one projection. The first-person pass has a
        // different FOV/near plane and distorted the new short attached join.
        // Camera-derived world endpoints still follow the rendered view each
        // frame, without inheriting replicated player/viewmodel transforms.
        f.worldOnly=true
        R1GrappleFlight_Pool(f.segments+7,cockpit)
        for(local i=0;i<f.segments;i++)R1GrappleFlight_Segment(i,points[i],points[i+1],0.55,camera,angles)
        for(local i=f.segments;i<f.segments+7;i++)f.screens[i].SetSize(0.001,0.001)
        f.lastLocalOutlet=R1GrappleFlight_ToView(origin,camera,angles)
        f.lastAttachedOutlet <- origin
        f.lastAttachedTip <- points.top()
        f.phaseFrames.attached++;f.movingFrames++;f.nearFrames++
        return
    }
    local age=max(0.0,now-f.started)
    local tip=R1GrappleFlight_Tip(f.mode,f.launchMarker.GetOrigin(),f.marker.GetOrigin(),origin,age,f.outTime,f.returnTime)
    local axis=tip-origin
    local distance=axis.Length()
    if(distance>0.001)axis*=1.0/distance
    else axis=forward
    local endpoint=tip-axis*min(10.0,distance)
    local cableDistance=(endpoint-origin).Length()
    local control1=origin+forward*min(75.0,cableDistance*0.22)+right*6.0
    local control2=origin+(endpoint-origin)*0.70-up*min(14.0,cableDistance*0.035)
    local amplitude=min(24.0,cableDistance*0.045)
    local points=[]
    for(local i=0;i<=f.segments;i++)
    {
        local u=i.tofloat()/f.segments
        local a=1.0-u
        local point=origin*(a*a*a)+control1*(3*a*a*u)+control2*(3*a*u*u)+endpoint*(u*u*u)
        local envelope=sin(3.14159265*u)
        point+=right*(envelope*envelope*amplitude*sin(age*9.0-u*4.5))
        point+=up*(envelope*amplitude*0.45*cos(age*7.0-u*3.0))
        points.append(point)
    }
    local cockpit=p.GetCockpit()
    if(!IsValid(cockpit))throw "missing pilot cockpit"
    // The cockpit pass has a different projection from WORLD. Even identical
    // join coordinates separate on screen during flight/return. Keep the entire
    // accepted curve in one pass, as for the attached cable above.
    f.worldOnly=true
    R1GrappleFlight_Pool(f.segments+7,cockpit)
    f.lastLocalOutlet=R1GrappleFlight_ToView(origin,camera,angles)
    local join=points[f.nearSegments]
    local roundTrip=R1GrappleFlight_FromView(R1GrappleFlight_ToView(join,camera,angles),camera,angles)
    f.maxJoinError=max(f.maxJoinError,(roundTrip-join).Length())
    for(local i=0;i<f.segments;i++)R1GrappleFlight_Segment(i,points[i],points[i+1],0.55,camera,angles)
    // Identical deployed shaft/three-arm geometry to the accepted native hook.
    local side=Vector(axis.y,-axis.x,0)
    if(side.Length()<0.001)side=Vector(0,1,0)
    else side*=1.0/side.Length()
    local hookUp=R1GrappleFlight_Cross(side,axis)
    local hook=[endpoint,tip]
    for(local arm=0;arm<3;arm++)
    {
        local angle=arm*2.0943951
        local radial=side*cos(angle)+hookUp*sin(angle)
        local root=endpoint+axis*4.0
        local elbow=tip-axis*2.0+radial*6.0
        local claw=tip+radial*5.0
        hook.extend([root,elbow,elbow,claw])
    }
    for(local i=0;i<7;i++)R1GrappleFlight_Segment(f.segments+i,hook[i*2],hook[i*2+1],1.25,camera)
    f.movingFrames++
    f.nearFrames++
    f.phaseFrames[f.mode]++
}
::R1GrappleFlight_Run <- function(generation)
{
    try
    {
        PrecacheHUDMaterial("HUD/r1pm_grapple_world")
        while(R1GrappleFlight.enabled && R1GrappleFlight.generation==generation)
        {
            local now=Time()
            local p=GetLocalClientPlayer()
            local f=R1GrappleFlight
            if(f.lastFrame>=0 && now>f.lastFrame)
            {f.minDt=min(f.minDt,now-f.lastFrame);f.maxDt=max(f.maxDt,now-f.lastFrame)}
            f.lastFrame=now;f.frames++
            if(IsValid(p) && IsAlive(p) && !p.IsTitan())
            {
                // Startup/health only; drawing still runs on every WaitFrame.
                if(now-f.heartbeat>5.0){p.ClientCommand("r1grapple_frame_renderer 1");f.heartbeat=now}
                if(R1GrappleFlight_Find(p))R1GrappleFlight_Draw(p,now)
                else if(f.screens.len()>0)R1GrappleFlight_Clear()
            }
            else if(f.screens.len()>0)R1GrappleFlight_Clear()
            // Stock R1 WaitFrame yields a positive interval. WaitEndFrame alone
            // can repeatedly resume inside the same frame; never use it here.
            WaitFrame()
        }
    }
    catch(err)
    {
        R1GrappleFlight.error=err.tostring()
        R1GrappleFlight_Stop()
        printt("[R1GrappleFlight] Native fallback after client error:",err)
    }
}
thread R1GrappleFlight_Run(R1GrappleFlight.generation)
