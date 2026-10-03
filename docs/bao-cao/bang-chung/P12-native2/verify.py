#!/usr/bin/env python3
"""Read-only, independent audit of this recorded native QA session.

This validates captured files and AX observations, not a new UI run or IME test.
Uses only Python's standard library. Run from any directory without -O.
"""
import hashlib
import json
import math
from pathlib import Path
import statistics
import struct
import zipfile
import zlib

ROOT = Path(__file__).resolve().parent
checks = []


def check(condition, label):
    if not condition:
        raise AssertionError(label)
    checks.append(label)


def ax(name):
    return (ROOT / (name + '.ax.txt')).read_text()


def png_rgba(data):
    """Decode the noninterlaced 8-bit RGBA previews emitted by Image I/O."""
    check(data[:8] == b'\x89PNG\r\n\x1a\n', 'PNG signature')
    offset, compressed = 8, bytearray()
    while offset < len(data):
        size = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + size]
        crc = struct.unpack('>I', data[offset + 8 + size:offset + 12 + size])[0]
        check(zlib.crc32(kind + payload) == crc, 'PNG CRC ' + kind.decode())
        if kind == b'IHDR':
            width, height, depth, color, comp, filt, interlace = struct.unpack('>IIBBBBB', payload)
            check((depth, color, comp, filt, interlace) == (8, 6, 0, 0, 0), 'RGBA8 preview format')
        elif kind == b'IDAT':
            compressed.extend(payload)
        offset += size + 12
        if kind == b'IEND':
            break
    raw = zlib.decompress(compressed)
    stride = width * 4
    check(len(raw) == (stride + 1) * height, 'PNG decompressed length')
    result, previous = bytearray(), bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        mode, row = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        if mode not in range(5):
            raise AssertionError('Unknown PNG filter')
        for x in range(stride):
            left = row[x - 4] if x >= 4 else 0
            up = previous[x]
            upper_left = previous[x - 4] if x >= 4 else 0
            if mode == 1:
                predictor = left
            elif mode == 2:
                predictor = up
            elif mode == 3:
                predictor = (left + up) // 2
            elif mode == 4:
                p = left + up - upper_left
                distances = (abs(p - left), abs(p - up), abs(p - upper_left))
                predictor = (left, up, upper_left)[distances.index(min(distances))]
            else:
                predictor = 0
            row[x] = (row[x] + predictor) & 255
        result.extend(row)
        previous = row
    return width, height, bytes(result)


def project(name):
    with zipfile.ZipFile(ROOT / name) as archive:
        check(archive.testzip() is None, name + ': ZIP CRC')
        d = json.loads(archive.read('document.json'))
        check(d['formatIdentifier'] == 'photoaxis.document' and d['formatVersion'] == 1,
              name + ': regular schema 1')
        return d, png_rgba(archive.read('preview.png'))


presets = {
    'A04-1080-transparent.paxis': (1080, 1080, 72, None),
    'A04-landscape-white.paxis': (1920, 1080, 72, 1),
    'A04-portrait-black.paxis': (1080, 1920, 72, 0),
    'A04-A4-white.paxis': (2480, 3508, 300, 1),
    'A04-custom-640.paxis': (640, 480, 144.5, None),
    'A04-square-en.paxis': (1080, 1080, 72, None),
    'A04-landscape-en.paxis': (1920, 1080, 72, 1),
    'A04-portrait-en.paxis': (1080, 1920, 72, 0),
    'A04-A4-en.paxis': (2480, 3508, 300, 1),
    'A04-custom-en.paxis': (640, 480, 144.5, None),
}
ids, verified_projects = set(), []
for name, (w, h, ppi, background) in presets.items():
    d, (pw, ph, rgba) = project(name)
    check(d['canvas'] == {'width': w, 'height': h} and d['ppi'] == ppi, name + ': dimensions/PPI')
    check(d['sources'] == [] and d['revision'] == 0 and d['id'] not in ids, name + ': new independent document')
    ids.add(d['id'])
    if background is None:
        check(d['layers'] == [] and all(v == 0 for v in rgba[3::4]), name + ': transparent model/preview')
    else:
        check(len(d['layers']) == 1, name + ': one background')
        layer = d['layers'][0]
        check(layer['type'] == 'shape' and layer['isLocked'] and layer['isVisible'] and layer['opacity'] == 1,
              name + ': locked visible background')
        check(layer['shape']['fill'] == dict(red=background, green=background, blue=background, alpha=1),
              name + ': background RGBA')
        expected = bytes([background * 255] * 3 + [255])
        check(rgba == expected * (pw * ph), name + ': every preview pixel')
    verified_projects.append(dict(file=name, canvas=d['canvas'], ppi=d['ppi'], layers=len(d['layers']),
                                  previewDimensions=[pw, ph], sha256=hashlib.sha256((ROOT / name).read_bytes()).hexdigest()))

