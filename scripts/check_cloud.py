#!/usr/bin/env python3
"""Live smoke check. Creates two temporary accounts, tests isolation, then removes them.
Run explicitly: python3 scripts/check_cloud.py --live
Never prints tokens/passwords. Uses only the app's public configuration.
"""
import base64, json, plistlib, secrets, sys, urllib.request, urllib.error
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
CONFIG = plistlib.loads((ROOT / 'MonArchive/GoogleService-Info.plist').read_bytes())
KEY, PROJECT = CONFIG['API_KEY'], CONFIG['PROJECT_ID']
SB = 'https://etkucvnppsvgpqytlhwe.supabase.co'
PUB = 'sb_publishable_gcvtomO0PrDmrIRWtfFxJg_UutZyfJp'

def call(method, url, body=None, headers=None, raw=False):
    data = body if raw else (json.dumps(body).encode() if body is not None else None)
    h = {'Content-Type': 'application/json', **(headers or {})}
    request = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            data = response.read()
            return response.status, data if raw else (json.loads(data) if data else {})
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:500]

def auth(action, body):
    return call('POST', f'https://identitytoolkit.googleapis.com/v1/accounts:{action}?key={KEY}', body)

def bearer(token): return {'Authorization': 'Bearer ' + token}
def storage_headers(token): return {**bearer(token), 'apikey': PUB}

def main():
    if '--live' not in sys.argv:
        raise SystemExit('Pass --live to create temporary test accounts and run the cloud checks.')
    accounts = []
    doc_url = None
    photo_path = None
    failure = None
    try:
        for _ in range(2):
            email = 'mono-check-' + secrets.token_hex(10) + '@example.test'
            password = secrets.token_urlsafe(24)
            status, result = auth('signUp', {'email': email, 'password': password, 'returnSecureToken': True})
            assert status == 200, f'Create temporary account: HTTP {status}'
            accounts.append({**result, 'password': password, 'email': email})
        a, b = accounts
        uid, token = a['localId'], a['idToken']
        doc_url = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents/users/{uid}/items/cloud-check-{secrets.token_hex(8)}'
        document = {'fields': {'deleted': {'booleanValue': False}, 'payload': {'stringValue': '{"test":true}'}}}
        status, _ = call('PATCH', doc_url, document, bearer(token))
        assert status == 200, f'Own document write: HTTP {status}'
        status, _ = call('GET', doc_url, headers=bearer(b['idToken']))
        assert status == 403, f'Cross-account document access must be denied, got HTTP {status}'
        print('PASS: Firestore upload and account isolation')
        status, signed_in = auth('signInWithPassword', {'email': a['email'], 'password': a['password'], 'returnSecureToken': True})
        assert status == 200
        fresh_token = signed_in['idToken']
        status, _ = call('GET', doc_url, headers=bearer(fresh_token))
        assert status == 200, f'Fresh login read: HTTP {status}'
        print('PASS: Fresh login can recover cloud data')
        photo_path = uid + '/cloud-check-' + secrets.token_hex(8) + '.png'
        png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')
        url = SB + '/storage/v1/object/collectible-images/' + photo_path
        status, _ = call('POST', url, png, {**storage_headers(token), 'Content-Type': 'image/png', 'x-upsert': 'true'}, raw=True)
        assert status == 200, f'Private image upload: HTTP {status}'
        download = SB + '/storage/v1/object/authenticated/collectible-images/' + photo_path
        status, data = call('GET', download, headers=storage_headers(fresh_token), raw=True)
        assert status == 200 and data == png, f'Fresh login image read: HTTP {status}'
        status, _ = call('GET', download, headers=storage_headers(b['idToken']), raw=True)
        assert status in (400, 401, 403, 404), f'Cross-account image read must be denied: HTTP {status}'
        status, _ = call('GET', download, headers={'apikey': PUB}, raw=True)
        assert status in (400, 401, 403, 404), f'Unauthenticated image read must be denied: HTTP {status}'
        print('PASS: Private image upload, recovery, cross-account and guest isolation')
    except Exception as e:
        failure = str(e)
    finally:
        if accounts:
            token = accounts[0]['idToken']
            if photo_path:
                status, _ = call('DELETE', SB + '/storage/v1/object/collectible-images', {'prefixes': [photo_path]}, storage_headers(token))
                if status != 200: print('WARNING: Check Storage for temporary cloud-check image cleanup')
            if doc_url:
                status, _ = call('DELETE', doc_url, headers=bearer(token))
                if status not in (200, 404): print('WARNING: Check Firestore for temporary cloud-check record cleanup')
            for a in accounts:
                status, _ = auth('delete', {'idToken': a['idToken']})
                if status != 200: print('WARNING: Remove temporary mono-check account in Firebase Authentication')
        if failure: raise SystemExit('FAIL: ' + failure)
        print('PASS: Temporary test data and accounts removed')
if __name__ == '__main__': main()
