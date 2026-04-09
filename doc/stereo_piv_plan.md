# Stereo-PIV Extension Plan

## Goal
Extend the current 2D PIVlab workflow into a dual-camera stereo-PIV workflow that outputs 2D3C velocity fields without destabilizing the existing single-view path.

## Design Rules
- Reuse the current 2D stack for each camera view: `+preproc`, `+piv`, and `+postproc` stay the source of truth for per-view processing.
- Keep stereo-specific logic isolated in a new `+stereo` package.
- Store GUI stereo state in a single `stereo_session` struct so save/load can evolve without spreading new appdata keys everywhere.
- Treat stereo calibration, disparity self-calibration, and 3C reconstruction as separate pipeline stages with explicit hand-off structs.

## Proposed Pipeline
1. Load or pair image sequences for camera 1 and camera 2.
2. Reuse existing monocular calibration and rectification from `+preproc`.
3. Estimate or load a stereo / volume calibration model.
4. Run the existing 2D PIV analysis independently on both rectified views.
5. Apply optional disparity self-calibration on the matched vector fields.
6. Reconstruct `u`, `v`, `w` in world coordinates on the measurement plane.
7. Validate and export stereo results.

## New Scaffold
- `+stereo/default_settings.m`: default contract for stereo configuration.
- `+stereo/default_session.m`: persistent session container for GUI and command-line use.
- `+stereo/run_analysis.m`: top-level orchestration entry point.
- `+stereo/run_dual_view_2d_piv.m`: wrapper around existing 2D analysis for both cameras.
- `+stereo/estimate_volume_calibration.m`: stereo target / volume calibration placeholder.
- `+stereo/self_calibrate_disparity.m`: disparity correction placeholder.
- `+stereo/reconstruct_velocity.m`: 2D3C reconstruction placeholder.
- `+stereo/load_calibration.m`, `+stereo/save_calibration.m`, `+stereo/export_results.m`: persistence helpers.

## Implementation Order
1. Finish dual-view import and pairing, including GUI support for left/right image sets.
2. Decide the stereo calibration model:
   - Planar world-plane mapping only, or
   - Full stereo camera model with ray intersection / least-squares reconstruction.
3. Wrap current 2D PIV settings so both views can share or override preprocessing and interrogation settings.
4. Implement calibration loading, target detection, and mapping estimation.
5. Implement stereo vector matching and disparity self-calibration.
6. Implement 3C reconstruction and export paths.
7. Add regression tests with synthetic stereo image pairs and known world-space motion.

## Current Boundary
This scaffold defines APIs and persistence points only. Heavy numerical work, GUI panels, stereo target handling, and reconstruction math are still TODO items.
