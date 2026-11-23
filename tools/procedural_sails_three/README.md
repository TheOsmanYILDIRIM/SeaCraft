# SeaCraft · Procedural 3D Sail & Rigging (Three.js)

**No Blender**. 3D meshes are generated programmatically from `catalog.json`, in vessel-local 3D coordinates. The interactive viewer uses **Three.js 0.186.1** to display the same mesh geometry with orthographic camera and fixed light; no 2D drawing, ocean, hull or textures exist in this library.

There are 6 elementary families (square, gaff, lateen, lug, jib/staysail, Bermuda), 12 rig combinations (R01–R12), and 15 canonical SeaCraft ships (SC-01–SC-15). Source meshes are once generated with rigging tubes (cylindrical centerlines through cubic Bézier sample points), spars, material slots, and precise corner/foot attachment records. Only `ShipRigRoot.rotation.z` changes across headings; no mirroring or per-heading geometry rebuild.

**Visual verification method:** This execution environment has no functioning Chromium WebGL and cannot install `three` from npm. To actually check the visuals, `render_reference.py` rasterizes the **same verified 3D triangle buffers** into orthographic 55° clay reference PNGs using an independent CPU triangle rasterizer (not SVG or hand-drawn 2D). These images and GLBs are generated and inspected. GitHub Actions additionally installs Three.js from npm and runs actual Three.js **scene-graph tests**. Browser GPU/WebGL rendering is offered by `viewer.html` but was **not visually verified in this environment**.

## Reproduce

```bash
cd tools/procedural_sails_three
npm install --no-audit --no-fund --package-lock=false
python3 -m pip install pillow numpy opencv-python-headless trimesh
npm run test:geometry
npm run test:three
npm run models
npm run gallery
npm run verify
python3 -m http.server 8000
# Open http://localhost:8000/viewer.html in a WebGL-capable browser
```

## Models and exports

- `geometry.mjs` — independent parameterized 3D scene builder; `generate_models.mjs` — strict CLI validator and SHA-256 scene identity recorder.
- `three_adapter.mjs` — actual Three.js `Mesh`, `BufferGeometry`, `Group` scene hierarchy and fixed orthographic camera.
- `viewer.html` — clickable 6/12/15 selection, 8 headings, zoom, transparent PNG export, and binary GLB export via Three.js `GLTFExporter`.
- `render_reference.py` — CPU triangle renderer from actual mesh vertices and GLB exporter; `verify_artifact.py` — independent model/readback and alpha/clip checks.
- `output/gallery/01_six_families_square_3x2.png` — six primitive types in one **1536×1536** PNG, 3 columns × 2 rows.
- `output/gallery/02_twelve_rigs_square_4x3.png` — 12 rigs in one **2048×2048** PNG, 4 columns × 3 rows.
- `output/models/{primitive,rigs,ships}/*.glb` — **33 real 3D models**.
- `output/png/{primitive,rigs,ships}/...` — **138** transparent RGBA orthographic views (**120** ship directions + **18** prototype views).
- `output/atlas/SC-NN_4x2.png` — **15** 8-frame transparent atlases (N,NE,E,SE / S,SW,W,NW).
- `output/validation.json` — exact mast feet, sail families, mesh and curve counts, corner attachment records, 8 heading yaw angles, and local geometry hash.
- `output/artifact_verification.json` — image bounds, alpha, per-file GLB SHA-256 and import readback.

## Geometry and camera invariants

- Vessel local convention: **bow +Y, starboard +X, up +Z**. Mast feet at the local waterline Z=0. Hull/deck integration must preserve `base_local` and `deck_points` from validation.
- Rigging is actual 3D round tube geometry following Bézier curves; spars have cylinder caps and exact end coordinates.
- Sail cloth is subdivided and non-planar, with normal-directed billow that vanishes at supported corners. Rips on SC-15 remove topology rather than painting fake damage.
- Fixed true orthographic projection; **55° elevation**, **0° roll**, same image scale across all ships, fixed lights not parented to model.
- All headings update `ShipRigRoot.rotation.z` only. For canonical SeaCraft screen angles, a projected 45° diagonal requires the documented elevation-aware heading yaw, not an arbitrary 45° world rotation.
- SC-11 retains the middle clear-zone for its separate A-frame crane; it is not created in this rig-only pipeline. SC-15 has two sound masts and one bare broken stump.
- The reference images are not final hull-integrated game sprites. The 3D armatures intentionally have no boat hull or 2D normalizing/ShowLook passes.

**License/dependency:** Three.js is the MIT open-source package fetched from the package registry/CDN and not embedded in this repository. The CPU reference renderer depends on Pillow, NumPy, OpenCV and Trimesh.
