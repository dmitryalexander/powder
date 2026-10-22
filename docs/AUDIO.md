# Audio sources

The included recordings were extracted from the owner's local Titanfall 2 general.mbnk
with official LegionPlus1.9.2 and converted to stereo PCM16 WAV. Original bank SHA-256
and each imported file's checksum are recorded in import-manifest.json.

The separate slide-jet event jumpjet_slide_start_1p resolves to four
jumpjet_jetbody_st_v1 recordings; slide-jet-reference.json records the bank offsets.
Grapple and slide clips use namespaced R1 sound aliases. The observer reads existing
movement state; the jet follows the actual accepted boost timestamp.

This is first-person owner audio. R2's full native mixer,envelopes,third-person/enemy
mixes and prediction are not ported exactly. Slide start uses R1 loop flags; bumps
use a speed-drop heuristic. See THIRD_PARTY_NOTICES.txt for game-content attribution.
No game executable,bank,stream archive,LegionPlus or proprietary codec DLL is bundled.
