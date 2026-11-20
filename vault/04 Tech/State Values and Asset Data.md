# State values and asset data

The Match results screen previously stopped before opening when the server hit Roblox's 1,024-byte Attribute payload limit. `MatchEndService` now publishes one results snapshot in `ReplicatedStorage.MatchState.Results`. The snapshot includes the winner, scores, round history and fighter rows. The controller checks both the snapshot and phase so it can open when either replicates first, and clients joining during results can read the same data. The next match clears the snapshot.

## Runtime state

- Keep server decisions in server-side variables. Server services use `Shared.StateValues` to publish the fields that clients need. Replicated values are visible to clients. The server continues to validate and rate-limit remote requests.
- `StateValues.get`, `set`, `changed` and `anyChanged` read, write and observe runtime fields. An empty field clears a runtime value. `StateValues.all` reads the authored defaults plus runtime overrides. Keep mode, queue and combat contracts on the existing services and remotes.
- `CharacterService` prepares all fields in `Simulation/Fields` before Movement and Poses step the character. Add a field to that list when a bound simulation callback writes it. Both places use `Workspace.AuthorityMode = Automatic`. Switching to Server Authority requires separate rollback verification.

## Editing active assets

The shared configuration lives in `src/shared/Config/AssetData`, grouped by place and asset type. Existing rows include an example Studio path. To add data, put a row in the appropriate ModuleScript and give the instance the `GauntletAuthoredData` tag and the row's `GGAsset_…` tag. Give an instance its own row if its settings should differ from other instances using a shared row. Tags travel with clones, so renaming or moving a cloned map, weapon or GUI template preserves its defaults.

The migration covers map models recognized by MapService, current Lobby geometry and V4 staging, weapon templates and skins, abilities, locker assets, StarterGui and Match settings. It leaves archive, staging imports, legacy builds, authoring kits and reference models in place. Roblox-managed fields such as `RBXRefinementScale` are maintained by Studio.

To apply the migration to another copy of the same scene, sync both Rojo projects, then run `tools/studio/MigrateAssetData.luau` in Edit mode in each matching place. It validates the whole plan before tagging or clearing any field. Add a matching ModuleScript row before applying to an asset whose authored data has since changed. Save the place through Studio after reviewing the result. Git and the published places have separate release steps.

In Match Studio, select **Workspace** in Explorer and find **TestMode** under **Attributes** in Properties. Set it before pressing Play. Checked starts the test range, and unchecked starts a match. The server reads this checkbox only in Studio and publishes the resolved mode as a runtime value. The asset migration preserves the checkbox. `BotMatch`, `BotDifficulty` and `ForceMap` are in `Config/AssetData/MatchSettings.luau`.

## Studio verification

See the [playtest record](../05%20Production/Playtests/2026-11-19%20State%20Values.md) for the results payload regression, 2v2 rematch, Lobby queue and asset audits.
