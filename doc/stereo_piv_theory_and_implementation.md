# Stereo-PIV Theory, DaVis-Style Workflow, and PIVlab Implementation Map

## Purpose
This note explains how a planar stereo-PIV system should work in this repository, using the local references in `refs/` and mapping each processing stage to the current PIVlab code. The target is a DaVis-style 2D3C workflow: measure in-plane velocity on a light sheet and reconstruct the third component from two oblique camera views.

## Local Reference Basis
This note is based mainly on:

- `refs/files/7558/Wieneke - 2005 - Stereo-PIV using self-calibration on particle images.pdf`
- `refs/files/10057/FL_DaVis 11 (1).pdf`
- `refs/files/7948/Sciacchitano and Wieneke - 2016 - PIV uncertainty propagation.pdf`
- `refs/files/10170/Wieneke - 2018 - Improvements for volume self-calibration.pdf`
- `refs/LaVision.bib`

The DaVis brochure gives the product-level workflow: calibration, recording, processing, visualization, and export in one chain. Wieneke 2005 provides the core stereo-PIV calibration logic that matters for implementation here: pinhole-based mapping, disparity-based self-calibration on particle images, and remapping onto the true laser sheet.

## Core Theory

### 1. Two cameras observe one illuminated plane
Stereo-PIV is still a planar measurement. The flow is illuminated in a thin laser sheet, but each camera sees that plane from a different angle. A single camera can only recover two image-plane displacement components. Two calibrated cameras provide enough information to reconstruct the three physical components on the sheet: `u`, `v`, and `w`.

### 2. Calibration is a mapping problem
For each camera, the fundamental object is a mapping:

`x_i = M_i(X, Y, Z)`

where `M_i` maps world coordinates in the measurement region to pixel coordinates in camera `i`. In practice, this can be represented by a polynomial mapping or a pinhole camera model with lens distortion. Wieneke 2005 argues that any mapping is acceptable as long as it models the optics accurately enough.

For this repository, the current monocular calibration path already follows the pinhole-model route:

- `+preproc/cam_estimateparams_Callback.m`
- `+opencv/pivlab_estimateCameraParameters.m`

That is the correct base for stereo work.

### 3. Why self-calibration is needed
The practical problem in stereo-PIV is that the calibration target is often not exactly in the laser sheet. If the plate plane and the light sheet do not coincide, the mapping derivatives used for 3C reconstruction are wrong, especially for the out-of-plane sensitivity.

Wieneke 2005 solves this by computing a disparity map from real particle images:

1. Dewarp both camera images onto the current world plane.
2. Cross-correlate corresponding regions.
3. Interpret residual disparity as evidence that the current plane is not the true light sheet.
4. Fit the actual particle plane in space.
5. Update the mapping functions so `Z=0` corresponds to the real light sheet.

This is the most important missing stereo-specific step in the current codebase.

### 4. 2D3C reconstruction
After calibration and self-calibration, each camera gives an image displacement vector. Those image displacements are related to the physical displacement in the laser sheet through the local Jacobian of the mapping. In implementation terms, reconstruction is a small linear system solved at each vector location:

`A * [dX dY dZ]^T = b`

where `b` is built from the measured image displacements from both cameras, and `A` comes from local mapping derivatives. Solving this system yields the world displacement components, then dividing by `dt` gives `u`, `v`, `w`.

### 5. Uncertainty still matters after reconstruction
Sciacchitano and Wieneke 2016 is not a stereo-only paper, but it is relevant: once image displacement uncertainty exists in each view, reconstruction and derivative quantities will amplify it. For stereo-PIV, the out-of-plane component is usually the most sensitive to calibration and correlation errors. This means the stereo module should eventually carry quality or uncertainty information, not only `u`, `v`, `w`.

## DaVis-Style Processing Flow
The DaVis-style workflow implied by the local references is:

1. Acquire synchronized left/right image pairs.
2. Perform monocular calibration for each camera.
3. Rectify or dewarp images consistently to a world plane.
4. Compute an initial stereo mapping from target images.
5. Use particle images for self-calibration and disparity correction.
6. Run standard 2D PIV in each view.
7. Reconstruct 3C velocity on the laser sheet.
8. Validate, visualize, and export.

In other words, stereo-PIV is not a replacement for 2D PIV. It is a wrapper around two calibrated 2D pipelines plus one reconstruction stage.

## Repository Implementation Map

