#!/usr/bin/env python3
"""P15 release preflight and anonymous HTTPS artifact checks; never publishes or runs app."""
import argparse, hashlib, json, os, re, subprocess, sys, tempfile, urllib.request
from pathlib import Path
import distribution as dist
ROOT=dist.ROOT
REQUIRED=[f'R{n:02d}' for n in range(1,10)]+['R12']

def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def validate_public_manifest(manifest,plan):
    if manifest.get('status')!='SIGNED_NOTARIZED_PENDING_INSTALL_TEST' or manifest.get('artifact')!='PhotoAxis-1.0.0-arm64.dmg': raise dist.GateError('Only the final Developer ID/notarized public DMG is eligible; local unsigned artifacts are blocked')
    version,build=dist.version_build()
    if manifest.get('version')!=version or manifest.get('build')!=build or manifest.get('architecture')!='arm64' or manifest.get('minimumOS')!='14.0': raise dist.GateError('Distribution version/build/architecture/minOS mismatch')
    if manifest.get('sourceDirty') is not False: raise dist.GateError('Distribution was not built from a clean source checkout')
    if not manifest.get('teamID') or not str(manifest.get('developerIDIdentity','')).startswith('Developer ID Application: '): raise dist.GateError('Developer ID identity missing')
    for item in ['app','dmg']:
        row=manifest.get('notarization',{}).get(item,{})
        if row.get('status')!='Accepted' or not row.get('id'):raise dist.GateError('App and DMG each require actual Accepted submission IDs')
    for key in ['sourceCommit','sha256']:
        if manifest.get(key)!=plan.get('sourceCommit' if key=='sourceCommit' else 'artifactSHA256'): raise dist.GateError('Distribution and publication plan disagree: '+key)
    if not re.fullmatch(r'[0-9a-f]{64}',manifest['sha256']):raise dist.GateError('Final artifact SHA-256 missing')
    if manifest.get('cleanInstallVerified') is not True or manifest.get('offlineWorkflowVerified') is not True: raise dist.GateError('Clean Gatekeeper install and offline workflow are not verified')
    return manifest

def gate_ledger(ledger,root=ROOT):
    failures=[]
    for name in REQUIRED:
        row=ledger.get(name,{})
        if row.get('status')!='PASS':failures.append(name);continue
        refs=row.get('evidence',[])
        if not refs or any(not isinstance(r,str) or not (root/r).is_file() or not (root/r).resolve().is_relative_to(root.resolve()) for r in refs):failures.append(name)
    return failures

def preflight(config_path,plan_path,ledger_path):
    plan=json.loads(Path(plan_path).read_text());ledger=json.loads(Path(ledger_path).read_text())
    results={n:{'status':ledger.get(n,{}).get('status','CHUA_KIEM_CHUNG'),'reason':ledger.get(n,{}).get('reason',''),'evidence':ledger.get(n,{}).get('evidence',[])} for n in [f'R{n:02d}' for n in range(1,13)]}
    errors=[];values=manifest=None
    try:values=dist.config(config_path,public=True)
    except (OSError,ValueError,dist.GateError) as error:errors.append('R01: '+str(error))
    try:rc=dist.require_candidate()
    except (OSError,ValueError,dist.GateError) as error:errors.append('R02: '+str(error))
    if plan.get('publicReady') is not True:errors.append('Publication plan publicReady is not true')
    if gate_ledger(ledger):errors.append('Unaccepted required gates: '+', '.join(gate_ledger(ledger)))
    for k in ['sourceCommit','distributionTargetCommit','websiteCommit']:
        if not re.fullmatch(r'[0-9a-f]{40}',str(plan.get(k,''))):errors.append('Confirmed commit missing: '+k)
    if values:
        for key in ['sourceRepository','sourceVisibility','distributionRepository','websiteURL']:
            if plan.get(key)!=values[key]:errors.append('Plan/config mismatch: '+key)
    path=plan.get('distributionManifest')
    if path:
        try:
            file=Path(path);manifest=validate_public_manifest(json.loads(file.read_text()),plan)
            dmg=file.parent/manifest['artifact']
            if sha(dmg)!=manifest['sha256']:raise dist.GateError('Artifact bytes do not match final checksum')
            if values:
                for key in ['teamID','developerIDIdentity','appBundleID']:
                    if manifest.get(key)!=values[key]:raise dist.GateError('Distribution/config identity mismatch: '+key)
                app=file.parent/'PhotoAxis.app'
                if dist.tree_hash(app)!=manifest.get('appTreeSHA256'):raise dist.GateError('App tree differs from the final distribution manifest')
                log=dist.BUILD/'P15-preflight-signature.log';dist.BUILD.mkdir(parents=True,exist_ok=True)
                dist.verify_signed(app,values,log)
                dist.run(['xcrun','stapler','validate',app],log)
                dist.run(['codesign','--verify','--strict',dmg],log);dist.run(['xcrun','stapler','validate',dmg],log)
        except (OSError,ValueError,KeyError,dist.GateError) as error:errors.append('R03-R08: '+str(error))
    else:errors.append('R03-R08: final distribution manifest missing')
    website=json.loads((ROOT/'website/release-status.json').read_text())
    if website.get('publicReady') is not True:errors.append('R09: website is still a preview with disabled download')
    if values and not errors:
        prefix='https://github.com/'+values['distributionRepository']+'/releases/'
        expected=prefix+'download/v1.0.0/PhotoAxis-1.0.0-arm64.dmg'
        if website.get('artifactURL')!=expected or website.get('sha256')!=plan.get('artifactSHA256'):errors.append('R09: versioned asset URL/checksum mismatch')
        if website.get('releaseURL')!=prefix+'tag/v1.0.0' or website.get('checksumURL')!=prefix+'download/v1.0.0/SHA256SUMS.txt':errors.append('R09: release/checksum URL mismatch')
    return {'status':'READY_FOR_TARGET_PERMISSION_AND_CI_CHECK' if not errors else 'BLOCKED_EXTERNAL','publicReady':not errors,'mutationPerformed':False,'results':results,'blockingReasons':errors,'scope':'read-only local release gates; GitHub permissions/CI/tag/draft/publish and HTTPS/native postcheck remain separate actual operations'}

class HTTPSOnlyRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):
        if urllib.parse.urlsplit(newurl).scheme!='https':raise dist.GateError('Refusing an HTTPS downgrade redirect')
        return super().redirect_request(req,fp,code,msg,headers,newurl)

def anonymous_download(url,destination,expected_sha=None,max_bytes=1024*1024*1024):
    if urllib.parse.urlsplit(url).scheme!='https':raise dist.GateError('Public checks require HTTPS')
    opener=urllib.request.build_opener(HTTPSOnlyRedirect())
    request=urllib.request.Request(url,headers={'User-Agent':'PhotoAxis-Release-Verification/1.0'})
    with opener.open(request,timeout=30) as response:
        if response.status!=200 or urllib.parse.urlsplit(response.url).scheme!='https':raise dist.GateError('Anonymous HTTPS request did not return 200')
        declared=response.headers.get('Content-Length')
        if declared and int(declared)>max_bytes:raise dist.GateError('Download exceeds verification size limit')
        destination=Path(destination)
        if destination.exists():raise dist.GateError('Refusing to overwrite a local file')
        partial=destination.with_name(destination.name+'.partial')
        if partial.exists():raise dist.GateError('Existing partial verification file')
        digest=hashlib.sha256();total=0
        try:
            with partial.open('xb') as output:
                while chunk:=response.read(1024*1024):
                    total+=len(chunk)
                    if total>max_bytes:raise dist.GateError('Download exceeds verification size limit')
                    digest.update(chunk);output.write(chunk)
            if expected_sha and digest.hexdigest()!=expected_sha:raise dist.GateError('Public bytes do not match the release checksum')
            partial.rename(destination)
        finally:
            if partial.exists():partial.unlink()
        return {'url':url,'finalURL':response.url,'httpStatus':response.status,'bytes':total,'sha256':digest.hexdigest(),'authentication':'none; no cookie/token/Authorization header'}

def postcheck(config_path,plan_path,ledger_path):
    audit=preflight(config_path,plan_path,ledger_path)
    if not audit['publicReady']:raise dist.GateError('Public postcheck blocked: complete preflight and actual publication first')
    values=dist.config(config_path,public=True);plan=json.loads(Path(plan_path).read_text());status=json.loads((ROOT/'website/release-status.json').read_text())
    dist.BUILD.mkdir(parents=True,exist_ok=True);out=Path(tempfile.mkdtemp(prefix='P15-public-download-',dir=dist.BUILD));log=out/'verification.log'
    site=anonymous_download(values['websiteURL'],out/'website.html',max_bytes=4*1024*1024)
    vi=(out/'website.html').read_text()
    for link in [status['artifactURL'],status['releaseURL'],status['checksumURL']]:
        if link not in vi:raise dist.GateError('Public website does not contain the planned versioned release links')
    sums=anonymous_download(status['checksumURL'],out/'SHA256SUMS.txt',max_bytes=65536)
    required=plan['artifactSHA256']+'  PhotoAxis-1.0.0-arm64.dmg'
    if required not in (out/'SHA256SUMS.txt').read_text().splitlines():raise dist.GateError('Public checksum file disagrees with manifest')
    asset=anonymous_download(status['artifactURL'],out/'PhotoAxis-1.0.0-arm64.dmg',plan['artifactSHA256'])
    dmg=out/'PhotoAxis-1.0.0-arm64.dmg'
    dist.run(['codesign','--verify','--strict',dmg],log);dist.run(['xcrun','stapler','validate',dmg],log);dist.run(['spctl','--assess','--type','open','--context','context:primary-signature','--verbose=4',dmg],log)
    original=Path(plan['distributionManifest']).parent/'PhotoAxis.app'
    app_tree=dist.inspect_dmg(dmg,original,log,source_commit=plan['sourceCommit'])
    result={'status':'PUBLIC_HTTP_HASH_SIGNATURE_PAYLOAD_PASS_NATIVE_INSTALL_PENDING','website':site,'checksum':sums,'asset':asset,'appTreeSHA256':app_tree,'sourceCommit':plan['sourceCommit'],'distributionTargetCommit':plan['distributionTargetCommit'],'websiteCommit':plan['websiteCommit'],'nativeInstallFromDownloadedAssetVerified':False,'offlineWorkflowFromDownloadedAssetVerified':False,'scope':'downloaded public bytes verified; no app execution or quarantine change, browser installation/native workflow and remote tag/CI still required'}
    (out/'postcheck.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'artifactDirectory':str(out),'result':result},indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=['preflight','postcheck']);p.add_argument('--config',default=str(ROOT/'Config/Distribution.local.json'));p.add_argument('--plan',default=str(ROOT/'docs/KE_HOACH_PUBLIC.json'));p.add_argument('--readiness',default=str(ROOT/'docs/READINESS_PUBLIC.json'));a=p.parse_args()
    try:
        if a.mode=='preflight':
            report=preflight(a.config,a.plan,a.readiness);print(json.dumps(report,indent=2));sys.exit(0 if report['publicReady'] else 2)
        postcheck(a.config,a.plan,a.readiness)
    except (dist.GateError,OSError,ValueError,KeyError) as error:print('BLOCKED: '+str(error),file=sys.stderr);sys.exit(2)
