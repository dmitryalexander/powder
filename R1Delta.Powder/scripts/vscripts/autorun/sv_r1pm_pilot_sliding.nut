// Experimental server-only movement approximation. No client animation/prediction.
// Starts automatically on a hosted server once map scripts are initialized.
if ( !( "R1Slide" in getroottable() ) )
{
    ::R1Slide <- {
        enabled = false,
        generation = 0,
        minEntrySpeed = 200.0,
        boostAdd = 456.0,
        boostCap = 600.0,
        boostCooldown = 2.0,
        deceleration = 50.0,
        velocityRetention = 0.7,
        minExitSpeed = 125.0,
        cooldown = 0.0
    }
}

// Values extracted from the installed R2 client player schema and pilot_base.set.
// Refresh them on explicit reload as well as on a new server VM.
R1Slide.minEntrySpeed = 200.0
// User-selected entry kick +20%; ceiling subsequently raised to 600.
R1Slide.boostAdd <- 456.0
R1Slide.boostCap <- 600.0
R1Slide.boostCooldown <- 2.0
R1Slide.deceleration = 50.0
R1Slide.velocityRetention <- 0.7
R1Slide.minExitSpeed = 125.0
R1Slide.cooldown = 0.0

::R1Slide_UpdatePlayer <- function( player, dt, now )
{
    if ( !( "r1SlideState" in player.s ) || player.s.r1SlideState.generation != R1Slide.generation )
    {
        player.s.r1SlideState <- {
            generation = R1Slide.generation,
            crouched = true,
            grounded = false,
            previousVelocity = Vector( 0, 0, 0 ),
            active = false,
            readyTime = 0.0,
            lastBoostTime = -1000.0,
            speed = 0.0,
            direction = Vector( 0, 0, 0 ),
            airStarted = -1.0
        }
    }
    local s = player.s.r1SlideState
    local velocity = player.GetVelocity()
    // Grapple owns velocity while attached. Preserve its release momentum and
    // allow a crouched landing to re-enter sliding after the tether lets go.
    if ( "R1Grapple_IsActive" in getroottable() && R1Grapple_IsActive(player) )
    {
        s.active = false
        s.grounded = false
        if ( s.airStarted < 0.0 ) s.airStarted = Time()
        s.previousVelocity = velocity
        return
    }
    // Input is visible before the engine finishes lowering the crouch hull.
    // Waiting for IsCrouched() can miss the standing speed at slide entry.
    local crouched = player.IsCrouched()
    if ( "gameUI" in player.s && IsValid( player.s.gameUI ) && "crouch" in player.s.gameUI.s.buttonState )
        crouched = ButtonPressed( player, "crouch" ) || crouched
    // Hold-crouch does not emit the early game_ui signal in this R1 build.
    // The control aliases relay button edges explicitly, before hull slowdown.
    if ( "r1SlideControls" in player.s )
        crouched = crouched || player.s.r1SlideHeld || player.s.r1SlideToggled
    local grounded = player.IsOnGround()
    local eligible = IsAlive( player ) && !player.IsTitan() && !player.IsWallRunning() && !player.IsWallHanging() && !player.IsMantling() && !player.IsZiplining()
    local wasSliding = s.active
    local takingOff = eligible && !grounded && s.grounded
    local landing = eligible && grounded && !s.grounded && s.airStarted >= 0.0 && now - s.airStarted >= 0.03

    if ( takingOff )
    {
        s.airStarted = now
        // Keep horizontal slide momentum on a jump. Leave vertical jump physics
        // and all subsequent air strafing to the engine.
        local horizontalSpeed = velocity.Length2D()
        if ( wasSliding && velocity.z > 0.0 && horizontalSpeed > 1.0 && horizontalSpeed < s.speed )
        {
            local carry = s.speed
            velocity = Vector( velocity.x * carry / horizontalSpeed, velocity.y * carry / horizontalSpeed, velocity.z )
            player.SetVelocity( velocity )
        }
    }
    if ( !eligible )
        s.airStarted = -1.0

    if ( !eligible || !grounded || !crouched )
    {
        if ( s.active && grounded )
            s.readyTime = now + R1Slide.cooldown
        s.active = false
    }

    // Use the previous standing velocity: crouching can already reduce speed.
    local crouchEntry = s.grounded && crouched && !s.crouched
    if ( eligible && grounded && crouched && ( crouchEntry || landing ) && now >= s.readyTime )
    {
        local entry = Vector( s.previousVelocity.x, s.previousVelocity.y, 0 )
        local speed = entry.Length2D()
        local requiredSpeed = landing ? R1Slide.minExitSpeed : R1Slide.minEntrySpeed
        if ( speed >= requiredSpeed )
        {
            s.direction = entry * ( 1.0 / speed )
            // Run->crouch and crouched landing intentionally share this EXACT
            // boost/cooldown rule. Do not introduce a stronger landing boost.
            // Add the selected boost; the selected ceiling limits only
            // added speed, not pre-existing momentum above that ceiling.
            s.speed = speed
            if ( now - s.lastBoostTime >= R1Slide.boostCooldown && speed < R1Slide.boostCap )
            {
                s.speed = min( speed + R1Slide.boostAdd, R1Slide.boostCap )
                s.lastBoostTime = now
            }
            s.active = true
            player.SetVelocity( Vector( s.direction.x * s.speed, s.direction.y * s.speed, velocity.z ) )
            // Passive acceptance evidence: actual immediate engine velocity,
            // not only the requested target. This does not prove later feel.
            s.lastEntry <- { time=now, incomingSpeed=speed, targetSpeed=s.speed,
                observedVelocity=player.GetVelocity(), landing=landing }
        }
    }
    else if ( s.active )
    {
        // R1's crouch friction can cause a sharp speed loss at landing. It is
        // not sufficient evidence of a wall; confirm it with the actual hull.
        local along = velocity.x * s.direction.x + velocity.y * s.direction.y
        local blocked = false
        if ( along < s.speed * 0.3 )
        {
            local start = player.GetOrigin() + Vector( 0, 0, 1 )
            local finish = start + s.direction * max( 4.0, s.speed * dt )
            local trace = TraceHull( start, finish, player.GetBoundingMins(), player.GetBoundingMaxs(), player, TRACE_MASK_PLAYERSOLID_BRUSHONLY, TRACE_COLLISION_GROUP_PLAYER )
            blocked = trace.fraction < 0.1
        }
        if ( blocked )
        {
            s.active = false
            s.readyTime = now + R1Slide.cooldown
        }
        else
        {
            s.speed = max( 0.0, s.speed * pow( R1Slide.velocityRetention, dt ) - R1Slide.deceleration * dt )
            if ( s.speed < R1Slide.minExitSpeed )
            {
                s.active = false
                s.readyTime = now + R1Slide.cooldown
            }
            else
                player.SetVelocity( Vector( s.direction.x * s.speed, s.direction.y * s.speed, velocity.z ) )
        }
    }

    s.crouched = crouched
    s.grounded = eligible && grounded
    s.previousVelocity = velocity
    if ( grounded )
        s.airStarted = -1.0
}

