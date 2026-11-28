# Dhaka Velocity — Visual Quality and 3D Asset Roadmap

## Guiding principle
Do not expand gameplay with placeholder-looking content while the visual foundation remains weak. Every major gameplay feature should arrive with an appropriate visual pass. Target a polished, readable, performant Android open-world prototype first; do not claim AAA GTA V/VI fidelity.

## Visual production priorities

### Phase A — Visual foundation
- Establish a consistent Dhaka-inspired art direction: contemporary South Asian city streets, shopfronts, signage, balconies, rooftop water tanks, utility poles, street furniture, road wear and varied building silhouettes.
- Improve lighting, sky, ambient occlusion-like contact shading where affordable, shadow quality, reflections and color grading within Godot/mobile limits.
- Add scalable quality profiles: Low, Balanced, High. Keep Android performance and thermal load in mind.
- Use reusable materials and shared meshes where possible to reduce draw calls and memory use.
- Improve road markings, sidewalks, curbs, streetlights, traffic signals and visual landmarks.

### Phase B — 3D world assets
- Replace repeated box-like building appearance with a modular kit: ground-floor shop units, apartment blocks, offices, balconies, windows, doors, roofs and rooftop props.
- Add distinct Dhaka street props: signboards, rickshaws, bus stops, barriers, bins, benches, poles, cables and market stalls.
- Build reusable interior kits for shops and mission locations rather than isolated one-off geometry.
- Add LOD strategy and distance-based visibility for buildings, props, pedestrians and traffic.
- Keep collision meshes simpler than visible meshes.

### Phase C — Vehicles and characters
- Upgrade player cars with better body proportions, glass, lights, mirrors, wheel arches, tyres, rims, interiors and material response.
- Create a small set of visually distinct vehicle classes before increasing the vehicle count.
- Improve pedestrian silhouettes, clothing colors, animations, idle/walk/run cycles and interaction poses.
- Add animation and collision simplification for mobile performance.

### Phase D — Gameplay visual integration
- Story missions: unique mission locations, character staging, dialogue camera framing, interaction prompts and objective feedback. No race checkpoint rings.
- Racing: dedicated race start/finish props, route gates, lap indicators, countdown and results UI. Checkpoints only while a race is active.
- Shops and side activities: recognizable storefronts, interiors, products and interaction feedback.
- Shared UI visual language: readable mobile HUD, consistent typography, icons, panel hierarchy and safe touch zones.

## Production sequence
1. Audit current prototype visuals and performance hotspots.
2. Define the art direction and mobile quality tiers.
3. Improve the central district's roads, buildings, lighting and street props as one coherent visual slice.
4. Upgrade the main player car and one pedestrian set.
5. Add LOD/visibility and performance checks before expanding the city.
6. Build the first story mission in the upgraded district with bespoke location/character presentation.
7. Build a separate race venue and race-only visual assets.
8. Expand districts and asset variety incrementally.

## Acceptance checks for each visual milestone
- Godot import/parse/smoke validation passes.
- Android ARM64 debug build succeeds.
- No new severe collision, camera, touch-control or scene-start regressions.
- Keep geometry/material reuse and object counts appropriate for Android.
- Never describe a visual upgrade as complete until the actual scene/assets are implemented and validated.
