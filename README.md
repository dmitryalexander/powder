# Powder

Powersliding, bunny hopping and an infinite-use grapple for Titanfall 1 + R1Delta.

R1Delta addon for **Titanfall 1**, version **0.23.0-preview**. Intended for hosted private matches. It is not a Titanfall 2 / Northstar mod.

## Features

- Momentum-preserving pilot slide and a server-authoritative grapple with client-frame black cable, collision-contact wrapping, fixed claw and animated launch/return.
- Powerslide into manually timed bunny hops. Grapple has unlimited uses with no recharge; each attached tether has a ten-second safety duration.
- Red enemy-target reticle; grapple phase and contracted attached reticle remain intact.
- One native airborne boost jump is restored after an attached grapple releases, including when a boost jump was used while attached. Misses do not grant a jump.
- Native per-frame scheduling for nearby grunts and Spectres on both teams, their deployment/death transitions, dropships and known fireteam pod props.
- Stim with a +70% speed bonus and a seven-second base duration. Existing native duration modifiers still apply.
- Original Titanfall 2 grapple and surface-specific slide clips, converted to PCM WAV and driven by a separate audio-only observer. First-person sounds target the pilot; movement and cable logic are preserved. Requires the R1Delta 2.14.14 sound-manifest baseline and a full restart after installation.

The audio uses namespaced `R1PM.*` events. Its shared sound manifest retains every stock entry and adds one namespaced file. The installer refuses another addon's overlapping manifest rather than overwriting that mod. Native Titanfall 2 event mixing, third-person/enemy mixes and prediction are not reproduced exactly by R1's engine.

## Download

Get **Powder-0.23.0-preview.zip** from [GitHub Releases](https://github.com/dmitryalexander/powder/releases/tag/v0.23.0-preview).

## Install

Read **INSTALL.md**. The checked installer creates only a new `r1/addons/R1Delta.Powder` folder. It does not edit `addonlist.txt`, `autoexec_user.cfg`, `config.cfg`, player profiles, other addon folders, or any game VPK/DLL. Enable the addon using R1Delta's Addons menu afterward.

**No automatic key rebindings.** No automatic autosprint, screenshot-bind or client updaterate changes. Bind the namespaced commands to keys you choose; examples are in INSTALL.md. The former personal settings profile is deliberately excluded.

## Runtime behavior and compatibility

The mod changes gameplay while enabled. In a private hosted match it raises `script_server_fps` to a minimum of 60 at startup if it is lower; an existing higher value is retained. This is a runtime scheduling requirement, not a settings-file edit. A game restart after disabling the addon returns runtime configuration to the game's normal startup values.

NPC scheduling is bounded: eight nearby normal actors, eight dying actors for up to three seconds, twelve scripted/deploying actors, four dropships and four pod props. Distance limits and the private sole-player condition remain; actors outside coverage keep normal scheduling. Some features are not established for shared/dedicated servers.

Shared game-file overrides are `scripts/weapons/mp_ability_heal.txt` for Stim duration, `scripts/game_sounds_manifest.txt` for audio registration and `scripts/kb_act.lst` for the selectable Grapple action. Powerslide uses ordinary Crouch / Toggle Crouch. All stock binding actions are retained. The installer refuses detected loose-file overlaps, existing destination folders and older movement addons. Behavioral conflicts with other movement, grapple, crosshair, AI-scheduling, audio or Stim mods cannot be ruled out by file checks. Packed mods also need manual review. Do not combine such mods without testing.

## Preview status

Based on the accepted 0.20.6 private-match movement build with the 0.20.7 audio observer. This distribution removes forced settings, namespaces files and replaces the derived cable texture with an original procedural texture. Packaging, installer tests and audio verification limits are recorded in `VALIDATION.md`. Release-specific runtime behavior, broad CPU performance, every map/FOV/death/ragdoll case and all mod combinations are not certified. The deferred Titan/gunship/turret/MRVN audit is not included.

Source scripts are included. No executable, native DLL, diagnostic service, crash dump, private save/configuration or extracted Titanfall 2 texture is bundled. See THIRD_PARTY_NOTICES.txt.
