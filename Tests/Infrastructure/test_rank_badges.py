"""Owner artwork packaging and fail-before-write import checks."""
from pathlib import Path
import contextlib
import hashlib
import io
import json
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from import_rank_badges import import_badges, validate_png


class RankBadgePackagingTests(unittest.TestCase):
    def test_all_owner_files_match_stable_assets_byte_for_byte(self):
        mapping = json.loads((ROOT / 'tools/rank_badges.json').read_text())
        expected = {
            'rank_bronze_1': 'bronze (1).png', 'rank_bronze_2': 'bronze (2).png', 'rank_bronze_3': 'bronze (3).png',
            'rank_silver_1': 'silver (1).png', 'rank_silver_2': 'silver (2).png', 'rank_silver_3': 'silver (3).png',
            'rank_gold_1': 'gold (1).png', 'rank_gold_2': 'gold (2).png', 'rank_gold_3': 'gold (3).png',
            'rank_platinum_1': 'plat (1).png', 'rank_platinum_2': 'plat (2).png', 'rank_platinum_3': 'plat (3).png',
            'rank_diamond_1': 'diamond (1).png', 'rank_diamond_2': 'diamond (2).png', 'rank_diamond_3': 'diamond (3).png',
            'rank_conqueror_1': 'conq1.png', 'rank_conqueror_2': 'conq2.png', 'rank_conqueror_3': 'conq3.png'
        }
        self.assertEqual(mapping, expected)
        self.assertEqual(len(set(mapping.values())), 18)
        lock = json.loads((ROOT / 'tools/rank_badges.lock.json').read_text())
        self.assertEqual(set(lock), set(expected))
        resolver = (ROOT / 'ASCEND/Resources/RankBadgeAsset.swift').read_text()
        for asset, filename in mapping.items():
            with self.subTest(asset=asset):
                original = ROOT / 'ASCEND/Resources/RankBadges' / filename
                imageset = ROOT / 'ASCEND/Resources/Assets.xcassets' / f'{asset}.imageset'
                self.assertEqual(validate_png(original), (1254, 1254))
                self.assertEqual(hashlib.sha256(original.read_bytes()).digest(), hashlib.sha256((imageset / 'badge.png').read_bytes()).digest())
                self.assertIn(f'"{asset}"', resolver)
                self.assertIn(f'"{filename}"', resolver)
                self.assertEqual(lock[asset]['source'], filename)
                self.assertEqual(lock[asset]['sha256'], hashlib.sha256(original.read_bytes()).hexdigest())
                metadata = json.loads((imageset / 'Contents.json').read_text())
                self.assertEqual(metadata['properties']['template-rendering-intent'], 'original')
                self.assertEqual(metadata['images'][0]['filename'], 'badge.png')
        self.assertEqual(mapping['rank_platinum_2'], 'plat (2).png')
        self.assertEqual(mapping['rank_conqueror_3'], 'conq3.png')

    def test_platinum_artwork_has_audited_two_and_three_spire_identities(self):
        # These identities were visually audited; re-generating the lock cannot mask a swap.
        identities = {
            'plat (2).png': 'a47539b45373c66788c8013b38ac28d296aa3dcc1c75c1b5d2b9e5e51cec6951',
            'plat (3).png': '0f5913595734b50c5f9f37661b6a2cb66f708f6d8aaaa5cc8f8cb2f6dca77c45'
        }
        for filename, digest in identities.items():
            self.assertEqual(hashlib.sha256((ROOT / 'ASCEND/Resources/RankBadges' / filename).read_bytes()).hexdigest(), digest)

    def test_artwork_lock_mismatch_fails_before_writing_catalog(self):
        with tempfile.TemporaryDirectory(prefix='ascend-lock-') as temporary:
            root = Path(temporary)
            (root / 'tools').mkdir()
            sources = root / 'ASCEND/Resources/RankBadges'
            sources.mkdir(parents=True)
            filename = 'plat (2).png'
            (sources / filename).write_bytes((ROOT / 'ASCEND/Resources/RankBadges/plat (3).png').read_bytes())
            (root / 'tools/rank_badges.json').write_text(json.dumps({'rank_platinum_2': filename}))
            (root / 'tools/rank_badges.lock.json').write_text(json.dumps({'rank_platinum_2': {'source': filename, 'sha256': 'a47539b45373c66788c8013b38ac28d296aa3dcc1c75c1b5d2b9e5e51cec6951'}}))
            with self.assertRaisesRegex(ValueError, 'audited mapping'):
                import_badges(root)
            self.assertFalse((root / 'ASCEND/Resources/Assets.xcassets').exists())

    def test_invalid_second_source_does_not_partially_overwrite_assets(self):
        with tempfile.TemporaryDirectory(prefix='ascend-badges-') as temporary:
            root = Path(temporary)
            (root / 'tools').mkdir()
            sources = root / 'ASCEND/Resources/RankBadges'
            sources.mkdir(parents=True)
            (sources / 'valid.png').write_bytes((ROOT / 'ASCEND/Resources/RankBadges/bronze (1).png').read_bytes())
            (sources / 'broken.png').write_bytes(b'broken PNG')
            (root / 'tools/rank_badges.json').write_text(json.dumps({'rank_bronze_1': 'valid.png', 'rank_bronze_2': 'broken.png'}))
            with self.assertRaises(ValueError), contextlib.redirect_stdout(io.StringIO()):
                import_badges(root)
            self.assertFalse((root / 'ASCEND/Resources/Assets.xcassets').exists())

    def test_corrupt_chunk_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='ascend-png-') as temporary:
            data = bytearray((ROOT / 'ASCEND/Resources/RankBadges/conq1.png').read_bytes())
            data[20] ^= 1
            path = Path(temporary) / 'corrupt.png'
            path.write_bytes(data)
            with self.assertRaisesRegex(ValueError, 'checksum'):
                validate_png(path)
