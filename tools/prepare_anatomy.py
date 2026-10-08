# SPDX-License-Identifier: CC-BY-SA-4.0
"""Reproducible Z-Anatomy muscle-only USDZ conversion. Requires Blender's bpy wheel.
Raw downloads/runtime stay outside the checkout. Derived assets: CC BY-SA 4.0.
Example: python tools/prepare_anatomy.py --source-folder C:/AnatomySource --runtime C:/AnatomySource/runtime --download
"""
from pathlib import Path
import argparse, hashlib, json, re, sys, urllib.request

COMMIT = "6c7f9016bd5899ac8edafd31b9900c151df42ed6"
BASE = f"https://raw.githubusercontent.com/LluisV/Z-Anatomy/{COMMIT}/Resources/Models/"
SHA256 = "4c19df534d5d84aabbce08604306aa0485b43e8a2483c72a95b569e1dfea2279"
ROOT = Path(__file__).resolve().parents[1]

def muscles(name):
    n = name.lower()
    if "pectoralis major" in n:
        return ["upperPectoral"] if "clavicular" in n else ["lowerPectoral"] if "abdominal" in n else ["midPectoral"]
    pairs = [
        ("clavicular part of deltoid", ["anteriorDeltoid"]), ("acromial part of deltoid", ["lateralDeltoid"]), ("scapular spinal part of deltoid", ["posteriorDeltoid"]),
        ("long head of biceps brachii", ["bicepsLongHead"]), ("short head of biceps brachii", ["bicepsShortHead"]), ("brachialis muscle", ["brachialis"]),
        ("long head of triceps", ["tricepsLongHead"]), ("lateral head of triceps", ["tricepsLateralHead"]), ("medial head of triceps", ["tricepsMedialHead"]),
        ("latissimus", ["latissimus"]), ("rhomboid", ["rhomboids"]), ("serratus anterior", ["serratusAnterior"]),
        ("descending part of trapezius", ["upperTrapezius"]), ("transverse part of trapezius", ["middleTrapezius"]), ("ascending part of trapezius", ["lowerTrapezius"]),
        ("rectus abdominis", ["rectusAbdominis"]), ("abdominal oblique", ["obliques"]), ("transversus abdominis", ["transverseAbdominis"]),
        ("iliocostalis lumborum", ["spinalErectors"]), ("iliocostalis thoracis", ["spinalErectors"]), ("longissimus thoracis", ["spinalErectors"]), ("spinalis thoracis", ["spinalErectors"]),
        ("gluteus maximus", ["gluteusMaximus"]), ("gluteus medius", ["gluteusMedius"]), ("gluteus minimus", ["gluteusMinimus"]),
        ("rectus femoris", ["rectusFemoris"]), ("vastus lateralis", ["vastusLateralis"]), ("vastus medialis", ["vastusMedialis"]), ("vastus intermedius", ["vastusIntermedius"]),
        ("biceps femoris", ["bicepsFemoris"]), ("semitendinosus muscle", ["semitendinosus"]), ("semimembranosus muscle", ["semimembranosus"]),
        ("gastrocnemius", ["gastrocnemius"]), ("soleus muscle", ["soleus"]), ("tibialis anterior", ["tibialisAnterior"]),
        ("flexor carpi", ["forearmFlexors"]), ("flexor digitorum superficialis", ["forearmFlexors"]), ("flexor digitorum profundus", ["forearmFlexors"]), ("extensor carpi", ["forearmExtensors"]), ("extensor digitorum muscle", ["forearmExtensors"]),
        ("psoas major", ["hipFlexors"]), ("iliacus", ["hipFlexors"]), ("adductor brevis", ["adductors"]), ("adductor longus", ["adductors"]), ("adductor magnus", ["adductors"]), ("adductor minimus", ["adductors"]),
    ]
    for phrase, result in pairs:
        if phrase in n and not (phrase == "brachialis muscle" and "coracobrachialis" in n): return result
    return []