| Stage | Theory / DaVis meaning | Current files | Status |
| --- | --- | --- | --- |
| Stereo mode toggle | Enter 2-camera 2D3C workflow | `+import/stereocheckbox_Callback.m`, `+gui/generateUI.m`, `+gui/generateMenu.m` | Exists, but lightweight |
| Per-camera target calibration | Estimate intrinsics, distortion, extrinsics | `+preproc/cam_estimateparams_Callback.m`, `+opencv/pivlab_estimateCameraParameters.m` | Implemented for one camera at a time |
| Per-camera dewarping | Undistort and apply rectification transform | `+preproc/cam_undistort.m`, `+preproc/cam_rectification_*` | Implemented |
| Standard 2D PIV | Compute image-pair displacement in one view | `+piv/piv_analysis.m`, `+piv/piv_FFTmulti.m`, `+postproc/PIVlab_postproc.m` | Implemented |
| Stereo session/config state | Store stereo settings and persistent state | `+stereo/default_settings.m`, `+stereo/default_session.m` | Scaffolded |
| Left/right file pairing | Pair camera 1 and camera 2 image lists | `+stereo/pair_image_lists.m` | Scaffolded |
| Stereo orchestration | Run the full 2D3C chain | `+stereo/run_analysis.m` | Scaffolded |
| Stereo calibration / world mapping | Build mapping from both calibrated cameras to the sheet | `+stereo/estimate_volume_calibration.m` | TODO |
| Disparity self-calibration | Correct misalignment using particle images | `+stereo/self_calibrate_disparity.m` | TODO |
| 3C reconstruction | Convert two view displacements into `u,v,w` | `+stereo/reconstruct_velocity.m` | TODO |
| Stereo export | Save stereo results and session state | `+stereo/export_results.m`, `+export/save_session_function.m`, `+import/load_session_Callback.m` | Partly scaffolded |

## What the Existing Code Already Supports

### Already usable
- Single-camera ChArUco-based calibration with reprojection checks.
- Image undistortion and per-camera rectification transforms.
- Mature 2D PIV correlation and post-processing.
- Session persistence for a stereo mode flag and a `stereo_session` struct.

### Not implemented yet
- Dual-view image import and pairing UX.
- A coupled stereo calibration object that combines camera 1 and camera 2.
- Particle-image self-calibration in the sense of Wieneke 2005.
- The actual 2D3C reconstruction solve.
- Stereo-specific validation and uncertainty reporting.

## Recommended Implementation Sequence

### Step 1: Pair the two views
Extend import so the user can load synchronized left/right image sets. The current scaffold entry is:

- `+stereo/pair_image_lists.m`

### Step 2: Reuse the existing calibration path
Do not redesign calibration first. Reuse:

- `+preproc/cam_estimateparams_Callback.m`
- `+opencv/pivlab_estimateCameraParameters.m`
- `+preproc/cam_undistort.m`

Then define one stereo calibration object that references both monocular models plus the measurement-plane mapping.

### Step 3: Run 2D PIV independently in each view
Wrap the current 2D engine instead of modifying it:

- `+piv/piv_analysis.m`
- `+piv/piv_FFTmulti.m`
- future wrapper: `+stereo/run_dual_view_2d_piv.m`

### Step 4: Implement self-calibration
This is the key stereo-specific algorithm. The implementation should:

1. Dewarp both views to the current world plane.
2. Cross-correlate particle images from camera 1 and camera 2.
3. Aggregate disparity over many image pairs.
4. Fit the actual light-sheet plane.
5. Update the mapping so reconstruction uses the corrected plane.

The placeholder is:

- `+stereo/self_calibrate_disparity.m`

### Step 5: Implement 3C reconstruction
For every vector location:

1. Evaluate local mapping derivatives for both cameras.
2. Build the linear system linking physical displacement to image displacement.
3. Solve for world displacement.
4. Convert to velocity using the time separation.

The placeholder is:

- `+stereo/reconstruct_velocity.m`

## Practical Design Guidance
- Keep stereo logic in `+stereo`; do not duplicate the 2D PIV code under `+piv`.
- Treat rectification and self-calibration as separate stages. Rectification cleans geometry; self-calibration corrects residual plane mismatch.
- Preserve raw per-view vector fields in the session object. Stereo debugging is much easier when left/right intermediate results are saved.
- Add a quality field to stereo results early. Even a simple condition number or residual error is better than returning only `u,v,w`.

## Bottom Line
For this repository, a DaVis-like stereo-PIV implementation should be built as:

`monocular calibration + per-view dewarping + two independent 2D PIV passes + particle-image self-calibration + local 3C reconstruction`

That architecture matches the local LaVision references and also matches the current codebase: the first half already exists, while the stereo-specific half is now scaffolded under `+stereo/` and ready for numerical implementation.
