from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parents[1]
BUILD = ROOT/"build/windows_2026-10-22"
PACKAGE = BUILD/"package"
record = HERE/"records/export_result.json"
info = json.loads(record.read_text())
info["native_macOS_pack_check"] = json.loads((HERE/"records/pack_window.json").read_text())
assert not info["native_macOS_pack_check"]["failures"]
assert json.loads((HERE/"records/cleanup_result.json").read_text())["committed_files_unchanged"]
(PACKAGE/"BUILD_INFO.json").write_text(json.dumps(info,ensure_ascii=False,indent=2)+"\n")
archive = BUILD/"诸界余烬_Windows_x86_64_2026-10-22.zip"
files = sorted(p for p in PACKAGE.rglob("*") if p.is_file())
prefix = "ZhujieYujin-Windows-x86_64/"
with zipfile.ZipFile(archive,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    for path in files: output.write(path,prefix+str(path.relative_to(PACKAGE)))
with zipfile.ZipFile(archive) as output:
    assert output.testzip() is None
    assert len(output.namelist()) == len(files)
    for name,metadata in info["files"].items():
        with output.open(prefix+name) as stream: checksum=hashlib.file_digest(stream,"sha256").hexdigest()
        assert checksum==metadata["sha256"],name
with archive.open("rb") as stream: checksum=hashlib.file_digest(stream,"sha256").hexdigest()
info["zip"] = {"path":str(archive.relative_to(ROOT)),"bytes":archive.stat().st_size,"sha256":checksum,"members":len(files),"crc_all_members_valid":True,"runtime_member_hashes_match":True}
record.write_text(json.dumps(info,ensure_ascii=False,indent=2)+"\n")
(BUILD/"SHA256SUMS.txt").write_text(checksum+"  "+archive.name+"\n")
print("ZIP VERIFIED",archive,archive.stat().st_size,checksum)
