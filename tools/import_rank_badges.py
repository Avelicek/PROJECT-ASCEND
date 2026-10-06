#!/usr/bin/env python3
"""Import the owner's original PNG bytes under stable rank asset names."""
from pathlib import Path
import hashlib, json, shutil, struct, zlib

ROOT = Path(__file__).resolve().parents[1]

def validate_png(path):
    data = Path(path).read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n': raise ValueError(f'Not a PNG: {path}')
    cursor = 8
    dimensions = None
    ended = False
    while cursor + 12 <= len(data):
        length = struct.unpack('>I', data[cursor:cursor+4])[0]
        kind = data[cursor+4:cursor+8]
        payload = data[cursor+8:cursor+8+length]
        end = cursor + 12 + length
        if end > len(data): raise ValueError(f'Truncated PNG: {path}')
        checksum = struct.unpack('>I', data[end-4:end])[0]
        if zlib.crc32(kind + payload) & 0xffffffff != checksum: raise ValueError(f'PNG checksum mismatch: {path}')
        if kind == b'IHDR': dimensions = struct.unpack('>II', payload[:8])
        if kind == b'IEND': ended = True; break
        cursor = end
    if not ended or not dimensions or min(dimensions) < 128: raise ValueError(f'Invalid badge image: {path}')
    return dimensions

def import_badges(root=ROOT):
    root = Path(root).resolve()
    mapping = json.loads((root/'tools/rank_badges.json').read_text(encoding='utf-8'))
    lock_path = root/'tools/rank_badges.lock.json'
    lock = json.loads(lock_path.read_text(encoding='utf-8')) if lock_path.exists() else None
    if lock is not None and set(lock) != set(mapping): raise ValueError('Badge lock does not match manifest')
    sources = []
    for asset, filename in mapping.items():
        if not asset.startswith('rank_') or not asset.replace('_', '').isalnum(): raise ValueError('Invalid asset name')
        source = (root/'ASCEND/Resources/RankBadges'/filename).resolve()
        if not source.is_relative_to(root/'ASCEND/Resources/RankBadges'): raise ValueError('Badge path escapes source directory')
        dimensions = validate_png(source)
        if lock is not None:
            entry = lock[asset]
            if entry['source'] != filename or entry['sha256'] != hashlib.sha256(source.read_bytes()).hexdigest():
                raise ValueError(f'Badge artwork differs from audited mapping: {filename}')
        sources.append((asset, source, dimensions))
    for asset, source, dimensions in sources:
        target = root/'ASCEND/Resources/Assets.xcassets'/f'{asset}.imageset'
        target.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target/'badge.png')
        metadata = {'images':[{'filename':'badge.png', 'idiom':'universal', 'scale':'1x'}],
                    'info':{'author':'xcode','version':1}, 'properties':{'template-rendering-intent':'original'}}
        (target/'Contents.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
        print(f'{source.name} -> {asset} ({dimensions[0]}x{dimensions[1]}, original bytes)')
    return len(sources)

if __name__ == '__main__': import_badges()
