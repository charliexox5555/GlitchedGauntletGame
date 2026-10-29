# Recall (was Rollback)

**Status:** spec locked 2026-10-29 · not built
**Inspiration:** Chamber's Rendezvous (Valorant). **Place an anchor**, and when you're in range, press the key to **teleport back to it**.
**Remove from the old Rollback:** rewinding to where you were 3 s ago.
**Later upgrade idea (not now):** a bigger teleport range.

## How it works
| Rule | Value |
|---|---|
| Place | Press the key → the gun lowers and you hold the anchor with a **placement preview** (green = valid ground, red = invalid). **LMB plants it** where you look, **within ~10 studs** on walkable ground. Press again or swap weapons to cancel (costs nothing) |
| Teleport | Once the anchor is placed, press the key while **within 40 studs** of it → a **0.6 s wind-up**, then you appear on the anchor |
| Out of range | Pressing beyond 40 studs is refused ("Out of range" cue); nothing is spent |
| Move it | Before you've teleported, **hold the key ~0.5 s near the anchor** (within ~6 studs) to pick it up and place it again |
| Uses | The **anchor stays all round** until you teleport to it; then it's used up. **1 teleport per round**, no recharge (unlimited in test mode) |
| Destroyable | **2 bullet hits** destroy the anchor (the teleport is lost for that round) |
| Gun | **You can't shoot during the 0.6 s wind-up.** You **arrive with the gun up** and can fire right away |
| During the wind-up | You can still be shot. Dying cancels the teleport |

## Server
- The server owns the anchor (position, HP) and the teleport.
- It validates: placement within range on walkable ground; that you're within 40 studs, alive and not mid-ability when you trigger the teleport.
- It runs the 0.6 s wind-up, then moves the character, working with the movement simulation the way Dash does.
- The anchor is a hittable target for the weapon system (2 HP worth of hits).

## First person
- **Hold anchor + place with preview:** the anchor in hand, a ghost preview on the ground, LMB plants it.
- **Wind-up:** the hand snaps/twists in a gesture and the **screen warps inward** toward the centre over 0.6 s, then you pop out at the anchor.
- **Arrival:** a quick violet flash and a slight camera settle.

## Look (Blender + VFX)
- **Anchor:** a compact tactical anchor device with a **cool violet** light, made in Blender (current tactical style). It glows softly so it's findable.
- **Teleport:** a violet shimmer on the player during the wind-up, then they vanish; a violet flash where they reappear.
- **Colours:** violet keeps it distinct from the other abilities (Heal Orb green-teal, Frost ice blue, Stim yellow, fire orange).

## What enemies see and hear
- The **anchor itself** (softly glowing), so they can find and shoot it.
- The **departure shimmer** during the wind-up.
- The **arrival flash** and sound at the anchor.

## Sound (hooks + placeholder sounds)
| Hook | What |
|---|---|
| `Recall_Equip` | Anchor out |
| `Recall_Place` | Anchor planted |
| `Recall_Idle` | Soft hum from the anchor (3D, ~20 studs) |
| `Recall_PickUp` | Anchor picked back up |
| `Recall_OutOfRange` | Refusal cue |
| `Recall_WindUp` | Teleport charging (3D, ~40 studs) |
| `Recall_Depart` | Vanish (3D) |
| `Recall_Arrive` | Appear at the anchor (3D, ~50 studs) |
| `Recall_Destroyed` | Anchor shot down (3D) |

## Mobile (provisional)
Tap to hold the anchor and **Fire** to place it. After that, tapping the Recall button teleports, and long-pressing near the anchor picks it up.

## Counter-play
Find and shoot the anchor (2 hits). Shoot the player during the 0.6 s shimmer. Pre-aim the anchor, since you know where they'll appear.
