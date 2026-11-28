# Dhaka Velocity — Gameplay Systems Architecture

## Core rule
Free Roam, Story Missions, Side Activities, and Racing are separate gameplay systems. They may share the city, player, vehicles, UI framework, and save data, but one system must not silently activate another.

## 1. Free Roam
- Default game state on launch.
- Player can walk, drive, explore, enter available interiors, interact with shops, and use the garage.
- No automatic route gates, checkpoint rings, race timer, or forced objective.
- Ambient traffic and pedestrians continue independently.
- HUD describes the current free-roam state, not a mission.

## 2. Story Missions and Tasks
A separate Mission Manager will own:
- Mission definitions: unique ID, title, briefing, start trigger, objectives, rewards, and unlock conditions.
- Mission states: locked, available, active, completed, failed.
- Objective types: reach a location, talk to a character, enter/exit a vehicle, deliver an item, follow/chase a target, escape a search area, interact with an object.
- Task progression and mission completion are driven by objective events, never by the racing checkpoint system.
- Mission start points and phone notifications are explicit interactions; free roam remains available when no mission is active.
- Dialogue/cutscenes and character conversations are added as their own layer.

## 3. Racing Mode
A separate Race Manager will own:
- Race start interaction, grid placement, countdown, route gates/checkpoints, lap count, race timer, finish detection, results, and rewards.
- Checkpoint gates exist only while a race is active.
- Race HUD appears only in Racing Mode.
- Leaving or finishing a race returns the player to Free Roam.

## 4. Shared systems
- Economy/inventory and save data are shared, with rewards granted by the system that earned them.
- World interaction points can start a shop interaction, a story mission, or a race, but each has its own handler.
- UI uses separate panels/states so mission text cannot overwrite race status or free-roam prompts.

## 5. Implementation order
1. Keep the current default state as Free Roam and verify no City Tour checkpoint is spawned or updated.
2. Add a data-driven Mission Manager and one simple story mission without using race gates.
3. Add phone/briefing UI and objective updates.
4. Add a separate Race Manager and a test circuit with race-only gates.
5. Expand mission variety, interiors, dialogue, and city districts after the systems are stable.

## Current implementation note
The prototype currently contains legacy City Tour/checkpoint helper code in the main script, but it is not started from game launch and its proximity progression is not called. It is reserved for refactoring into Racing Mode; it is not an open-world mission.
