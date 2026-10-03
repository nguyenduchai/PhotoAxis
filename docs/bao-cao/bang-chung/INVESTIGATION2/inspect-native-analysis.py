#!/usr/bin/env python3
"""Read-only verification of synthetic native case/analysis artifacts."""
import argparse, hashlib, json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('case');p.add_argument('analysis');p.add_argument('--output',required=True);a=p.parse_args()
root=Path(a.case);case=json.loads((root/'case.json').read_text());data=Path(a.analysis).read_bytes();export=json.loads(data)
def sha(b):return hashlib.sha256(b).hexdigest()
def canonical(v):return json.dumps(v,ensure_ascii=False,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
checks={}
previous='0'*64
for index,event in enumerate(case['events']):
 payload=event['payload'];assert payload['sequence']==index+1 and payload['previousSHA256']==previous
 assert sha(canonical(payload))==event['sha256'];previous=event['sha256']
checks['eventHashesAndSequence']=len(case['events'])
state={k:case[k] for k in ['id','code','title','examiner','createdAt','items','analysis']}
assert sha(canonical(state))==case['events'][-1]['payload']['details']['caseStateSHA256'];checks['stateDigest']='PASS'
for item in case['items']:
 assert sha((root/'originals'/item['originalSHA256']).read_bytes())==item['originalSHA256']
 for h in set([item['workingFileSHA256'],item['intakeWorkingFileSHA256']]):
  archive=root/'projects'/(item['id'].lower()+'-'+h+'.paxis');assert sha(archive.read_bytes())==h
checks['imageOriginalsAndArchives']=len(case['items'])
analysis=case['analysis']
for video in analysis['videos']:
 path=root/'originals'/(video['sha256']+'.'+Path(video['originalName']).suffix[1:].lower())
 assert sha(path.read_bytes())==video['sha256'] and path.stat().st_size==video['byteCount']
checks['videoSources']=len(analysis['videos'])
pts={f['frameIndex']:f['presentationTime']['value']/f['presentationTime']['timescale'] for f in analysis['frames']}
assert pts[1]==0.1 and pts[2]==0.35
assert next(f for f in analysis['frames'] if f['frameIndex']==2)['timeOffsetSeconds']==5
checks['exactPTS']=pts
for ocr in analysis['ocr']:
 raw='\n'.join(l['text'] for l in ocr['lines'])
 assert raw=='HỒ SƠ ĐIỀU TRA\nTài liệu kiểm thử tiếng Việt\nKhông suy đoán phần không đọc được'
 assert 'NGOÀI VÙNG' not in raw and ocr['language'].startswith('vi-') and ocr['confirmations']
checks['ocrRecords']=len(analysis['ocr']);checks['confirmations']=[len(o['confirmations']) for o in analysis['ocr']]
assert analysis['ocr'][0]['confirmations'][0]['text']!=raw
checks['rawAndConfirmedTextSeparate']='PASS'
assert [m['result'] for m in analysis['measurements']]==[50,100,50]
checks['measurementResults']=[{'kind':m['kind'],'result':m['result']} for m in analysis['measurements']]
receipt=next(e for e in case['events'] if e['payload']['operation']=='analysisExportCompleted' and e['payload']['details']['fileName']==Path(a.analysis).name)
assert receipt['payload']['details']['sha256']==sha(data)
assert any(e['sha256']==export['ledgerSHA256'] and e['payload']['operation']=='analysisExportStarted' for e in case['events'])
assert export['caseID']==case['id']
checks['nativeOutputSHA256']=sha(data);checks['outputReceiptSequence']=receipt['payload']['sequence']
checks['outputIsSnapshotBeforeLaterEnglishConfirmation']=len(export['analysis']['ocr'][-1]['confirmations']) < len(analysis['ocr'][-1]['confirmations'])
checks['status']='PASS';checks['dataScope']='synthetic fixtures; no real case or personal image'
Path(a.output).write_text(json.dumps(checks,ensure_ascii=False,indent=2)+'\n');print(json.dumps(checks,ensure_ascii=False,indent=2))
