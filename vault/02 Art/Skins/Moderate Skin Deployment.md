# Moderate skin deployment

**2026-11-16.** Playback, Breakwater and Sundial are installed in both Roblox places, with seven skins per line. The match preview and the Locker recognize all 21 skins. The existing weapon rigs and attachment transforms are carried over from stock.

| Place | ID | Saved Roblox version |
| --- | --- | ---: |
| Lobby | 71551303511506 | 571 |
| Match | 133387545285290 | 580 |

## Bulldog and Stinger

The stock Bulldog front pedestal sat 0.027 studs above the receiver in the forward mounting area. The shared seat bridges that gap below the original sight. It is installed on the stock Bulldog and all nine Bulldog skin templates in each place. The sight and AimPoint were retained. [Corrected Blender source](../../../art-source/weapons/Skins/Shared%20Sources/Bulldog/SightSeat_v01/Bulldog_RemasterV2_v05_SightSeat_v01.blend)

The stock and standard skin templates use the shared Bulldog bolt and Stinger handguard corrections. Four structural variants were rebuilt and uploaded from their own revised sources. These are Payload Bulldog, Payload Stinger, Inkshift Stinger and Giltfold Stinger. Playback Bulldog and Stinger use the repaired base geometry from the earlier build.

## Studio verification

- Each place checked 21 moderate templates, four structural replacements and 22 affected stock and skin templates. The checks cover geometry and weld presence, correct replacement mesh IDs, mounted sight positions, texture maps and Locker routing.
- Asset preloads passed for the installed packages. The lobby's first load of one Bulldog roughness image failed and succeeded on retry.
- Match preview routing passed for the 21 moderate skins. Studio checks on scaled Playback Phantom, Breakwater Knife and Sundial Guardian clones confirmed the cosmetic inspect welds move and return to rest.
- The temporary installer was removed before the cloud saves. The recorded versions are Team Create saves.

[Deployment jobs](../../../art-source/weapons/Skins/Review/Moderate/Studio/deployment-jobs.json) · [Upload record](../../../art-source/weapons/Skins/Review/Moderate/Studio/deployment-uploads.json) · [Validation and save results](../../../art-source/weapons/Skins/Review/Moderate/Studio/deployment-validation.json)