::R1Slide_Run <- function( generation )
{
    local last = Time()
    while ( R1Slide.enabled && R1Slide.generation == generation )
    {
        local now = Time()
        local dt = min( max( now - last, 0.0 ), 0.05 )
        last = now
        foreach ( player in GetPlayerArray() )
        {
            if ( !IsValid( player ) )
                continue
            try
            {
                R1Slide_UpdatePlayer( player, dt, now )
            }
            catch ( error )
            {
                // Fail closed; report the first incompatible engine call.
                R1Slide.enabled = false
                printt( "[R1Slide] Disabled after script error:", error )
                return
            }
        }
        wait 0.016
    }
}

::R1Slide_Enable <- function()
{
    if ( R1Slide.enabled )
        return
    if ( !( "commandsRegistered" in R1Slide ) || !R1Slide.commandsRegistered )
    {
        AddClientCommandCallback( "r1slide_down", R1Slide_InputDown )
        AddClientCommandCallback( "r1slide_up", R1Slide_InputUp )
        AddClientCommandCallback( "r1slide_toggle", R1Slide_InputToggle )
        R1Slide.commandsRegistered <- true
    }
    R1Slide.generation++
    R1Slide.enabled = true
    thread R1Slide_Run( R1Slide.generation )
    printt( "[R1Slide] Experimental sliding enabled for this server." )
}

::R1Slide_InputInit <- function( player )
{
    if ( !( "r1SlideControls" in player.s ) )
    {
        player.s.r1SlideHeld <- false
        player.s.r1SlideToggled <- player.IsCrouched()
        player.s.r1SlideControls <- true
    }
}

::R1Slide_InputDown <- function( player, ... )
{
    R1Slide_InputInit( player )
    player.s.r1SlideHeld = true
    return true
}

::R1Slide_InputUp <- function( player, ... )
{
    R1Slide_InputInit( player )
    player.s.r1SlideHeld = false
    return true
}

::R1Slide_InputToggle <- function( player, ... )
{
    R1Slide_InputInit( player )
    player.s.r1SlideToggled = !player.s.r1SlideToggled
    return true
}

::R1Slide_Disable <- function()
{
    R1Slide.enabled = false
    R1Slide.generation++
    printt( "[R1Slide] Sliding disabled." )
}

::R1Slide_AutoStart <- function()
{
    while ( !("AddClientCommandCallback" in getroottable()) || !("GetPlayerArray" in getroottable()) ) wait 0.1
    wait 0.2
    R1Slide_Enable()
}
thread R1Slide_AutoStart()
printt( "[R1Slide] Saved R2 profile loaded; waiting for host map initialization." )
