# Installation and removal

## Requirements

- A working **Titanfall 1 + R1Delta** installation. Tested personal base: R1Delta 2000 RC5; other builds require testing.
- Close the game before installing. Keep existing settings and mods.
- Host/server installation supplies gameplay; clients need the addon for custom presentation. The tested mode is a private sole-player listen server.

## Checked installation on Windows

1. Extract the release ZIP into a separate folder, not over the game.
2. Open PowerShell in the extracted folder and run:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -GamePath "D:\Games\Titanfall"
   ```

   Substitute the folder containing `Titanfall.exe` and `r1\GameInfo.txt`. This execution-policy option applies to that invocation; the script does not change the machine policy. Administrator rights are not normally required. Preview the operation with `-WhatIf` first if desired.
3. The installer validates payload hashes and checks for conflicting loose addon paths. It **refuses** existing destination folders and the old `R1Delta.Sliding` personal prototype. It does not merge or overwrite them.
4. Start R1Delta, open its **Addons** menu, and enable **Powder**. Restart the game, then enter a private match.

The installer never edits your settings, keybinds or addon list. If an installation is interrupted, inspect the new addon folder before retrying; a partial folder is deliberately not deleted automatically.

## Manual installation

Copy only the `R1Delta.Powder` directory into `<Titanfall>\r1\addons\`. Stop if that destination already exists. Enable it in the Addons menu and restart.

If your build requires editing `r1\addonlist.txt` manually, back it up and add only this entry **inside its existing `AddonList` braces**, preserving every other entry:

```text
"R1Delta.Powder" "1"
```

Do not replace the whole addon list. No replacement `addonlist.txt`, `autoexec` or player profile is supplied.

## Choose your controls

Open **Settings > Controls > Key Bindings** and find the **POWDER** section. Choose a key for **Grapple (tap fire / release)**, then Apply. It starts unbound. Powersliding uses your existing **Crouch** or **Toggle Crouch** action; jump uses the ordinary **Jump** action. Sprint and crouch to powerslide, then time jumps yourself to bunny hop. No separate powerslide binding is needed.

At sign-on the addon defines aliases without binding any keys. Console commands remain an optional alternative:

```text
bind "MOUSE4" "+r1pm_grapple"
```

These lines change only the keys you explicitly execute, replacing those keys' existing actions. The example leaves Shift available for native sprint. Keep R/E/W/Mouse3 and all other controls as you prefer. Automatic sprint is not enabled by this release; use your existing sprint control.

- Grapple: tap the chosen key to fire; tap again to release.
- Slide: use ordinary crouch while running, or toggle crouch. Optional legacy command aliases remain available for existing personal layouts.
- Optional network preference for high-rate host updates: `cl_updaterate 60`. This is **not** applied automatically; the server may enforce a different limit.

If aliases are unavailable after a manual reload, `exec r1pm_commands` defines them without changing keybindings. Do not execute old `r1slide_controls` / `r1slide_load` profiles from the personal prototype.

## Update

Close the game. Back up the existing `R1Delta.Powder` folder **outside** `r1\addons`. Remove that old folder only after preserving any changes you made inside it, then install the new version. The checked installer deliberately has no overwrite/update switch. Preserve other addons and your existing addon-list entries.

## Uninstall

Disable this addon in the Addons menu, close the game, then remove only `r1\addons\R1Delta.Powder`. Restart the game. If you enabled it manually, remove only its own addon-list entry. Restore any keys you personally rebound using your saved bindings; the installer did not change them. Do not restore a whole old addon list over newer mods.

## Conflict reports

The Stim weapon-definition path is shared with other Stim mods. Stop if the installer reports an overlap; do not solve it by overwriting the other addon. Also review movement/AI controllers even when their filenames differ. Report R1Delta build, map, other enabled mods, reproduction steps and console errors. Native ragdolls after entity removal and unimplemented entity types are separate issues.

Audio also uses the shared `scripts/game_sounds_manifest.txt` path, based on R1Delta 2.14.14. All original manifest entries are retained. The installer refuses an overlapping manifest in another addon. Do not replace another mod's manifest; a reviewed merge is required for those combinations. A full game restart is required after enabling or disabling this audio version.

The Grapple entry uses shared `scripts/kb_act.lst`, preserving every stock action and adding one Powder action. An overlap from another addon is refused as well. No default-binding or player settings file is supplied. Back up the older `R1Delta.PilotMovement` addon outside `r1/addons` before upgrading to `R1Delta.Powder`.
