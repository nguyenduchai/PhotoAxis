#!/usr/bin/env python3
"""P13 local packaging and gated Developer ID/notarization. Standard library only."""
import argparse, hashlib, json, os, plistlib, re, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = Path(os.environ.get('PHOTOAXIS_BUILD_ROOT', str(Path.home()/'Library/Developer/PhotoAxisBuilds'/hashlib.sha256(str(ROOT).encode()).hexdigest()[:12])))
ENV = dict(os.environ, DEVELOPER_DIR=os.environ.get('DEVELOPER_DIR','/Applications/Xcode.app/Contents/Developer'))
FIELDS = set(json.loads((ROOT/'Config/Distribution.example.json').read_text()))
SIGN_FIELDS = ['publisher','appBundleID','coreBundleID','documentUTI','teamID','developerIDIdentity','notaryKeychainProfile']
PUBLIC_FIELDS = sorted(FIELDS)
class GateError(RuntimeError): pass

def run(argv, log=None, stdout_only=False):
    result = subprocess.run([str(x) for x in argv],cwd=ROOT,env=ENV,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    if log is not None:
        text = (result.stdout+result.stderr).replace(str(BUILD),'$BUILD_ROOT').replace(str(ROOT),'$REPO').replace(str(Path.home()),'$HOME')
        with log.open('a') as f: f.write('$ '+str(argv[0])+' '+str(argv[1]).replace(str(BUILD),'$BUILD_ROOT').replace(str(ROOT),'$REPO').replace(str(Path.home()),'$HOME')+'\n'+text+'\n')
    if result.returncode: raise GateError(f'{argv[0]} {argv[1]} failed (exit {result.returncode}); inspect the external artifact log')
    return result.stdout if stdout_only else result.stdout+result.stderr

def config(path, public=False):
    values = json.loads(Path(path).read_text())
    if not isinstance(values,dict) or set(values) != FIELDS: raise GateError('Configuration must match Distribution.example.json; credentials/secrets are not accepted')
    missing = [k for k in (PUBLIC_FIELDS if public else SIGN_FIELDS) if not isinstance(values[k],str) or not values[k].strip()]
    if missing: raise GateError('Missing confirmed configuration: '+', '.join(missing))
    for key in ['appBundleID','coreBundleID','documentUTI']:
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+){2,}',values[key]) or values[key].startswith(('local.','com.example.')): raise GateError('Publisher-owned namespace required: '+key)
    if len({values[k] for k in ['appBundleID','coreBundleID','documentUTI']}) != 3: raise GateError('App, framework and document namespaces must differ')
    if not re.fullmatch(r'[A-Z0-9]{10}',values['teamID']): raise GateError('Invalid Team ID')
    if not values['developerIDIdentity'].startswith('Developer ID Application: ') or not values['developerIDIdentity'].endswith('('+values['teamID']+')'): raise GateError('Developer ID Application identity must match Team ID')
    if any('\n' in v or '\0' in v for v in values.values() if isinstance(v,str)): raise GateError('Control characters in configuration')
    if public:
        for key in ['sourceRepository','distributionRepository']:
            if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',values[key]): raise GateError('Invalid repository: '+key)
        if values['sourceVisibility'] not in ['public','private'] or values['distributionVisibility'] != 'public': raise GateError('Source visibility must be explicit; distribution must allow anonymous download')
        if values['sourceRepository']==values['distributionRepository'] and values['sourceVisibility']!='public': raise GateError('Private source needs a separately confirmed public distribution repository')
        for key in ['websiteURL','distributionTermsURL']:
            if not values[key].startswith('https://') or 'example.' in values[key]: raise GateError('Confirmed HTTPS URL required: '+key)
        if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+',values['supportEmail']): raise GateError('Support email required')
        if values['websiteDeployMode'] not in ['github-pages-artifact','existing-host']: raise GateError('Choose the existing host or a confirmed GitHub Pages artifact workflow')
        if not re.fullmatch(r'[A-Za-z0-9_.-]+',values['sourceRemoteName']): raise GateError('Invalid source remote name')
    return values

def require_candidate(path=ROOT/'docs/RELEASE_CANDIDATE.json'):
    rc = json.loads(Path(path).read_text())
    if rc.get('releaseReady') is not True: raise GateError('R02 is not accepted: RELEASE_CANDIDATE.releaseReady is false')
    sha = rc.get('sourceCommit','')
    if not re.fullmatch(r'[0-9a-f]{40}',sha): raise GateError('Candidate source commit missing')
    run(['git','merge-base','--is-ancestor',sha,'HEAD'])
    if run(['git','status','--porcelain']).strip(): raise GateError('Commit and verify checkout before distribution')
    if run(['git','diff',sha,'HEAD','--','Sources','Tests','Config','scripts','PhotoAxis.xcodeproj','.github','Fixtures']).strip(): raise GateError('Candidate source/config differs from checkout; re-accept the affected changes')
    return rc

