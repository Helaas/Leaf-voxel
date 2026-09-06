#!/usr/bin/env python3
"""Package only the mod source and notices; never include imported game data."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'manifest.json').read_text())
output = root / 'dist' / f"leaf-voxel-{manifest['version']}.zip"
output.parent.mkdir(exist_ok=True)
files = [root / name for name in ('main.lua', 'manifest.json', 'mod.card', 'LICENSE', 'CREDITS.md', 'README.md', 'HARDWARE.md')]
files += sorted((root / 'lib').glob('*.lua'))
files += sorted((root / 'data').glob('*.lua'))
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        info = zipfile.ZipInfo('LEAF_VOXEL/' + path.relative_to(root).as_posix())
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, path.read_bytes())
checksum = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix('.zip.sha256').write_text(f'{checksum}  {output.name}\n')
print(f'{output}\n{checksum}')
