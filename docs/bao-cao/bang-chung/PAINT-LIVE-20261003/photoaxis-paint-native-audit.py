import hashlib,io,json,zipfile,datetime,sys
from pathlib import Path
from PIL import Image
r=Path(sys.argv[1])
sha=lambda b:hashlib.sha256(b).hexdigest()
fixture=(r/'paint-fixture.png').read_bytes(); fixtureHash=sha(fixture)
projects=[]
for lang,count,sources in [('vi',5,3),('en',7,4)]:
 p=r/f'native-{lang}-paint.paxis'
 with zipfile.ZipFile(p) as z:
  assert z.testzip() is None
  m=json.loads(z.read('document.json')); assert m['formatVersion']==4
  assert m['canvas']=={'width':1200,'height':900}
  strokes=[s for l in m['layers'] if l['type']=='paint' for s in l['paint']['strokes']]
  assert len(strokes)==count and len(m['sources'])==sources
  for s in m['sources']:
   b=z.read('assets/'+s['id']); assert sha(b)==s['id']
   assert Image.open(io.BytesIO(b)).size==(1200,900)
  sid=next(l['sourceID'] for l in m['layers'] if l['type']=='image')
  assert sid==fixtureHash and z.read('assets/'+sid)==fixture
  projects.append(dict(language=lang,formatVersion=4,strokes=count,sourceCount=sources,assetHashesValid=True,originalBytesUnchanged=True,archiveSHA256=sha(p.read_bytes())))
  if lang=='en':
   output=Image.open(r/'native-en-paint.png').convert('RGBA'); assert output.size==(1200,900)
   samples=[]
   for idx,s in enumerate(strokes):
    if s['kind']=='brush':
     pt=s['points'][0]; xy=(round(pt['x']),round(pt['y'])); got=output.getpixel(xy)
     assert max(got[:3])<=2 and got[3]==255,(idx,got)
     samples.append(dict(stroke=idx,kind='brush',point=xy,rgba=got,passBlackOpaque=True))
   for idx in [4,6]:
    s=strokes[idx]; pt=s['points'][0]; off=s['sourceOffset']; xy=(round(pt['x']),round(pt['y']))
    sourceXY=(round(pt['x']+off['x']),round(pt['y']+off['y']))
    source=Image.open(io.BytesIO(z.read('assets/'+s['sourceID']))).convert('RGBA')
    got=output.getpixel(xy); expected=source.getpixel(sourceXY)
    assert max(abs(a-b) for a,b in zip(got,expected))<=2,(idx,got,expected)
    samples.append(dict(stroke=idx,kind='clone',point=xy,sourcePoint=sourceXY,rgba=got,expectedRGBA=expected,passFrozenSourceMatch=True))
   original=Image.open(io.BytesIO(fixture)).convert('RGBA')
   untouched=[(20,20),(50,800),(1100,50)]
   for xy in untouched: assert output.getpixel(xy)==original.getpixel(xy)
assert 'Saved' in (r/'en-undo.ax.txt').read_text() and 'Unsaved' not in (r/'en-undo.ax.txt').read_text()
assert 'Unsaved' in (r/'en-redo.ax.txt').read_text()
assert 'Saved' in (r/'en-undo-final.ax.txt').read_text() and 'Unsaved' not in (r/'en-undo-final.ax.txt').read_text()
assert 'Saved' in (r/'en-reopen.ax.txt').read_text() and 'Unsaved' not in (r/'en-reopen.ax.txt').read_text()
report=dict(createdAt=datetime.datetime.now().astimezone().isoformat(),scope='Final build6 scoped native VI/EN synthetic mouse/keyboard QA; not full baseline acceptance or performance qualification',projects=projects,export=dict(width=1200,height=900,sha256=sha((r/'native-en-paint.png').read_bytes()),pixelSamples=samples,untouchedSamples=untouched),sourceFixtureSHA256=fixtureHash,undoRedoSavedMarker=True,reopenSchema4=True,nativeSourcePick='click then Option-Return; Option-click covered by hosted native NSEvent test',livePreview=dict(scan='VI rotation3deg ->1246x962, no Preview button, transparent paint ROI black-bar regression visually absent',imageSize='VI width600->height450 automatic; Cancel restored1200x900',perspective='VI956x699 automatic inset with full-preview checkbox off; Cancel restored saved state',crop='hosted native test',performance='not measured'),status='PASS')
(r/'native-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
