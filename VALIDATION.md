# Release validation

Validated on October 22, 2026. Distribution: 0.23.0-preview, based on personal build 0.20.7-test.

## Packaging checks

- 138 payload files match the SHA-256 manifest; all files are confined to the new addon folder.
- Seven source scripts match the personal build after documented namespacing and the private-host minimum-rate guard. The eighth script defines commands without keybind/cvar assignments.
- 120 imported stereo PCM16 WAV files and all 43 event references are checked. The shared sound manifest retains every stock R1Delta 2.14.14 entry.
- Stim definition matches the tested seven-second personal build.
- No private settings, addon-list replacement, autoexec, native binaries, game archives, diagnostic service, extracted R2 textures, or old control/cheat loader is included.
- The small black texture is generated from an original procedural pattern. Its VTF header and payload were checked.

## Installer safety

Eleven cases passed on both Windows PowerShell 5.1 and PowerShell 7:

1. Clean installation preserves all pre-existing settings/profile/addon/addon-list bytes.
2. Existing destination is refused without changes.
3. WhatIf writes nothing.
4. A shared Stim weapon path in another addon is refused.
5. The legacy personal prototype is refused.
6. The wrong game is refused.
7. Tampered payload is refused before destination creation.
8. Path traversal is refused.
9. Another addon's shared sound manifest is refused, preserving its bytes.
10. Another addon's key-binding list is refused, preserving its bytes.
11. The previous Pilot Movement addon is refused.

These checks cover filesystem safety, not arbitrary mod-to-mod runtime compatibility. The installer does not alter addonlist; enable the addon in the game UI.

## Gameplay status

The personal build has native gameplay evidence described in the development diary: cable motion, grunt/Spectre/deployment/dropship scheduling, red enemy reticle, doubled extra Stim speed and parsed seven-second duration. Those observations are not a clean-install gameplay certification for this release.

All eight packaged scripts compiled in the native client/server VMs. Playback, automatic startup, cleanup and the requested post-grapple jump verification are recorded separately in verification-v0.20.7.txt. The first full restart crashed in native client.dll+0x35D03 after pilot spawn; causation is unresolved. A subsequent restart loaded private Fracture successfully. The user confirmed grapple audio, then accepted the separate slide jet and post-release boost jump with "perfect. SHIP IT". Fresh-install gameplay, new procedural material appearance, arbitrary addon combinations and broader performance remain pending. This is why the package is labeled preview.

Audio targets the owning pilot. R2 native mixing, third-person/enemy mixes and prediction are not reproduced exactly. Slide start clips are sustained with R1 loop flags; bump detection uses an observed speed-drop heuristic. These are implementation choices, not verified R2 event internals.
