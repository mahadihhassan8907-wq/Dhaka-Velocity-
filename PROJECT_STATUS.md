Dhaka Velocity - Current Prototype Status

## Recovered gameplay systems in v8
- Procedurally generated starter city block and road layout.
- On-foot player controller with walk, run and jump input.
- Three selectable character slots: Marcus, Felix and Damian. These are prototype visuals, not finished unique character assets.
- Enter/exit vehicle flow.
- Sport-car placeholder plus alternate SUV body.
- Mobile steering buttons and virtual steering wheel, movement joystick, touch camera orbit and zoom.
- Vehicle acceleration, reverse, braking, drift, nitro, horn, headlights, brake/reverse lamps and turn signals.
- Moving traffic actors and a three-checkpoint city-tour objective.
- Basic garage options: paint, finish, rims, spoiler and saved settings.

## Verified in cloud
- Godot 4.4.1 headless editor import/parse completed successfully.
- Main scene launched in a 120-frame headless smoke test without a script parse/runtime crash.
- Detailed sport sedan GLB is not yet in this Git branch. The script safely uses procedural car visuals until that asset is added.

## Not finished
This is a playable-prototype foundation, not the promised full open-world game. A larger Dhaka-style map, finished character/car assets, richer missions, optimization, audio polish, and real-device testing remain.

## Build pipeline
- Godot validation: .github/workflows/godot-check.yml
- Android arm64 debug APK attempt: .github/workflows/android-apk.yml
- Android export is still being validated; do not treat an APK as ready until the workflow produces and uploads one successfully.
