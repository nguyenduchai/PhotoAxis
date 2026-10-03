from pathlib import Path
import json,hashlib,base64,zipfile,math,shutil,sys
from PIL import Image
q=Path(sys.argv[1]);case=q/'CurrentImage8.paxcase';stage=Path(sys.argv[2])
def sha(b):return hashlib.sha256(b).hexdigest()
def canon(x):return json.dumps(x,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
def integral(x):
 if isinstance(x,dict):return {k:integral(v) for k,v in x.items()}
 if isinstance(x,list):return [integral(v) for v in x]
 if isinstance(x,float) and x.is_integer():return int(x)
 return x
c=json.loads((case/'case.json').read_text());i=c['items'][0];prev='0'*64
for n,e in enumerate(c['events'],1):
 assert e['payload']['sequence']==n and e['payload']['previousSHA256']==prev
 assert sha(canon(e['payload']))==e['sha256'];prev=e['sha256'];assert e['payload']['appVersion']=='1.0.0 (8)'
assert sha(canon(integral({k:c[k] for k in ('id','code','title','examiner','createdAt','items','analysis')})))==c['events'][-1]['payload']['details']['caseStateSHA256']
original=case/'originals'/i['originalSHA256'];assert sha(original.read_bytes())==i['originalSHA256'] and original.stat().st_size==i['originalByteCount']
for field in ['workingFileSHA256','intakeWorkingFileSHA256']:
 candidates=list((case/'projects').rglob('*'));assert any(p.is_file() and sha(p.read_bytes())==i[field] for p in candidates)
model=base64.b64decode(i['currentModelJSON']);assert sha(model)==i['redactionModelSHA256']
ordinary=q/'edited-open-image.paxis';before=json.loads((q/'ordinary-before-analysis.json').read_text());assert sha(ordinary.read_bytes())==before['sha256'] and ordinary.stat().st_size==before['bytes']
with zipfile.ZipFile(ordinary) as z:
 raw=z.read('document.json');m=json.loads(raw);asset=z.read('assets/'+m['sources'][0]['id'])
 assert m.get('investigation') is None;assert abs(m['layers'][0]['imageAdjustments']['contrast']-20)<1e-10
 assert sha(asset)==sha((q/'open-image-fixture.png').read_bytes())
snapshot=next(e['payload']['details'] for e in c['events'] if e['payload']['operation']=='openImageSnapshot');assert snapshot['origin']=='rendered-current-canvas-not-received-original';assert snapshot['documentModelSHA256']==sha(raw);assert snapshot['documentID']==m['id'];assert json.loads(snapshot['embeddedSourceIDsJSON'])==sorted(s['id'] for s in m['sources']);assert snapshot['renderedPNG_SHA256']==i['originalSHA256']
assert 'openImageAnalysisSaved' in [e['payload']['operation'] for e in c['events']]
cal=c['analysis']['calibrations'][0];measure=c['analysis']['measurements'][0];assert cal['modelSHA256']==sha(model) and measure['calibrationID']==cal['id']
def distance(p):return math.hypot(p[1]['x']-p[0]['x'],p[1]['y']-p[0]['y'])
expected=distance(measure['points'])/distance(cal['reference'])*cal['knownLength'];assert expected==measure['result']==50 and cal['unit']=='mm'
outpath=q/'shared-current.png';receipt=next(e['payload'] for e in c['events'] if e['payload']['operation']=='sharingCompleted');assert receipt['details']['sha256']==sha(outpath.read_bytes())
out=Image.open(outpath);src=Image.open(original);assert out.size==src.size==(1600,640);assert not out.getexif().get(34853);assert not any(k.lower() in ['comment','description','gps'] for k in out.info)
r=i['redactions'][0];oa=out.convert('RGBA').load();sa=src.convert('RGBA').load();black=outside=0
for y in range(640):
 for x in range(1600):
  if r['x']<=x<r['x']+r['width'] and r['y']<=y<r['y']+r['height']:assert oa[x,y]==(0,0,0,255);black+=1
  else:assert oa[x,y]==sa[x,y];outside+=1
assert (black,outside)==(147917,876083)
normal=(q/'ordinary-with-selected-case-en.ax.txt').read_text();working=(q/'case-working-analysis-en.ax.txt').read_text();assert 'Temporary analysis' in normal and 'button (disabled) Measure distance/area' in normal;assert 'case working image' in working and 'button Measure distance/area' in working
assert '1516 × 560 px' in (q/'crop-pointer-en.ax.txt').read_text();assert 'Clone Stamp Size' in (q/'clone-tool-en.ax.txt').read_text()
report={'stage':'OPEN-IMAGE-CURSOR-20261004','build':'8','data':'synthetic fixtures only','status':'PASS within stated scope','eventsValidated':len(c['events']),'eventHashChain':'PASS','caseStateDigest':'PASS','ordinaryArchiveUnchangedDuringAnalysisAndSave':True,'ordinaryArchiveSHA256':before['sha256'],'ordinaryModelUnattached':True,'ordinaryContrastPercent':20,'embeddedSourceBytesEqualToFixture':True,'snapshotOrigin':snapshot['origin'],'snapshotDocumentModelSHA256':snapshot['documentModelSHA256'],'snapshotSHA256':i['originalSHA256'],'snapshotByteCount':i['originalByteCount'],'measurementMM':measure['result'],'recomputedMeasurementMM':expected,'sharingSHA256':sha(outpath.read_bytes()),'sharingSize':[1600,640],'opaqueBlackRegionPixels':black,'outsideRegionPixelsEqualToCanvasSnapshot':outside,'nativeLanguages':['vi','en'],'finalNativeScope':['VI normal-image contrast20/Apply/Save/Open paxis','VI active-canvas calibration100mm/measurement50mm entered coordinates','VI redaction40,193,791,187 entered coordinates/share PNG','VI save analysis as newcase/verify integrity','EN ordinary active analysis with other case selected does not use case results','EN reopen savedcase/edit workingimage/analysis has calibration/compare','EN Crop corner pointerdrag1600x640 to1516x560 thenCancel;Brush/Clone/Hand selections;Hand pointerpan'],'finalNativeOCR':'CHUA_KIEM_CHUNG: cold request stayed busy, QA quit and reopened saved document; no OCR event persisted in final case','preSaveGuardNativeOCR':'Three Vietnamese lines, ROI pointerdrag and human confirmation observed before destination guard fix; not claimed as final binary rerun','hostedOnlyScope':['exact NSCursor.current/image/hotspots/cache distinctions for all tool kinds','OptionZoom/Clone sample modifier roles,Space midpan release,all crop/move handles/rotation/offscreen rects','capture pixels match committed adjusted layered canvas and baseline before-after','direct annotation oneUndo/cancel/async tabchange/stale calibration/redactions','save fault cleanup/corrupt raster/nested existing case destination protection'],'cursorScreenshotLimitation':'CUA overlays its own pointer; screenshots do not certify actual OS cursor bitmap. AppKit NSCursor identity/hotspot/image tests provide that evidence.','baselineAcceptanceUnchanged':True}
(q/'native-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');stage.mkdir(exist_ok=True)
for p in q.iterdir():
 if p.name.endswith('.ax.txt'):(stage/p.name).write_text(p.read_text().replace(str(q),'$QA').replace(str(Path.home()),'$HOME'))
 elif p.suffix=='.png' and p.name not in ['open-image-fixture.png','other-image.png']:shutil.copy2(p,stage/p.name)
for name in ['native-audit.json','ordinary-before-analysis.json','qa-setup.json']:shutil.copy2(q/name,stage/name)
print(json.dumps(report,ensure_ascii=False,indent=2))
