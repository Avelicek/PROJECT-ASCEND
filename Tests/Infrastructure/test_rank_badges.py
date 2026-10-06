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
        expected = {f'rank_{tier}_{division}' for tier in ('bronze', 'silver', 'gold', 'platinum', 'diamond', 'conqueror') for division in (1, 2, 3)}
        self.assertEqual(set(mapping), expected)
        self.assertEqual(len(set(mapping.values())), 18)
        resolver = (ROOT / 'ASCEND/Resources/RankBadgeAsset.swift').read_text()
        for asset, filename in mapping.items():
            with self.subTest(asset=asset):
                original = ROOT / 'ASCEND/Resources/RankBadges' / filename
                imageset = ROOT / 'ASCEND/Resources/Assets.xcassets' / f'{asset}.imageset'
                self.assertEqual(validate_png(original), (1254, 1254))
                self.assertEqual(hashlib.sha256(original.read_bytes()).digest(), hashlib.sha256((imageset / 'badge.png').read_bytes()).digest())
                self.assertIn(f'"{asset}"', resolver)
                metadata = json.loads((imageset / 'Contents.json').read_text())
                self.assertEqual(metadata['properties']['template-rendering-intent'], 'original')
                self.assertEqual(metadata['images'][0]['filename'], 'badge.png')
        self.assertEqual(mapping['rank_platinum_2'], 'plat (2).png')
        self.assertEqual(mapping['rank_conqueror_3'], 'conq3.png')

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
