// Nearby private-match grunts and Spectres use native think every simulation frame.
// Their normal ~0.1s think schedule held animation/root motion between thinks.
// No scripted origins, velocities, animation replacement or damage changes.
// Dropships have a separate bounded list, including their scripted flight.
if(!("R1NPCMotion" in getroottable()))
    ::R1NPCMotion <- {generation=0,enabled=true,error=null,actors=[],updates=0,frames=0,maxActors=8,range=2200.0,refresh=0.25}
R1NPCMotion.generation++
R1NPCMotion.enabled=true
R1NPCMotion.error=null
R1NPCMotion.actors.clear()
if(!("dying" in R1NPCMotion))R1NPCMotion.dying <- []
if(!("deathUpdates" in R1NPCMotion))R1NPCMotion.deathUpdates <- 0
if(!("deathCallbackRegistered" in R1NPCMotion))R1NPCMotion.deathCallbackRegistered <- false
if(!("ships" in R1NPCMotion))R1NPCMotion.ships <- []
if(!("shipUpdates" in R1NPCMotion))R1NPCMotion.shipUpdates <- 0
if(!("maxShips" in R1NPCMotion))R1NPCMotion.maxShips <- 4
if(!("shipRange" in R1NPCMotion))R1NPCMotion.shipRange <- 12000.0
R1NPCMotion.ships.clear()
R1NPCMotion.shipError <- null
R1NPCMotion.shipsEnabled <- true
R1NPCMotion.shipRefreshRequested <- true
if(!("shipSpawnCallbackRegistered" in R1NPCMotion))R1NPCMotion.shipSpawnCallbackRegistered <- false
R1NPCMotion.deploy <- []
R1NPCMotion.pods <- []
R1NPCMotion.podCandidates <- []
R1NPCMotion.deploymentEnabled <- true
R1NPCMotion.deploymentError <- null
R1NPCMotion.deploymentDirty <- true
R1NPCMotion.deploymentBirths <- []
if(!("deploymentUpdates" in R1NPCMotion))R1NPCMotion.deploymentUpdates <- 0
if(!("podUpdates" in R1NPCMotion))R1NPCMotion.podUpdates <- 0
if(!("deploymentCallbacksRegistered" in R1NPCMotion))R1NPCMotion.deploymentCallbacksRegistered <- false
if(!("spectreCallbacksRegistered" in R1NPCMotion))R1NPCMotion.spectreCallbacksRegistered <- false
R1NPCMotion.actorRefreshRequested <- true

::R1NPCMotion_GroundActors <- function()
{
    local actors=[]
    foreach(className in ["npc_soldier","npc_spectre"])actors.extend(GetNPCArrayByClass(className))
    return actors
}

::R1NPCMotion_IsPod <- function(e)
{
    local model=e.GetModelName()
    return model=="models/vehicle/droppod_fireteam/droppod_fireteam.mdl" || model=="models/vehicle/droppod_fireteam/droppod_fireteam_door.mdl"
}
::R1NPCMotion_OnDeploymentSpawn <- function(e)
{
    if(R1NPCMotion.deploymentBirths.len()>=64)R1NPCMotion.deploymentBirths.remove(0)
    R1NPCMotion.deploymentBirths.append({actor=e,at=Time()})
    R1NPCMotion.deploymentDirty=true
    R1NPCMotion.actorRefreshRequested=true
}
::R1NPCMotion_OnPropSpawn <- function(e)
{
    if(!IsValid(e) || !R1NPCMotion_IsPod(e))return
    foreach(pod in R1NPCMotion.podCandidates)if(pod==e)return
    // Cache only the known fireteam prop models; never scan all props per frame.
    if(R1NPCMotion.podCandidates.len()>=32)R1NPCMotion.podCandidates.remove(0)
    R1NPCMotion.podCandidates.append(e)
    R1NPCMotion.deploymentDirty=true
}
::R1NPCMotion_SelectDeployment <- function(now)
{
    if(!IsPrivateMatch())return {deploy=[],pods=[]}
    local players=GetPlayerArray()
    if(players.len()!=1 || !IsAlive(players[0]))return {deploy=[],pods=[]}
    local eye=players[0].EyePosition();local candidates=[];local deploy=[];local pods=[]
    foreach(e in R1NPCMotion_GroundActors())
    {
        if(!IsAlive(e))continue
        local until=now+0.35
        if(!e.Anim_IsActive())
        {
            until=-1.0
            foreach(entry in R1NPCMotion.deploy)if(entry.actor==e)until=entry.until
            if(until<now)continue
        }
        local distance=(e.GetOrigin()-eye).Length()
        local born=-1.0
        foreach(birth in R1NPCMotion.deploymentBirths)
            if(birth.actor==e && now-birth.at<15.0)born=birth.at
        if(distance<=6000.0)candidates.append({actor=e,distance=distance,until=until,born=born})
    }
    // New squads take priority over old scripted background/idle soldiers.
    candidates.sort(function(a,b)
    {
        if(a.born!=b.born)return a.born>b.born ? -1 : 1
        return a.distance<b.distance ? -1 : (a.distance>b.distance ? 1 : 0)
    })
    foreach(c in candidates)
    {
        deploy.append({actor=c.actor,until=c.until})
        if(deploy.len()>=12)break
    }
    candidates.clear()
    for(local i=R1NPCMotion.podCandidates.len()-1;i>=0;i--)
    {
        local e=R1NPCMotion.podCandidates[i]
        if(!IsValid(e)){R1NPCMotion.podCandidates.remove(i);continue}
        local distance=(e.GetOrigin()-eye).Length()
        if(distance<=12000.0)candidates.append({actor=e,order=i})
    }
    // Prop animation need not set the NPC scripted-animation flag. Prioritize
    // newly spawned pod bodies/doors over stationary remnants, without testing it.
    candidates.sort(function(a,b){return a.order>b.order ? -1 : (a.order<b.order ? 1 : 0)})
    foreach(c in candidates)
    {
        pods.append(c.actor)
        if(pods.len()>=4)break
    }
    return {deploy=deploy,pods=pods}
}

