import json,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parent.parent;ref=json.loads((root/'engine-reference.json').read_text())
url='https://raw.githubusercontent.com/midoali250/bitvault-engine/'+ref['commit']+'/engine/cores/registry.json'
with urllib.request.urlopen(url,timeout=30) as f:registry=json.load(f)
rows=[x for x in registry['cores'] if x['system']=='NES'];assert len(rows)==1 and rows[0]['repository']=='libretro/libretro-fceumm' and rows[0]['revision']=='e0f3086a8104f8fbbe49a2615b10401504a9533f'
print('BitVault Engine pinned NES core registry verified')
