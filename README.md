# Dhaka Velocity

An original Android-first open-world driving prototype built with Godot 4.

## Current prototype
- Procedurally built test city block with roads and simple buildings
- Third-person player capsule
- Two selectable vehicle silhouettes: Velocity Sport and Metro SUV (switch with the CAR touch button near the vehicle)
- Three-stage City Tour mission: reach FIRST DRIVE, NORTH GATE and WEST AVENUE checkpoints
- Four-color preset paint cycling plus a full custom color picker for mixing any color
- Dedicated metallic SILVER finish with reflective material settings
- Three selectable paint finishes: MATTE, GLOSS and METALLIC; finish changes apply to both vehicles
- Custom paint and silver finish apply to both selectable garage vehicle models
- Four selectable alloy-rim finishes: SILVER, GRAPHITE, BRONZE and TEAL, applied to both vehicle models
- Toggleable rear spoiler on the Velocity Sport
- Rechargeable nitro boost with a dedicated touch button and short boost reserve
- Dedicated DRIFT touch control with stronger steering response and lateral slide while held
- On-foot movement and enter/exit vehicle interaction
- Four simple moving traffic cars on the main road
- Road lane markings and street lights
- Separate GO, REV and BRAKE touch controls with live speed display
- Selectable steering modes: left/right touch buttons or a draggable, self-centering virtual steering wheel; the selected mode hides the unused steering controls
- Scrollable compact garage controls for smaller mobile screens
- Persistent local garage settings: paint color and finish, rim finish, selected vehicle, spoiler, headlights and steering mode are saved between launches
- Steering input now eases smoothly instead of snapping instantly
- Nearby traffic triggers a slowdown and a short traffic-alert message
- Steering response scales with vehicle speed; the follow camera smoothly widens its field of view as speed and nitro rise
- Functional toggleable headlights with forward spotlights on both vehicles
- Brake lamps, reverse lamps and animated left/right turn indicators respond to braking, reversing and steering
- Procedurally synthesized looping engine tone changes pitch with vehicle speed and nitro; a dedicated HORN touch button plays a short generated horn tone without external audio assets
- Four wheel assemblies visibly rotate with vehicle motion, front wheels steer with the input, and a subtle speed-linked spring motion approximates suspension travel
- Traffic-aware approach braking and basic impact response against traffic and city obstacles
- Touch-friendly on-screen directional controls
- Basic follow camera, lighting, and collision for the ground, buildings and player vehicle

## Project location
Open the `GodotPrototype` folder as a Godot project. The main scene is `Main.tscn`.

## Current limitations
This is an early playable-slice foundation, not a finished game. Vehicle physics and traffic are still arcade-style prototypes; full progress/mission saving, additional mission chains, enterable interiors, shops, home ownership, weapons/police systems and multiplayer are not implemented yet. The project has not yet been opened in the Godot editor, run, or device-tested as an APK. First test checklist: open `GodotPrototype/project.godot`, run the main scene, check both steering modes, enter/exit, garage customization persistence after restart, mission checkpoints, traffic impacts and UI fit on the target phone. Fix any parser/runtime errors before expanding content.

## Development branch
`godot-prototype`
