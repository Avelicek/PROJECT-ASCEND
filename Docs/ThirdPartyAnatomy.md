# ASCEND V1 anatomy provenance and license

ASCEND bundles a real anatomical muscle model from Z-Anatomy, derived from BodyParts3D. It is loaded with native RealityKit in a non-AR `ARView`. It is not a generated illustration, primitive mannequin or replacement for biological measurements.

## Source and permitted use

- Repository: [LluisV/Z-Anatomy](https://github.com/LluisV/Z-Anatomy/tree/6c7f9016bd5899ac8edafd31b9900c151df42ed6/Resources/Models).
- Pinned commit: `6c7f9016bd5899ac8edafd31b9900c151df42ed6`.
- Source file: `Resources/Models/FBX/MuscularSystem100.fbx`, 37,343,180 bytes.
- Source SHA-256: `4c19df534d5d84aabbce08604306aa0485b43e8a2483c72a95b569e1dfea2279`.
- Required upstream attribution: **BodyParts3D - The Database Center for Life Science - CC-BY-SA 2.1 Japan** and **Z-Anatomy - The open source atlas of anatomy - CC-BY-SA 4.0**.
- Original model: Kousaku Okubo; anatomy/model design: Gauthier Kervyn; source distribution: Lluis Vinent. [Upstream project/license](https://github.com/Z-Anatomy/Models-of-human-anatomy).
- Retain `ASCEND/Resources/Anatomy/SOURCE-LICENSE.txt` verbatim and the full `LICENSE.txt`. The notice includes other atlas systems; ASCEND imports only the muscle FBX, without kidney, inner-ear, cranial-nerve or brain models listed separately in that notice.
- ASCEND's derived USDZ, manifest, mapping and conversion script are **CC BY-SA 4.0**. Changes: muscle-only selection, removal of connective-tissue/guides, geometry reduction, shared graphite material, stable identifiers and Y-up conversion. Preserve attribution and share-alike terms whenever redistributing those derived files. This notice covers those assets/files, not independently authored app source.
- Attribution and license links are also accessible in Profile → System → Data. [License terms](https://creativecommons.org/licenses/by-sa/4.0/).

## Final package

| Property | Value |
|---|---|
| USDZ | `ASCEND/Resources/Anatomy/AscendMuscles.usdz` |
| Exact size | 8,186,398 bytes (about 7.81 MiB) |
| SHA-256 | `38f91423a4c23857bdfee61885b6f3f4ddb6dc545fbf799859a30b1fdc486f30` |
| Retained anatomical meshes | 463 |
| Triangles before/after reduction | 1,819,652 / 345,735 |
| Exporter | Blender bpy 5.2.2 LTS |
| Orientation | Y-up; negative-Z forward conversion |
| Textures | None |

The source contains 686 mesh objects. Bursae, fascia, tendons, guide sections and other connective structures are excluded; independent anatomical muscle surfaces remain. `manifest.json` records every original name, stable entity name, logical muscle mapping and triangle count. Head/neck/hand/foot structures without an engine group remain neutral and cannot fabricate a fitness estimate.

`AnatomyMeshMapping` joins multiple visual meshes to established logical `Muscle` values. Engines and workout history do not depend on raw asset node names. Mapping covers the major pectoral, back, deltoid, arm, core, lumbar, gluteal, thigh and calf groups. Distinguishing forearm from foot flexors and thigh from hand adductors is explicit in the converter.

## Reproduce without checkout pollution

Use Python and a compatible Blender `bpy` wheel in an external folder, for example:

```powershell
python -m pip install --target C:\AnatomySource\runtime bpy==5.2.2
python tools/prepare_anatomy.py --source-folder C:\AnatomySource --runtime C:\AnatomySource\runtime --download --preview
```

The script rejects raw-source folders inside the checkout and verifies the pinned FBX checksum before import. Raw FBX, bpy runtime and CPU preview PNGs remain outside Git. Exported geometry is repeatable, but Blender packaging metadata can change the byte checksum; review any regenerated manifest and asset together. The checked-in full license must remain packaged.

## Runtime and QA

Recovery offers explicit **Explore 3D anatomy**, front/back/side/reset, drag orbit, bounded pinch zoom and mapped-muscle selection. Recovery/load/fatigue materials use central semantic tokens and actual deterministic reports; unknown stays graphite. A material key avoids replacing unchanged materials; selection only changes affected surfaces. Only mapped objects receive collision shapes. Two simple lights, no textures, physics simulation, continuous model animation, motion blur, camera grain or grounding shadows.

The renderer exists only while its card is visible and the app is foreground. Removal cancels loading, removes entities/anchors and releases model references; leaving Recovery disables 3D. VoiceOver, normal snapshot mode and load failure use the existing accessible 2D anatomy and region list. One explicit Debug snapshot scenario exercises the actual native model.

Windows QA checked USDZ alignment, stored ZIP members, hashes, mapping and notices. Front/back/side CPU renders of the selected derived geometry were visually inspected for shape, hands/feet and orientation. Those are **asset QA**, not simulator images. RealityKit loading, native materials/camera, touch selection, hidden-view resource release, memory/frame cost and energy use still require Xcode CI and real-device Instruments. Geometry counts are a budget estimate, not a measured device-performance claim.