::R1NPCMotion_OnShipSpawn <- function(e)
{
    // Selection itself applies the private-match, distance and count limits.
    // A new ship must not wait out the periodic discovery interval.
    if(R1NPCMotion.enabled && R1NPCMotion.shipsEnabled)R1NPCMotion.shipRefreshRequested=true
}

::R1NPCMotion_OnDeath <- function(e,damageInfo)
{
    if(!R1NPCMotion.enabled || !IsPrivateMatch() || !IsValid(e))return
    local players=GetPlayerArray()
    if(players.len()!=1 || !IsValid(players[0]) || (e.GetOrigin()-players[0].GetOrigin()).Length()>R1NPCMotion.range)return
    foreach(entry in R1NPCMotion.dying)if(entry.actor==e)return
    if(R1NPCMotion.dying.len()>=R1NPCMotion.maxActors)R1NPCMotion.dying.remove(0)
    R1NPCMotion.dying.append({actor=e,until=Time()+3.0})
}

::R1NPCMotion_Select <- function()
{
    local candidates=[]
    if(!IsPrivateMatch())return []
    local players=GetPlayerArray()
    if(players.len()!=1 || !IsAlive(players[0]))return []
    local p=players[0];local eye=p.EyePosition();local forward=p.GetViewVector()
    foreach(e in R1NPCMotion_GroundActors())
    {
        if(!IsAlive(e) || e.Anim_IsActive())continue
        local d=e.GetOrigin()-eye;local distance=d.Length()
        if(distance>R1NPCMotion.range)continue
        // Keep close actors full-rate even at screen edges; distant actors
        // behind the camera retain ordinary native scheduling.
        if(distance>384 && distance>0.001 && R1Grapple_Dot(d,forward)/distance < -0.15)continue
        candidates.append({actor=e,distance=distance})
    }
    candidates.sort(function(a,b){return a.distance<b.distance ? -1 : (a.distance>b.distance ? 1 : 0)})
    local result=[]
    foreach(c in candidates)
    {
        result.append(c.actor)
        if(result.len()>=R1NPCMotion.maxActors)break
    }
    return result
}
::R1NPCMotion_SelectShips <- function()
{
    if(!IsPrivateMatch())return []
    local players=GetPlayerArray()
    if(players.len()!=1 || !IsAlive(players[0]))return []
    local eye=players[0].EyePosition();local candidates=[]
    foreach(e in GetNPCArrayByClass("npc_dropship"))
    {
        if(!IsValid(e) || !IsAlive(e))continue
        local distance=(e.GetOrigin()-eye).Length()
        if(distance<=R1NPCMotion.shipRange)candidates.append({actor=e,distance=distance})
    }
    candidates.sort(function(a,b){return a.distance<b.distance ? -1 : (a.distance>b.distance ? 1 : 0)})
    local result=[]
    foreach(c in candidates)
    {
        result.append(c.actor)
        if(result.len()>=R1NPCMotion.maxShips)break
    }
    return result
}
::R1NPCMotion_Run <- function(generation)
{
    local selectAt=-1.0;local shipSelectAt=-1.0;local deploySelectAt=-1.0;local last=-1.0
    try
    {
        while(R1NPCMotion.enabled && R1NPCMotion.generation==generation)
        {
            local now=Time()
            if(now!=last)
            {
                last=now;R1NPCMotion.frames++
                if(now>=selectAt || R1NPCMotion.actorRefreshRequested)
                {
                    R1NPCMotion.actors=R1NPCMotion_Select()
                    R1NPCMotion.actorRefreshRequested=false
                    selectAt=now+R1NPCMotion.refresh
                }
                foreach(e in R1NPCMotion.actors)
                {
                    if(!IsValid(e))continue
                    if(!IsAlive(e)){R1NPCMotion_OnDeath(e,null);continue}
                    if(e.Anim_IsActive())continue
                    e.SetNextThinkNow()
                    R1NPCMotion.updates++
                }
                // Death animations must not fall back to the slow schedule
                // at the exact frame IsAlive becomes false.
                for(local i=R1NPCMotion.dying.len()-1;i>=0;i--)
                {
                    local entry=R1NPCMotion.dying[i]
                    if(!IsValid(entry.actor) || now>entry.until){R1NPCMotion.dying.remove(i);continue}
                    entry.actor.SetNextThinkNow()
                    R1NPCMotion.deathUpdates++
                }
                // Scripted ship flight still needs native animation/think
                // advancement. Do not apply the soldier Anim_IsActive filter.
                // Isolate this path so vehicle failures cannot stop grunts.
                if(R1NPCMotion.shipsEnabled)
                {
                    try
                    {
                        if(now>=shipSelectAt || R1NPCMotion.shipRefreshRequested)
                        {
                            R1NPCMotion.ships=R1NPCMotion_SelectShips()
                            shipSelectAt=now+R1NPCMotion.refresh
                            R1NPCMotion.shipRefreshRequested=false
                        }
                        foreach(e in R1NPCMotion.ships)
                        {
                            if(!IsValid(e) || !IsAlive(e))continue
                            e.SetNextThinkNow()
                            R1NPCMotion.shipUpdates++
                        }
                    }
                    catch(err)
                    {
                        R1NPCMotion.shipError=err.tostring();R1NPCMotion.shipsEnabled=false
                        R1NPCMotion.ships.clear()
                        printt("[R1NPCMotion] Dropship scheduling stopped:",err)
                    }
                }
                if(R1NPCMotion.deploymentEnabled)
                {
                    try
                    {
                        if(now>=deploySelectAt || R1NPCMotion.deploymentDirty)
                        {
                            local selected=R1NPCMotion_SelectDeployment(now)
                            R1NPCMotion.deploy=selected.deploy;R1NPCMotion.pods=selected.pods
                            R1NPCMotion.deploymentDirty=false;deploySelectAt=now+R1NPCMotion.refresh
                        }
                        foreach(entry in R1NPCMotion.deploy)
                        {
                            local e=entry.actor
                            if(!IsValid(e) || !IsAlive(e))continue
                            if(e.Anim_IsActive())entry.until=now+0.35
                            if(now>entry.until)continue
                            e.SetNextThinkNow();R1NPCMotion.deploymentUpdates++
                        }
                        foreach(e in R1NPCMotion.pods)
                        {
                            if(!IsValid(e))continue
                            e.SetNextThinkNow();R1NPCMotion.podUpdates++
                        }
                    }
                    catch(err)
                    {
                        R1NPCMotion.deploymentError=err.tostring();R1NPCMotion.deploymentEnabled=false
                        R1NPCMotion.deploy.clear();R1NPCMotion.pods.clear()
                        printt("[R1NPCMotion] Deployment scheduling stopped:",err)
                    }
                }
            }
            WaitFrame()
        }
    }
    catch(err)
    {
        R1NPCMotion.error=err.tostring();R1NPCMotion.enabled=false
        R1NPCMotion.actors.clear()
        printt("[R1NPCMotion] Stopped:",err)
    }
}
::R1NPCMotion_Start <- function(generation)
{
    while(!("GetNPCArrayByClass" in getroottable()) || !("IsPrivateMatch" in getroottable()) || !("R1Grapple_Dot" in getroottable()) || !("AddDeathCallback" in getroottable()) || !("deathCallbacks" in level))wait 0.1
    if(!R1NPCMotion.deathCallbackRegistered)
    {
        AddDeathCallback("npc_soldier",R1NPCMotion_OnDeath)
        R1NPCMotion.deathCallbackRegistered=true
    }
    while(!("AddSpawnCallback" in getroottable()) || !("SpawnActions" in level))wait 0.1
    if(!R1NPCMotion.shipSpawnCallbackRegistered)
    {
        AddSpawnCallback("npc_dropship",function(e){R1NPCMotion_OnShipSpawn(e)})
        R1NPCMotion.shipSpawnCallbackRegistered=true
    }
    if(!R1NPCMotion.deploymentCallbacksRegistered)
    {
        AddSpawnCallback("npc_soldier",function(e){R1NPCMotion_OnDeploymentSpawn(e)})
        AddSpawnCallback("prop_dynamic",function(e){R1NPCMotion_OnPropSpawn(e)})
        R1NPCMotion.deploymentCallbacksRegistered=true
    }
    if(!R1NPCMotion.spectreCallbacksRegistered)
    {
        AddSpawnCallback("npc_spectre",function(e){R1NPCMotion_OnDeploymentSpawn(e)})
        AddDeathCallback("npc_spectre",function(e,damageInfo){R1NPCMotion_OnDeath(e,damageInfo)})
        R1NPCMotion.spectreCallbacksRegistered=true
    }
    // Bootstrap props that existed before a hot reload; thereafter spawn events
    // maintain the small model-filtered cache.
    foreach(e in GetEntArrayByClass_Expensive("prop_dynamic"))R1NPCMotion_OnPropSpawn(e)
    if(R1NPCMotion.generation==generation)thread R1NPCMotion_Run(generation)
}
thread R1NPCMotion_Start(R1NPCMotion.generation)
