#!/usr/bin/env python3
"""Validate local bilingual static pages, links, download state and asset provenance."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit,unquote
import hashlib,json
ROOT=Path(__file__).resolve().parent.parent;SITE=ROOT/'website'
class Page(HTMLParser):
    def __init__(self,text):
        super().__init__();self.links=[];self.ids=set();self.lang=None;self.buttons=[];self.images=[];self.meta={};self.scripts=[];self.titles=0;self.feed(text)
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag=='html':self.lang=a.get('lang')
        if 'id' in a:self.ids.add(a['id'])
        if tag=='a' and 'href' in a:self.links.append(a['href'])
        if tag=='link' and 'href' in a:self.links.append(a['href'])
        if tag=='img':self.images.append(a);self.links.append(a['src'])
        if tag=='button':self.buttons.append(a)
        if tag=='meta' and 'name' in a:self.meta[a['name']]=a.get('content')
        if tag=='script':self.scripts.append(a)
        if tag=='title':self.titles+=1
pages={p:Page(p.read_text()) for p in SITE.rglob('*.html')};assert len(pages)==12
status=json.loads((SITE/'release-status.json').read_text());assert status['publicReady'] is False
site_url=status['websiteURL'].rstrip('/')+'/'
repository=status['sourceRepository']
assert status['sourceLicense']=='GPL-3.0-only'
for p,page in pages.items():
    assert page.lang==('en' if p.parent.name=='en' else 'vi'),p
    assert page.titles==1 and page.meta.get('viewport') and page.meta.get('description') and page.meta.get('robots')=='noindex,nofollow',p
    assert not page.scripts,'No tracking or script needed in preview'
    assert all('alt' in a for a in page.images),p
    if p.name=='index.html':assert len(page.buttons)==1 and 'disabled' in page.buttons[0],p
    for href in page.links:
        u=urlsplit(href)
        if u.scheme:
            allowed=(href=='https://zlib.net/zlib_license.html' or href=='https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement' or href==repository or href.startswith(repository+'/') or href.startswith(site_url))
            assert u.scheme=='https' and allowed,href
            if href.startswith(site_url):
                target=SITE/unquote(href[len(site_url):])
                assert target.is_file(),href
            continue
        assert href and href!='#' and not u.netloc,href
        target=(p.parent/unquote(u.path)).resolve() if u.path else p
        assert target.is_relative_to(SITE.resolve()) and target.is_file(),(p,href)
        if u.fragment:assert u.fragment in pages[target].ids,(p,href)
for row in json.loads((SITE/'asset-provenance.json').read_text()):
    source=ROOT/row['source'];artifact=SITE/row['file']
    assert hashlib.sha256(source.read_bytes()).hexdigest()==row['sourceSHA256'],source
    assert hashlib.sha256(artifact.read_bytes()).hexdigest()==row.get('artifactSHA256',row['sourceSHA256']),artifact
    if 'buildManifest' in row:assert (ROOT/row['buildManifest']).is_file()
print('PASS: 12 vi/en pages; local links/anchors/metadata/alt/disabled download/owned asset provenance; no scripts/trackers')
print('PASS: configured GitHub Pages canonical/alternate paths and GPLv3 source links; installer remains disabled')