def main():
    parser = argparse.ArgumentParser(); parser.add_argument("--source-folder", type=Path, required=True); parser.add_argument("--runtime", type=Path); parser.add_argument("--download", action="store_true"); parser.add_argument("--preview", action="store_true")
    args = parser.parse_args(); folder = args.source_folder.resolve()
    if folder.is_relative_to(ROOT): raise SystemExit("Raw anatomy sources must be outside the checkout.")
    folder.mkdir(parents=True, exist_ok=True)
    source = folder / "MuscularSystem100.fbx"
    if args.download:
        urllib.request.urlretrieve(BASE + "FBX/MuscularSystem100.fbx", source)
        urllib.request.urlretrieve(BASE + "License.txt", folder / "SOURCE-LICENSE.txt")
    if hashlib.sha256(source.read_bytes()).hexdigest() != SHA256: raise SystemExit("Source checksum mismatch")
    if args.runtime: sys.path.insert(0, str(args.runtime.resolve()))
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(source))
    excluded = re.compile(r"bursa|fascia|tendon|septum|aponeuros|ligament|retinacul|sheath|tendinous|raphe|membrane|synovial|iliotibial tract|tarsus|trochlea", re.I)
    selected = sorted((x for x in bpy.data.objects if x.type == "MESH" and len(x.data.polygons) > 0 and not excluded.search(x.name)), key=lambda x: x.name)
    for obj in bpy.data.objects: obj.select_set(False)
    mappings = []; input_triangles = 0; output_triangles = 0
    # Preserve independent anatomical meshes and their original world-space shape.
    # A shared material removes hundreds of redundant source materials/textures.
    material = bpy.data.materials.new("GraphiteMuscle"); material.diffuse_color = (0.17, 0.20, 0.25, 1)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF"); bsdf.inputs["Base Color"].default_value = material.diffuse_color; bsdf.inputs["Roughness"].default_value = 0.65; bsdf.inputs["Metallic"].default_value = 0.12
    for index, obj in enumerate(selected):
        obj.data = obj.data.copy()
        original = obj.name; obj.name = f"muscle_{index:04d}"; obj.select_set(True); bpy.context.view_layer.objects.active = obj
        obj.data.calc_loop_triangles(); before = len(obj.data.loop_triangles); input_triangles += before
        if before > 500:
            modifier = obj.modifiers.new("V1 mobile surface reduction", "DECIMATE"); modifier.ratio = max(0.18, 180 / before)
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.data.calc_loop_triangles(); output_triangles += len(obj.data.loop_triangles)
        obj.data.materials.clear(); obj.data.materials.append(material)
        for slot in obj.material_slots: slot.link = "DATA"; slot.material = material
        for polygon in obj.data.polygons: polygon.use_smooth = True
        mappings.append({"entity": obj.name, "sourceName": original, "muscles": muscles(original), "vertices": len(obj.data.vertices), "triangles": len(obj.data.loop_triangles)})
    points = [obj.matrix_world @ Vector(corner) for obj in selected for corner in obj.bound_box]
    low = [min(p[i] for p in points) for i in range(3)]; high = [max(p[i] for p in points) for i in range(3)]
    dest = ROOT / "ASCEND/Resources/Anatomy"; dest.mkdir(parents=True, exist_ok=True)
    # Blender's USD exporter packages a valid aligned USDZ, with transforms baked by importer.
    bpy.ops.wm.usd_export(filepath=str(dest / "AscendMuscles.usdz"), selected_objects_only=True, export_materials=True, convert_orientation=True, export_global_up_selection="Y", export_global_forward_selection="NEGATIVE_Z")
    manifest = {"source": "LluisV/Z-Anatomy", "commit": COMMIT, "sourceSHA256": SHA256, "license": "CC BY-SA 4.0 (BodyParts3D attribution retained)", "converter": bpy.app.version_string, "sourceMeshes": 686, "includedMeshes": len(selected), "inputTriangles": input_triangles, "outputTriangles": output_triangles, "bounds": {"min": low, "max": high}, "upAxis": "Y", "assetBytes": (dest / "AscendMuscles.usdz").stat().st_size, "assetSHA256": hashlib.sha256((dest / "AscendMuscles.usdz").read_bytes()).hexdigest(), "meshes": mappings}
    (dest / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    (dest / "SOURCE-LICENSE.txt").write_bytes((folder / "SOURCE-LICENSE.txt").read_bytes())
    lines = ["// SPDX-License-Identifier: CC-BY-SA-4.0", "// Generated by tools/prepare_anatomy.py from the pinned source mesh names.", "import Foundation", "public enum AnatomyMeshMapping {", "    public static let muscles: [String: [Muscle]] = ["]
    lines += [f'        "{row["entity"]}": [{", ".join("." + x for x in row["muscles"])}],' for row in mappings if row["muscles"]]
    lines += ["    ]", "    public static let sourceNames: [String: String] = ["] + [f'        "{row["entity"]}": {json.dumps(row["sourceName"])},' for row in mappings] + ["    ]", "}"]
    (ROOT / "ASCEND/Core/Domain/AnatomyMeshMapping.swift").write_text("\n".join(lines) + "\n", encoding="utf-8")
    if args.preview:
        # Source-derived asset QA, not a simulator screenshot or Apple-rendering claim.
        import math
        selected_ids = {obj.name for obj in selected}
        for obj in bpy.data.objects:
            if obj.type == "MESH" and obj.name not in selected_ids: obj.hide_render = True
        scene = bpy.context.scene; scene.render.engine = "CYCLES"; scene.cycles.samples = 16; scene.cycles.device = "CPU"
        scene.render.resolution_x = 600; scene.render.resolution_y = 900; scene.render.resolution_percentage = 100
        scene.world = bpy.data.worlds.new("Dark studio"); scene.world.use_nodes = True
        scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.018, 0.024, 0.04, 1)
        camera_data = bpy.data.cameras.new("Asset QA"); camera = bpy.data.objects.new("Asset QA", camera_data); scene.collection.objects.link(camera); scene.camera = camera
        camera_data.type = "ORTHO"; camera_data.ortho_scale = 2.15
        for name, position in [("key", (2, -3, 3)), ("fill", (-2, 2, 2))]:
            light_data = bpy.data.lights.new(name, "AREA"); light_data.energy = 500; light_data.shape = "DISK"; light_data.size = 3
            light = bpy.data.objects.new(name, light_data); scene.collection.objects.link(light); light.location = position; light.rotation_euler = (Vector((0, 0, 0.85)) - light.location).to_track_quat("-Z", "Y").to_euler()
        for name, position in [("front", (0, -4, 0.85)), ("back", (0, 4, 0.85)), ("side", (4, 0, 0.85))]:
            camera.location = position; camera.rotation_euler = (Vector((0, 0, 0.85)) - camera.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(folder / ("asset-qa-" + name + ".png")); bpy.ops.render.render(write_still=True)
    print(json.dumps({key: manifest[key] for key in ["includedMeshes", "inputTriangles", "outputTriangles", "assetBytes", "bounds"]}, indent=2))

if __name__ == "__main__": main()