def version_build():
    text=(ROOT/'Config/Base.xcconfig').read_text()
    version=re.search(r'^MARKETING_VERSION\s*=\s*(\d+\.\d+\.\d+)\s*$',text,re.M)
    build=re.search(r'^CURRENT_PROJECT_VERSION\s*=\s*(\d+)\s*$',text,re.M)
    if not version or not build: raise GateError('Version/build missing from Base.xcconfig')
    return version.group(1),build.group(1)

def app_info(app):
    info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    version,build=version_build()
    if info.get('CFBundleShortVersionString')!=version or info.get('CFBundleVersion')!=build or info.get('LSMinimumSystemVersion')!='14.0': raise GateError('Unexpected version/build/minimum OS')
    binary=app/'Contents/MacOS/PhotoAxis'
    if run(['lipo','-archs',binary]).strip()!='arm64': raise GateError('Binary must be arm64 only')
    if not (app/'Contents/Resources/PhotoAxis.icns').is_file(): raise GateError('App icon missing')
    if list(app.rglob('*.xctest')) or (app/'Contents/PlugIns').exists(): raise GateError('Test/plugin payload in app')
    return info

def tree_hash(root):
    digest=hashlib.sha256()
    for p in sorted(root.rglob('*')):
        name=p.relative_to(root).as_posix()
        if p.is_symlink(): payload=b'LINK\0'+os.readlink(p).encode()
        elif p.is_file(): payload=p.read_bytes()
        else: continue
        digest.update(name.encode()+b'\0'+payload+b'\0')
    return digest.hexdigest()

def distribution_documents(local):
    license_bytes=(ROOT/'LICENSE').read_bytes()
    if b'GNU GENERAL PUBLIC LICENSE' not in license_bytes or b'Version 3, 29 June 2007' not in license_bytes:
        raise GateError('GNU GPLv3 license text is required in the installer')
    commit=run(['git','rev-parse','HEAD']).strip()
    source=('PhotoAxis 1.0.0 (3)\nGNU GPL version 3 (GPL-3.0-only)\n'
            'Copyright (C) 2026 PhotoAxis contributors. No warranty.\n\n'
            'Corresponding source: https://github.com/nguyenduchai/PhotoAxis\n'
            'Packaging checkout: '+commit+'\n'
            'Build instructions: docs/HUONG_DAN_BUILD.md in the repository.\n\n')
    source += ('This LOCAL-UNSIGNED package is for local testing: ad-hoc signing,\n'
               'no Developer ID, no notarization or clean Gatekeeper acceptance.\n'
               'A final signed release will have its own manifest and checksum.\n' if local else
               'Refer to the distribution manifest for signing, notarization,\n'
               'checksum and installation acceptance evidence.\n')
    source=source.encode()
    return {'LICENSE.txt':license_bytes,'SOURCE.txt':source}

def inspect_dmg(dmg, expected_app, log):
    mount=Path(tempfile.mkdtemp(prefix='mount-',dir=dmg.parent)); attached=False
    try:
        data=run(['hdiutil','attach','-readonly','-nobrowse','-noautoopen','-mountpoint',mount,'-plist',dmg],log,stdout_only=True)
        attached=True
        info=plistlib.loads(data.encode())
        if not any(e.get('mount-point')==str(mount) for e in info.get('system-entities',[])): raise GateError('DMG did not mount at the isolated verification directory')
        documents=distribution_documents('-LOCAL-UNSIGNED' in dmg.name)
        if sorted(p.name for p in mount.iterdir() if not p.name.startswith('.'))!=sorted(['Applications','PhotoAxis.app',*documents]): raise GateError('Unexpected DMG payload')
        for name,expected_bytes in documents.items():
            if (mount/name).is_symlink() or (mount/name).read_bytes()!=expected_bytes: raise GateError('DMG license/source notice differs: '+name)
        if not (mount/'Applications').is_symlink() or os.readlink(mount/'Applications')!='/Applications': raise GateError('DMG Applications shortcut invalid')
        app_info(mount/'PhotoAxis.app')
        expected=tree_hash(expected_app); actual=tree_hash(mount/'PhotoAxis.app')
        if expected!=actual: raise GateError('Mounted app differs from checked app')
        run(['codesign','--verify','--deep','--strict',mount/'PhotoAxis.app'],log)
        return actual
    finally:
        if attached: run(['hdiutil','detach',mount],log)
        mount.rmdir()

