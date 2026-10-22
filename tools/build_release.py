from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'MANIFEST.json').read_text())
addon=root/manifest['name']
actual={p.relative_to(addon).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in addon.rglob('*') if p.is_file()}
assert actual==manifest['files'],'Payload differs from MANIFEST.json; update manifest intentionally after review.'
out=root/'dist';out.mkdir(exist_ok=True)
archive=out/('Powder-'+manifest['version']+'.zip')
docs=['README.md','INSTALL.md','CHANGELOG.md','THIRD_PARTY_NOTICES.txt','Install.ps1','MANIFEST.json','VALIDATION.md']
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for name in docs:z.write(root/name,name)
    for rel in sorted(actual):z.write(addon/rel,manifest['name']+'/'+rel)
assert zipfile.ZipFile(archive).testzip() is None
archive.with_suffix(archive.suffix+'.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n')
print(archive)
