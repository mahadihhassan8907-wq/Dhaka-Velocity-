# Dhaka Velocity - Godot branch

This branch is isolated from the original Unity-oriented `main` branch.

## Project contents
- `Main.tscn`: entry scene.
- `Scripts/DhakaVelocity_v8.gd`: recovered v8 gameplay script.
- Android-first landscape viewport using Godot 4.4-compatible GL Compatibility rendering.

## Cloud validation
GitHub Actions downloads the official Godot 4.4.1 editor and runs a headless editor import/parse pass. This is a project/script validation step, not proof of visual gameplay or a completed Android APK.

## Known asset dependency
The v8 script optionally loads:
`res://Assets/DhakaVelocity_Super3D_SportSedan.glb`

If that model is not present, the script reports the missing model and keeps its procedural vehicle visuals. The recovered GLB is retained separately and still needs to be added to this branch before the detailed sport-car model can appear.

The original `main` branch and its files have not been changed.
