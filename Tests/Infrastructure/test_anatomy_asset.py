"""Verify the committed licensed asset package and conversion provenance, not Apple rendering."""
from pathlib import Path
import hashlib, json, struct, unittest, zipfile

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "ASCEND/Resources/Anatomy"

class AnatomyPackageTests(unittest.TestCase):
    def test_usdz_is_uncompressed_aligned_and_matches_provenance(self):
        manifest = json.loads((FOLDER / "manifest.json").read_text(encoding="utf-8"))
        asset = FOLDER / "AscendMuscles.usdz"
        self.assertEqual(hashlib.sha256(asset.read_bytes()).hexdigest(), manifest["assetSHA256"])
        self.assertEqual(asset.stat().st_size, manifest["assetBytes"])
        self.assertLess(asset.stat().st_size, 15_000_000)
        self.assertLess(manifest["outputTriangles"], 450_000)
        self.assertGreater(manifest["outputTriangles"], 100_000)
        self.assertEqual(manifest["upAxis"], "Y")
        with zipfile.ZipFile(asset) as archive, asset.open("rb") as raw:
            self.assertGreater(len(archive.infolist()), 0)
            self.assertTrue(archive.infolist()[0].filename.endswith((".usd", ".usdc")))
            for item in archive.infolist():
                self.assertEqual(item.compress_type, zipfile.ZIP_STORED)
                raw.seek(item.header_offset + 26)
                name_len, extra_len = struct.unpack("<HH", raw.read(4))
                self.assertEqual((item.header_offset + 30 + name_len + extra_len) % 64, 0)
                self.assertFalse(".." in Path(item.filename).parts)
            self.assertTrue(archive.read(archive.infolist()[0])[:8].startswith(b"PXR-USDC"))
    def test_source_attribution_and_mapping_are_preserved(self):
        manifest = json.loads((FOLDER / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["commit"], "6c7f9016bd5899ac8edafd31b9900c151df42ed6")
        self.assertIn("BodyParts3D", (FOLDER / "SOURCE-LICENSE.txt").read_text(encoding="utf-8"))
        self.assertIn("ShareAlike", (FOLDER / "LICENSE.txt").read_text(encoding="utf-8"))
        meshes = manifest["meshes"]
        self.assertEqual(len(meshes), manifest["includedMeshes"])
        self.assertEqual(len({x["entity"] for x in meshes}), len(meshes))
        for mesh in meshes:
            self.assertGreater(mesh["triangles"], 0)
            if "hallucis" in mesh["sourceName"].lower() or "pollicis" in mesh["sourceName"].lower():
                self.assertNotIn("adductors", mesh["muscles"])

if __name__ == "__main__": unittest.main()
