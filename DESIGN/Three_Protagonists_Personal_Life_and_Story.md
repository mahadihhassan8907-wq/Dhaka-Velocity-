# Dhaka Velocity — Three Protagonists: Personal Life & Story Design

## Core rule
Dhaka Velocity has one continuous single-player Dhaka world. Story Mode includes open-world free roam; character switching does not create separate maps. Each protagonist owns a separate home, current world position, wallet, personal mission progression, and profile. Switching characters restores that character's saved position and cash balance.

## The protagonists

### Marcus — family and neighbourhood
- Home: Marcus' Family Home, a warm, modest family house on the north-west edge of the district.
- Personality: steady, protective, practical; prioritises family and neighbours.
- Play feel: balanced walking speed and driving.
- Personal story arc:
  1. A Family Favour — collect a parcel from the local shop.
  2. North Side Delivery — take it to a meeting point on the north avenue.
  3. Back Home — return safely and check on the family.
- Prototype rewards: $120 / $180 / $250.

### Felix — ambition and street racing
- Home: Felix' City Apartment, a compact modern apartment on the north-east side.
- Personality: ambitious, competitive, wants to make a name in Dhaka's street-racing scene.
- Play feel: quickest on foot; racing-focused story hooks.
- Personal story arc:
  1. Racer's Call — meet a racing contact at the central junction.
  2. Test Run — reach the east avenue checkpoint.
  3. Cool Down — return to his apartment.
- Prototype rewards: $140 / $220 / $280.

### Damian — fixer and old debts
- Home: Damian's Riverside House, a quieter house on the south-west side.
- Personality: independent, patient, resourceful; old contacts and unfinished business.
- Play feel: slightly slower, more deliberate movement.
- Personal story arc:
  1. Old Debt — find a contact on the west side.
  2. Quiet Pickup — reach the south avenue for a hidden package.
  3. Safe House — return to his own home.
- Prototype rewards: $160 / $240 / $320.

## Implemented in the current mobile prototype
- Three distinct home compounds with separate facades, signs, interior furniture, lighting, and walk-in front entrances.
- Personal Life panel with character profile, home name, current mission, and per-character story progress.
- Go To My Home action for the active protagonist, plus a home Rest / Save interaction that restores stamina.
- Three personal mission steps per protagonist, with separate progression and rewards.
- A visible world-space beacon marks the active mission destination.
- Character switching restores the selected protagonist's own world position and separate wallet.
- Each protagonist has a distinct on-foot movement profile and personal funds display.
- Mission progress, active tracking, character positions, and wallet balances are saved in the local game config.
- Character position autosaves every 15 seconds during play; home rest also saves immediately.

## Full production roadmap (not yet implemented)
1. Add bespoke high-quality character models, facial identity, clothing variants, voice and animation sets.
2. Expand the prototype home interiors with bedroom, kitchen, garage, storage, wardrobe and a full sleep/day-cycle system.
3. Add family members, friends, contacts, phone calls, dialogue choices and character-specific daily schedules.
4. Expand each personal arc into multi-stage missions with driving, delivery, chase, stealth, timed objectives and cutscenes.
5. Add shared crossover missions where the three protagonists meet and can be switched during selected sequences.
6. Add a character wheel and a cinematic switch camera; keep touch controls accessible on Android.
7. Add separate owned vehicles, garages, wardrobe and inventory where performance and save design allow.
8. Add mission replay, mission prerequisites, story flags and robust save-slot migration.

## Mobile performance constraints
Homes and mission markers use lightweight procedural geometry. Keep collision shapes simple, avoid heavy per-frame work, and use shared meshes/materials where possible. Replace prototype geometry with optimized authored assets in a later visual pass; do not inflate draw calls just to add decorative detail.