first, _ = project('A26-first-save-en.paxis')
check([l['type'] for l in first['layers']] == ['text', 'shape', 'shape'], 'A26 first Save: typed layers')
check([l['opacity'] for l in first['layers']] == [1, 0.6, 0.6], 'A26 first Save: opacity and duplicate')
for language in ['vi', 'en']:
    d, _ = project('A26-branch-save-' + language + '.paxis')
    check(len(d['layers']) == 1 and d['layers'][0]['type'] == 'text', 'A26 ' + language + ': removed redo shapes')
    layer = d['layers'][0]
    check(layer['opacity'] == 0.75 and layer['text']['text'] == 'Kiểm thử History' and layer['text']['fontSize'] == 24,
          'A26 ' + language + ': saved branch content')
    saved, dirty = ('Đã lưu', 'Chưa lưu') if language == 'vi' else ('Saved', 'Unsaved')
    for prefix in ['history-saved', 'history-redo-saved', 'history-branch-saved', 'history-branch-redo-saved']:
        check(saved + ' sRGB, ID: workspace.taskStatus' in ax(prefix + '-' + language), prefix + ': ' + language)
    for prefix in ['history-undo-dirty', 'history-branch-undo-dirty']:
        check(dirty + ' sRGB, ID: workspace.taskStatus' in ax(prefix + '-' + language), prefix + ': ' + language)
    check('(disabled) ' + ('Làm lại' if language == 'vi' else 'Redo') + ', ID: redoAction' in ax('history-redo-disabled-' + language),
          'A26 ' + language + ': Redo disabled')
    check('Value: Phiên tab A' in ax('tabs-a-preview-restored-' + language), 'A07 ' + language + ': preview retained across tabs')
    check('options.apply' in ax('tabs-a-preview-restored-' + language), 'A07 ' + language + ': session apply control')
    check(saved + ' sRGB, ID: workspace.taskStatus' in ax('tabs-b-undo-' + language), 'A07 ' + language + ': B Undo restores saved')
    check(dirty + ' sRGB, ID: workspace.taskStatus' in ax('tabs-b-redo-' + language), 'A07 ' + language + ': B Redo remains independent')
    check(saved + ' sRGB, ID: workspace.taskStatus' in ax('tabs-a-undo-' + language), 'A07 ' + language + ': A Undo restores saved')
    check('Value: 75 %' in ax('tabs-c-history-unchanged-' + language), 'A07 ' + language + ': C content remains unchanged')
    for field in ['width', 'ppi']:
        check('nút (disabled) ' + ('Tạo tài liệu…' if language == 'vi' else 'New Document…') in ax('preset-invalid-' + field + '-' + language),
              'A04 ' + language + ': invalid ' + field + ' disabled')
check('Tối đa 5 tài liệu' in ax('sixth-import-refused-vi'), 'A07 VI: sixth image refused')
check('At most 5 documents' in ax('sixth-project-refused-en'), 'A07 EN: sixth project refused')

telex, _ = project('A22-Telex-native-vi.paxis')
check(len(telex['layers']) == 1 and telex['layers'][0]['text']['text'] == 'tiếng việt\nthử nghiệm',
      'A22 partial VI: ASCII key events produced two Vietnamese lines in saved model')
check('Value: tiếng việt\nthử nghiệm' in ax('ime-telex-multiline-preview-vi'),
      'A22 partial VI: Return inserts newline')
check('(disabled) Áp dụng' in ax('ime-telex-escape1-vi') and 'Đã lưu sRGB' in ax('ime-telex-cancel-saved-vi'),
      'A22 partial VI: Escape restores saved state')


def stats(s):
    samples = s['samplesSeconds']
    check(s['count'] == len(samples), 'benchmark sample count')
    for key, expected in [('medianSeconds', statistics.median(samples)), ('maximumSeconds', max(samples)),
                          ('p95Seconds', sorted(samples)[math.ceil(len(samples) * .95) - 1])]:
        check(math.isclose(s[key], expected, rel_tol=1e-12, abs_tol=1e-12), 'benchmark ' + key)
    return {k: round(s[k] * 1000, 4) for k in ['medianSeconds', 'maximumSeconds', 'p95Seconds']}


open_export = json.loads((ROOT / 'benchmark-open-export.json').read_text())
benchmark = {k: stats(open_export[k]) for k in ['open', 'export']}
interactions = json.loads((ROOT / 'benchmark-interactions.json').read_text())
for key, value in interactions['interactions'].items():
    check(len(value['runs']) == 5 and all(r['count'] == 20 for r in value['runs']), key + ': five runs')
    check([s for r in value['runs'] for s in r['samplesSeconds']] == value['samplesSeconds'], key + ': flattened samples')
    fraction = sum(s <= 1 / 30 for s in value['samplesSeconds']) / len(value['samplesSeconds'])
    check(fraction == value['workerFramesWithin33msFraction'], key + ': 33.333 ms fraction')
    benchmark[key] = dict(stats(value), fractionWithin33ms=fraction, settled=stats(value['fullQualitySettledWorker']))
stress = json.loads((ROOT / 'benchmark-stress.json').read_text())
check(len(stress['cycles']) == 5 and all(c['decodedCacheAfterClose'] == 0 for c in stress['cycles']), 'stress: five cycles/cache zero')
summary = json.loads((ROOT / 'benchmark-test-summary.json').read_text())
check((summary['passedTests'], summary['failedTests'], summary['skippedTests']) == (3, 0, 0), 'benchmark xcresult: 3/0/0')
print(json.dumps(dict(status='PASS', auditAssertions=len(checks), nativeCases=['A04', 'A07', 'A26'],
                     scope='Recorded native VI/EN evidence and independent ZIP/model/preview/sample audit. Not a fresh UI run, real IME test, native FPS or target-device qualification.',
                     partialTelex='VI real ASCII key conversion/Return/CmdReturn/Cancel recorded; EN source context and VNI unverified. A22 remains open.',
                     presetProjects=verified_projects, benchmark=benchmark,
                     recoveryFiveTabsSeconds=stress['completedRecoveryFiveTabsSeconds']), ensure_ascii=False, indent=2))
