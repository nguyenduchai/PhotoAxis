#!/usr/bin/env python3
"""Verify an anonymous HTTPS Pages deployment against its commit and file hashes."""
import argparse, concurrent.futures, hashlib, json, ssl
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin, urlsplit
from urllib.request import Request, HTTPSHandler, HTTPRedirectHandler, build_opener

class HTTPSRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, url):
        if urlsplit(url).scheme != 'https':
            raise ValueError('Refusing HTTPS downgrade')
        return super().redirect_request(request, fp, code, message, headers, url)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url', required=True)
parser.add_argument('--commit', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
if urlsplit(args.url).scheme != 'https':
    parser.error('HTTPS is required')
base = args.url.rstrip('/') + '/'

def fetch(path):
    if path.startswith('/') or '..' in Path(path).parts or urlsplit(path).scheme:
        raise ValueError('Invalid site path: ' + path)
    # No credentials or cookies; normal certificate verification, HTTPS redirects only.
    opener = build_opener(HTTPSHandler(context=ssl.create_default_context()), HTTPSRedirect())
    request = Request(urljoin(base, path), headers={'User-Agent': 'PhotoAxis-Deployment-Check/1', 'Cache-Control': 'no-cache'})
    with opener.open(request, timeout=30) as response:
        data = response.read(20 * 1024 * 1024 + 1)
        if response.status != 200 or len(data) > 20 * 1024 * 1024:
            raise ValueError('Invalid HTTP status or oversized file: ' + path)
        if urlsplit(response.url).scheme != 'https':
            raise ValueError('Non-HTTPS final URL')
        return data

manifest = json.loads(fetch('deployment-manifest.json'))
if manifest['sourceCommit'] != args.commit:
    raise SystemExit('Deployment commit differs: ' + manifest['sourceCommit'])
if manifest['installerPublicReady'] is not False:
    raise SystemExit('This check is for the source/development website, not installer promotion')

def check(item):
    path, expected = item
    data = fetch(path)
    actual = hashlib.sha256(data).hexdigest()
    if actual != expected:
        raise ValueError('Deployed bytes differ: ' + path)
    return {'file': path, 'status': 'PASS', 'httpStatus': 200, 'sha256': actual, 'bytes': len(data)}

http_files = dict(manifest['files'])
control_files = dict(manifest.get('controlFiles', {}))
# First deployment recorded this empty Pages/Jekyll control file with HTTP files.
# GitHub Pages does not expose dotfiles as public URLs. It is not an HTTP resource.
if '.nojekyll' in http_files:
    control_files['.nojekyll'] = http_files.pop('.nojekyll')
assert all(name == '.nojekyll' and sha == hashlib.sha256(b'').hexdigest()
           for name, sha in control_files.items())
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
    files = sorted(executor.map(check, http_files.items()), key=lambda row: row['file'])
status = json.loads(fetch('release-status.json'))
assert status['publicReady'] is False and status['sourceLicense'] == 'GPL-3.0-only'
result = {'status': 'PASS', 'checkedAt': datetime.now(timezone.utc).isoformat(),
          'websiteURL': base, 'sourceCommit': args.commit, 'anonymousHTTPS': True,
          'installerPublicReady': False, 'artifactControlFilesNotHTTPResources': control_files,
          'files': files}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2) + '\n')
print(f'PASS: {len(files)} deployed files, anonymous HTTPS, SHA256 and source commit {args.commit}')
