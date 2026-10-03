# Run from the repository root with PHOTOAXIS_QA_ROOT pointing to the unchanged owned QA folder.
from pathlib import Path
import hashlib,json,base64,os
from pypdf import PdfReader
from PIL import Image
qa=Path(os.environ['PHOTOAXIS_QA_ROOT']);root=qa/'Ho-so-native.paxcase';c=json.loads((root/'case.json').read_bytes());item=c['items'][0]
def sha(data):return hashlib.sha256(data).hexdigest()
def encoded(value):return json.dumps(value,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()
prev='0'*64
for i,e in enumerate(c['events'],1):
 assert e['payload']['sequence']==i and e['payload']['previousSHA256']==prev
 assert sha(encoded(e['payload']))==e['sha256'], i
 prev=e['sha256']
state={k:c[k] for k in ['id','code','title','examiner','createdAt','items']}
assert sha(encoded(state))==c['events'][-1]['payload']['details']['caseStateSHA256']
for h in {item['workingFileSHA256'],item['intakeWorkingFileSHA256']}:
 path=root/'projects'/f"{item['id'].lower()}-{h}.paxis";assert sha(path.read_bytes())==h
raw=(root/'originals'/item['originalSHA256']).read_bytes();assert raw==Path('Fixtures/P02/grid-corners.png').read_bytes()
image=Image.open(qa/'verified-reviewed.png').convert('RGBA');assert image.size==(640,480)
for y in range(30,67):
 for x in range(20,75):assert image.getpixel((x,y))==(0,0,0,255)
log=json.loads((qa/'verified-processing-log.json').read_bytes());assert log['events']==c['events'][:-1]
receipts=[]
for name in ['verified-reviewed.png','verified-English-A4.pdf','verified-processing-log.json','native-source-catalog.json']:
 h=sha((qa/name).read_bytes());matches=[e['payload']['sequence'] for e in c['events'] if e['payload']['details'].get('fileName')==name and e['payload']['details'].get('sha256')==h];assert matches,name
 receipts.append(dict(file=name,sha256=h,matchingReceipts=matches))
pdf=PdfReader(qa/'verified-English-A4.pdf');r=pdf.trailer['/Root'];assert not any(k in r for k in ['/AcroForm','/OCProperties','/AF','/EmbeddedFiles','/OpenAction','/AA'])
for p in pdf.pages:
 assert not p.extract_text().strip() and not p.get('/Annots')
 assert not p['/Resources'].get('/Font')
 xs=p['/Resources']['/XObject'].get_object();assert len(xs)==1
 obj=list(xs.values())[0].get_object();assert obj['/Width']==1240 and obj['/Height']==1754
 assert abs(float(p.mediabox.width)-595.2756)<.01 and abs(float(p.mediabox.height)-841.8898)<.01
before=Image.open(qa/'screenshots/comparison-verified-en-before.png').convert('RGB');after=Image.open(qa/'screenshots/comparison-verified-en-pan.png').convert('RGB')
def first_red(image,start,end):
 for y in range(400,1100):
  for x in range(start,end):
   r,g,b=image.getpixel((x,y))
   if r>220 and g<80 and b<80:return [x,y]
points=[dict(view=view,before=first_red(before,a,b),after=first_red(after,a,b)) for view,a,b in [('source',40,935),('processed',944,1840)]]
for p in points:
 p['delta']=[p['after'][0]-p['before'][0],p['after'][1]-p['before'][1]];assert p['delta']==[50,30],p
output=dict(status='PASS',sourceCommit='826bebf61c068ca1864fdf8a20f6b410ca13aa2f',caseID=c['id'],itemID=item['id'],original=dict(bytes=len(raw),sha256=sha(raw),matchesFixtureByteForByte=True,permissions=oct((root/'originals'/item['originalSHA256']).stat().st_mode & 0o777)),ledger=dict(events=len(c['events']),sha256LinksIndependentlyVerified=True,currentCaseStateDigestVerified=True,exportedEvents=len(log['events']),exportCompletionRemainsInCase=True,incompleteStarts=[9,11],intakeArchiveHash=item['intakeWorkingFileSHA256'],checkpointHash=item['workingFileSHA256']),PNG=dict(size=image.size,maskedPixels=55*37,allMaskPixelsOpaqueBlack=True),PDF=dict(pages=len(pdf.pages),size='A4',raster=[1240,1754],textSelectable=False,annotations=False,fonts=False,embeddedFiles=False),pan=dict(pointerPixels=[50,30],screenshots=points),receipts=receipts)
(qa/'verified-artifact-inspection.json').write_text(json.dumps(output,indent=2)+'\n');print(json.dumps(output,indent=2))
