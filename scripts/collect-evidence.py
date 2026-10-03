#!/usr/bin/env python3
"""Collect reproducible local build/test provenance without user paths/device IDs."""
import argparse, datetime, hashlib, json, os, plistlib, re, shutil, subprocess
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('stage');parser.add_argument('--test-log',required=True);parser.add_argument('--release-log',required=True)
parser.add_argument('--qa-app',action='append',default=[]);parser.add_argument('--artifact',action='append',default=[])
args=parser.parse_args();repo=Path(__file__).resolve().parent.parent
build_root=Path.home()/'Library/Developer/PhotoAxisBuilds'/hashlib.sha256(str(repo).encode()).hexdigest()[:12]
app=build_root/'DerivedData/Build/Products/Release/PhotoAxis.app'
evidence=repo/'docs/bao-cao/bang-chung'/args.stage;evidence.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
def run(command):
 result=subprocess.run(command,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 if result.returncode: raise RuntimeError(f'{command[0]} failed: {result.stdout}')
 return result.stdout
log=Path(args.test_log).read_text();result=Path(re.findall(r'^Test result: (.+)$',log,re.M)[-1])
summary=json.loads(run(['xcrun','xcresulttool','get','test-results','summary','--path',str(result)]))
ids=[]
for item in summary.get('devicesAndConfigurations',[]):
 value=item.get('device',{}).pop('deviceId',None)
 if value:ids.append(value)
def clean(value):
 value=value.replace(str(repo).replace(' ','%20'),'$REPO').replace(str(repo),'$REPO').replace(str(build_root),'$BUILD_ROOT').replace(str(Path.home()),'$HOME')
 for item in ids:value=value.replace(item,'<DEVICE_ID>')
 value=re.sub(r'/var/folders/[^\s]+','<TEMP_PATH>',value)
 return '\n'.join(line.rstrip() for line in value.splitlines())+'\n'
for source,name in [(args.test_log,'debug-test.log'),(args.release_log,'release-build.log')]:
 (evidence/name).write_text(clean(Path(source).read_text()))
(evidence/'test-summary.json').write_text(clean(json.dumps(summary,ensure_ascii=False,indent=2)))
checks=[]
for script in ['generate-project.py','check-localization.py']:
 output=run(['python3',str(repo/'scripts'/script)]+(['--check'] if script.startswith('generate') else []))
 checks.append(output);(evidence/(script.replace('.py','')+'.log')).write_text(clean(output))
binary=app/'Contents/MacOS/PhotoAxis';uuid=run(['xcrun','dwarfdump','--uuid',str(binary)]).split()[1]
core=app/'Contents/Frameworks/PhotoAxisCore.framework/Versions/A/PhotoAxisCore'
core_hash=hashlib.sha256(core.read_bytes()).hexdigest()
commands=[['codesign','--verify','--deep','--strict',str(app)],['codesign','-dv','--verbose=4',str(app)],['file',str(binary)],['xcrun','vtool','-show-build',str(binary)],['xcrun','dwarfdump','--uuid',str(binary)]]
qa=[]
for path_string in args.qa_app:
 path=Path(path_string);qa_binary=path/'Contents/MacOS/PhotoAxis'
 qa_uuid=run(['xcrun','dwarfdump','--uuid',str(qa_binary)]).split()[1]
 commands.append(['codesign','--verify','--deep','--strict',str(path)])
 qa_core=path/'Contents/Frameworks/PhotoAxisCore.framework/Versions/A/PhotoAxisCore'
 qa_core_hash=hashlib.sha256(qa_core.read_bytes()).hexdigest()
 qa.append(dict(path=str(path),uuid=qa_uuid,sha256=hashlib.sha256(qa_binary.read_bytes()).hexdigest(),coreFrameworkSHA256=qa_core_hash,matchesReleaseCore=qa_core_hash==core_hash,matchesReleaseUUID=qa_uuid==uuid))
(evidence/'binary-verification.log').write_text(''.join(clean('$ '+' '.join(c)+'\n'+run(c)) for c in commands))
for source in args.artifact:shutil.copy2(source,evidence/Path(source).name)
paths=sorted(p.relative_to(repo).as_posix() for folder in ['Sources','Tests','Config','scripts','PhotoAxis.xcodeproj','.github','Fixtures'] for p in (repo/folder).rglob('*') if p.is_file() and not any(x in p.parts for x in ['xcuserdata','__pycache__']))
fingerprint=hashlib.sha256()
for path in paths:fingerprint.update(path.encode()+b'\0'+(repo/path).read_bytes()+b'\0')
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
manifest=dict(stage=args.stage,specification='1.0-draft.3',createdAt=datetime.datetime.now().astimezone().isoformat(),parentCommit=run(['git','rev-parse','HEAD']).strip(),sourceFingerprintSHA256=fingerprint.hexdigest(),fingerprintAlgorithm='SHA256 of relative UTF-8 path + NUL + file bytes + NUL in sourceFiles order',sourceFiles=paths,appVersion=info['CFBundleShortVersionString'],build=info['CFBundleVersion'],releaseBinaryUUID=uuid,binarySHA256=hashlib.sha256(binary.read_bytes()).hexdigest(),architecture='arm64',minimumOS=info['LSMinimumSystemVersion'],appPath=str(app),qaApps=qa,testResult=str(result),testsPassed=summary['passedTests'],testsFailed=summary['failedTests'],testsSkipped=summary['skippedTests'],runtimeWarnings=summary.get('runtimeWarnings',[]),hostOS=run(['sw_vers','-productVersion']).strip(),chip=run(['sysctl','-n','machdep.cpu.brand_string']).strip(),ramBytes=int(run(['sysctl','-n','hw.memsize']).strip()),xcode=run(['xcodebuild','-version']).strip(),signing='local ad-hoc only',hardenedRuntime=False,evidenceSHA256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(evidence.iterdir()) if p.is_file() and p.name!='build-manifest.json'})
manifest['coreFrameworkSHA256']=core_hash
(evidence/'build-manifest.json').write_text(clean(json.dumps(manifest,ensure_ascii=False,indent=2)))
print(f"{args.stage}: {summary['passedTests']} PASS / {summary['failedTests']} FAIL / {summary['skippedTests']} SKIP; UUID {uuid}")
print('Source fingerprint:',fingerprint.hexdigest())
