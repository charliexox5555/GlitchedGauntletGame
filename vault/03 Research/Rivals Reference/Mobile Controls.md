# RIVALS mobile controls: Studio read (2026-11-25)

Read only, from the RIVALS file in Studio ("rivals file updated without DMCA @CLSTUDIO.rbxl"): `StarterPlayerScripts.Modules.UserInterface.MobileInputs` (`Joystick`, `Buttons`, `Buttons.MobileButton`, `DoubleTap`), `ReplicatedStorage.Modules.InputLibrary` and `Controllers.MechanicsController`. Study, not copy ([rivals-reference](../../../.claude/skills/rivals-reference/SKILL.md) rules). Earlier reads: [Rivals Mobile UI](../UI%20References/Rivals%20Mobile%20UI.md) (videos, owner's phone captures, the editor). Our build: [UI Mobile Controls](../../02%20Art/UI%20Mobile%20Controls.md#stick-and-button-pass-2026-11-25).

## Move stick
- **It is Roblox's own dynamic thumbstick, unchanged.** `StarterPlayer.DevTouchMovementMode = DynamicThumbstick`, no forked PlayerModule in the file. Their `Joystick` module only hides the `ThumbstickStart` image (it re-hides it whenever Roblox shows it), mirrors the frame for left-handed, and sizes their editor's `JoystickArea` to Roblox's `DynamicThumbstickFrame`.
- So the behaviour is Roblox's (from its published PlayerModule source, not measured here; our place has no readable PlayerModule in Play):
  - **The base is fixed for the whole touch** at the point the thumb landed. It never follows the thumb, so there is no re-centre and pulling back never reverses until the thumb crosses the start point.
  - **Max speed is reached very early:** about 20 px from the start on screens whose short side is ≤ 500 px (40 px on bigger screens), dead zone about 2 px (4). Past that the move is full speed in the thumb's direction, however far the thumb goes.
  - Speed is linear from the dead zone to the max-speed radius.
  - The nub image follows the thumb with a trail of small dots back to the (hidden) start.
- **Auto sprint** (`MechanicsController`, every RenderStepped): sprint turns on when not crouching or sliding and the move vector magnitude is **≥ 0.9**, and off below it.

## Buttons
- **Hit test = the button's full square box** (`UILibrary:IsWithinBounds(AbsolutePosition, AbsoluteSize)`), so a round button gets free slop in its corners. All buttons under the touch fire. Touches on their top bars (`Inset:IsWithinAnyBar`) are ignored.
- **One `UserInputService.InputBegan` listener** for all buttons (Touch or MouseButton1, not gated on `gameProcessed`); a hold ends when that InputObject's `UserInputState` becomes `End`. Toggle buttons flip on down.
- **The buttons keep their touch:** each is an `ImageButton` with `Interactable = true` (`Active = false`), so a swipe that starts on a button does not turn the camera. One-thumb aim-and-shoot comes from `DoubleTap` on the right half instead.
- **Per frame:** one RenderStepped loop that only updates the infinite-ammo particles. Visuals and visibility change on events (equip, health, scope, settings), never per frame.
- **Look:** transparency from settings; a held or equipped button doubles its opacity and tints the icon blue; scoped = fully opaque (setting). Ammo sits on the weapon slot buttons.
- **Slide chaining:** with Easy Slide on, a Crouch tap during a slide is a jump (slide-jump from the same button).

## Default layout (phone, short side ≤ 500 px; centre offsets from the corner)
| Button | Size px | Centre (from bottom-right unless noted) | Toggle |
|---|---|---|---|
| Aim | 70 | (-90, -185) | per gun |
| Shoot | 70 | (-160, -150) | no |
| Jump | 80 | (-90, -90) | no |
| Crouch | 70 | (-185, -75) | always |
| Slide (off by default) | 70 | (-270, -75) | no |
| Reload | 50 | (-230, -130) | no |
| Weapon slots ×4 | 40 | top-right row, y 60, x -175 / -130 / -85 / -40 | no |
| Quick melee / utility | 30 | top-right, y 100 | no |
| Inspect, POV, player list, emote | 40 | top-left row, y 80 | no |

Gaps between neighbours: Shoot-Aim 8 px, Reload-Shoot 13, Jump-Aim 20, Crouch-Jump 21. Tablets (short side > 500): positions × 1.79, sizes × 1.71, cluster 45 px higher.

## What we took (our own code and art)
- A base that stays put for the whole touch, full speed past the ring, linear speed in between (our numbers: dead zone 0.08, full at 0.55 of the ring; Config/TouchControls `STICK`).
- Run only on a strong push (theirs 0.9, ours 0.6, since our run builds from the walk).
- Buttons keep their touch, except the ones you aim with (Fire, Aim, Mods), which the owner wants to look through.
- Event-driven button visuals; one input listener.
- Kept ours where we differ on purpose: bigger Fire and Jump, the Mod arc, our Soft Edge circles, saved layouts as fractions.