def create_dmg(app, target, log):
    if target.exists(): raise GateError('Refusing to overwrite an existing artifact')
    with tempfile.TemporaryDirectory(prefix='photoaxis-dmg-',dir=target.parent) as directory:
        staging=Path(directory); run(['ditto',app,staging/'PhotoAxis.app'],log)
        (staging/'Applications').symlink_to('/Applications')
        for name,payload in distribution_documents('-LOCAL-UNSIGNED' in target.name).items(): (staging/name).write_bytes(payload)
        run(['hdiutil','create','-volname','PhotoAxis 1.0.0','-srcfolder',staging,'-format','UDZO','-fs','HFS+',target],log)

def notarize(artifact, profile, out, log):
    command=['xcrun','notarytool','submit',str(artifact),'--keychain-profile',profile,'--wait','--output-format','json']
    submitted=subprocess.run(command,cwd=ROOT,env=ENV,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    with log.open('a') as f: f.write('$ xcrun notarytool submit (Keychain profile)\n'+submitted.stdout+'\n'+submitted.stderr.replace(str(Path.home()),'$HOME')+'\n')
    try: result=json.loads(submitted.stdout)
    except ValueError as error: raise GateError('Notary submission did not return JSON; inspect external log') from error
    (out/(artifact.stem+'-submission.json')).write_text(json.dumps(result,indent=2)+'\n')
    if not result.get('id'): raise GateError('Notary submission ID missing')
    run(['xcrun','notarytool','log',result['id'],'--keychain-profile',profile,out/(artifact.stem+'-notary-log.json')],log)
    if result.get('status')!='Accepted': raise GateError('Notarization did not return Accepted')
    return {'id':result['id'],'status':result['status']}

def verify_signed(app, values, log):
    info=app_info(app)
    if info['CFBundleIdentifier']!=values['appBundleID']: raise GateError('Signed app namespace mismatch')
    core_info=plistlib.loads((app/'Contents/Frameworks/PhotoAxisCore.framework/Resources/Info.plist').read_bytes())
    if core_info['CFBundleIdentifier']!=values['coreBundleID']: raise GateError('Framework namespace mismatch')
    utis=info['UTExportedTypeDeclarations']
    if utis[0]['UTTypeIdentifier']!=values['documentUTI'] or info['CFBundleDocumentTypes'][0]['LSItemContentTypes']!=[values['documentUTI']]: raise GateError('Document association mismatch')
    if utis[1]['UTTypeIdentifier']!=values['documentUTI']+'.investigation' or info['CFBundleDocumentTypes'][1]['LSItemContentTypes']!=[values['documentUTI']+'.investigation']: raise GateError('Investigation association mismatch')
    for item in [app/'Contents/Frameworks/PhotoAxisCore.framework',app]:
        run(['codesign','--verify','--strict',item],log)
        detail=run(['codesign','-dv','--verbose=4',item],log)
        if 'Authority=Developer ID Application:' not in detail or 'TeamIdentifier='+values['teamID'] not in detail or 'runtime' not in detail or 'Timestamp=' not in detail: raise GateError('Developer ID/runtime/timestamp verification failed')
        ent=run(['codesign','-d','--entitlements',':-',item],log).strip()
        start=ent.find('<?xml')
        if start>=0 and plistlib.loads(ent[start:].encode()): raise GateError('Unexpected release entitlement; no debug/bypass capabilities allowed')
    run(['codesign','--verify','--deep','--strict',app],log)

def execute(mode, path):
    if mode=='preflight':
        values=config(path); require_candidate()
        identities=run(['security','find-identity','-v','-p','codesigning'])
        if '"'+values['developerIDIdentity']+'"' not in identities: raise GateError('Configured Developer ID Application identity not available')
        run(['xcrun','notarytool','history','--keychain-profile',values['notaryKeychainProfile'],'--output-format','json'])
        print('PASS: local release preflight; no signing/upload performed'); return
    values=rc=None
    if mode=='signed':
        values=config(path); rc=require_candidate()
        identities=run(['security','find-identity','-v','-p','codesigning'])
        if '"'+values['developerIDIdentity']+'"' not in identities: raise GateError('Configured Developer ID Application identity not available')
        run(['xcrun','notarytool','history','--keychain-profile',values['notaryKeychainProfile'],'--output-format','json'])
    BUILD.mkdir(parents=True,exist_ok=True)
    out=Path(tempfile.mkdtemp(prefix='P13-'+mode+'-',dir=BUILD)); log=out/'packaging.log'
    app=out/'PhotoAxis.app'
    if mode=='local': run(['ditto',BUILD/'DerivedData/Build/Products/Release/PhotoAxis.app',app],log)
    else:
        archive=out/'PhotoAxis.xcarchive'
        run(['xcodebuild','-project','PhotoAxis.xcodeproj','-scheme','PhotoAxis','-configuration','Release','-destination','generic/platform=macOS','-archivePath',archive,'-derivedDataPath',BUILD/'DistributionDerivedData','CODE_SIGNING_ALLOWED=NO','ENABLE_HARDENED_RUNTIME=YES','ENABLE_TESTABILITY=NO','PHOTOAXIS_APP_BUNDLE_ID='+values['appBundleID'],'PHOTOAXIS_CORE_BUNDLE_ID='+values['coreBundleID'],'PHOTOAXIS_DOCUMENT_UTI='+values['documentUTI'],'archive'],log)
        run(['ditto',archive/'Products/Applications/PhotoAxis.app',app],log)
    info=app_info(app); run(['codesign','--verify','--deep','--strict',app],log) if mode=='local' else None
    notary={}
    if mode=='signed':
        ent=out/'Release.entitlements'; ent.write_bytes(plistlib.dumps({}))
        for item in [app/'Contents/Frameworks/PhotoAxisCore.framework',app]:
            run(['codesign','--force','--sign',values['developerIDIdentity'],'--options','runtime','--timestamp','--entitlements',ent,item],log)
        verify_signed(app,values,log)
        archive_zip=out/'PhotoAxis-notarization.zip'; run(['ditto','-c','-k','--keepParent',app,archive_zip],log)
        notary['app']=notarize(archive_zip,values['notaryKeychainProfile'],out,log)
        run(['xcrun','stapler','staple',app],log); run(['xcrun','stapler','validate',app],log)
        run(['spctl','--assess','--type','execute','--verbose=4',app],log)
    filename='PhotoAxis-1.0.0-arm64'+('-LOCAL-UNSIGNED' if mode=='local' else '')+'.dmg'; dmg=out/filename
    create_dmg(app,dmg,log)
    if mode=='signed':
        run(['codesign','--sign',values['developerIDIdentity'],'--timestamp',dmg],log)
        notary['dmg']=notarize(dmg,values['notaryKeychainProfile'],out,log)
        run(['xcrun','stapler','staple',dmg],log); run(['xcrun','stapler','validate',dmg],log)
        run(['codesign','--verify','--strict',dmg],log)
        run(['spctl','--assess','--type','open','--context','context:primary-signature','--verbose=4',dmg],log)
    app_tree=inspect_dmg(dmg,app,log); sha=hashlib.sha256(dmg.read_bytes()).hexdigest()
    (out/'SHA256SUMS.txt').write_text(sha+'  '+filename+'\n')
    manifest={'status':'LOCAL_UNSIGNED' if mode=='local' else 'SIGNED_NOTARIZED_PENDING_INSTALL_TEST','publicReady':False,'sourceCommit':run(['git','rev-parse','HEAD']).strip(),'sourceDirty':bool(run(['git','status','--porcelain']).strip()),'version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],'appBundleID':info['CFBundleIdentifier'],'appTreeSHA256':app_tree,'artifact':filename,'sha256':sha,'architecture':'arm64','minimumOS':info['LSMinimumSystemVersion'],'notarization':notary,'teamID':values['teamID'] if values else None,'developerIDIdentity':values['developerIDIdentity'] if values else None,'candidateCommit':rc['sourceCommit'] if rc else None,'cleanInstallVerified':False,'offlineWorkflowVerified':False,'toolchain':run(['xcodebuild','-version']).strip()}
    (out/'distribution-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'artifactDirectory':str(out),'artifact':filename,'sha256':sha,'status':manifest['status']}))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('mode',choices=['preflight','local','signed']); parser.add_argument('--config',default=str(ROOT/'Config/Distribution.local.json')); args=parser.parse_args()
    try: execute(args.mode,args.config)
    except (GateError,OSError,ValueError,KeyError) as error: print('BLOCKED: '+str(error),file=sys.stderr); sys.exit(2)
