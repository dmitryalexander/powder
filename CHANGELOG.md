# 0.23.0-preview

- Name the mod Powder: powersliding, bunny hopping and unlimited-use grapple for Titanfall 1 + R1Delta.
- Add Grapple under POWDER in the native Key Bindings menu, with no default key assignment. Powerslide uses ordinary Crouch / Toggle Crouch, including after legacy slide aliases have been used. Refuse conflicting key-binding lists and previous Pilot Movement installs.
- Restore one native airborne boost jump after an attached grapple releases. Misses and cosmetic-return cleanup do not replenish it.
- Include the separate R2 slide-jet event's four source clips, triggered only by the existing controller's accepted boost timestamp.
- Add original R2 grapple fire, surface impact/extraction, traverse, retract/reset and surface-specific slide start/bump/stop audio.
- Add an isolated audio observer with cleanup on release, jump, death, Titan transition, stop and reload. Keep movement/cable code unchanged except removing three placeholder zipline sound calls.
- Add namespaced audio and a shared-manifest conflict check. Full restart required. First-person playback; not an exact port of R2's native mixer or prediction.

# 0.21.0-preview

- Package the 0.20.6 personal build as a separate R1Delta addon.
- Remove automatic private keybindings, autosprint/client-network preferences, screenshot bind, manual cheat loader and personal addon/settings files.
- Add command-only aliases and install/update/uninstall instructions.
- Namespace autorun scripts, configuration and cable materials.
- Keep higher host script rates; apply the required minimum 60 only to private hosted matches.
- Replace derived R2 cable pixels with an original procedural black texture; exclude unused extracted textures.
- Add a checksum-checked, non-overwriting installer with loose-file conflict detection.
- Preserve core slide/grapple/NPC/Spectre/deployment/Stim behavior and the seven-second native Stim definition.

Earlier gameplay evidence is from the personal build. The release remains a preview pending clean-install gameplay testing on additional machines.
