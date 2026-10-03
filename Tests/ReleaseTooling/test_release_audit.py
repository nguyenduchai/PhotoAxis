import importlib.util,sys,json,tempfile,unittest,io
from unittest.mock import patch,Mock
from pathlib import Path
scripts=Path(__file__).resolve().parents[2]/'scripts';sys.path.insert(0,str(scripts))
spec=importlib.util.spec_from_file_location('audit',scripts/'release-audit.py');a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
class PublicationAuditTests(unittest.TestCase):
    def test_missing_configuration_and_unaccepted_gates_list_all_blockers(self):
        with tempfile.TemporaryDirectory() as tmp:
            plan=Path(tmp)/'plan.json';plan.write_text(json.dumps({'publicReady':False}))
            ledger=Path(tmp)/'ledger.json';ledger.write_text(json.dumps({n:{'status':'BLOCKED_EXTERNAL','evidence':[]} for n in a.REQUIRED}))
            with patch.object(a.dist,'require_candidate',side_effect=a.dist.GateError('synthetic unaccepted R02')):
                r=a.preflight(a.ROOT/'Config/Distribution.example.json',plan,ledger)
            self.assertFalse(r['publicReady']);self.assertFalse(r['mutationPerformed']);self.assertEqual(len(r['results']),12);self.assertTrue(any('R02' in x for x in r['blockingReasons']))
    def test_local_unsigned_manifest_cannot_be_promoted_by_boolean(self):
        m=json.loads((a.ROOT/'docs/bao-cao/bang-chung/P13/distribution-manifest.json').read_text());m['publicReady']=True
        with self.assertRaises(a.dist.GateError):a.validate_public_manifest(m,{})
    def test_old_build_cannot_be_published_as_current_investigation_build(self):
        version,build=a.dist.version_build()
        m={'status':'SIGNED_NOTARIZED_PENDING_INSTALL_TEST','artifact':'PhotoAxis-1.0.0-arm64.dmg','version':version,'build':str(int(build)-1),'architecture':'arm64','minimumOS':'14.0'}
        with self.assertRaisesRegex(a.dist.GateError,'version/build'):a.validate_public_manifest(m,{})
    def test_pass_without_real_evidence_or_path_outside_repository_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);ledger={n:{'status':'PASS','evidence':[]} for n in a.REQUIRED};self.assertEqual(set(a.gate_ledger(ledger,root)),set(a.REQUIRED))
            (root/'record.md').write_text('synthetic gate evidence');ledger={n:{'status':'PASS','evidence':['record.md']} for n in a.REQUIRED};self.assertEqual(a.gate_ledger(ledger,root),[])
            ledger['R02']['evidence']=['/etc/hosts'];self.assertIn('R02',a.gate_ledger(ledger,root))
    def test_http_download_refused_before_request_or_destination_creation(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest=Path(tmp)/'asset'
            with self.assertRaises(a.dist.GateError):a.anonymous_download('http://127.0.0.1/asset',dest)
            self.assertFalse(dest.exists())
    def response(self,data):
        response=io.BytesIO(data);response.status=200;response.url='https://example.invalid/synthetic';response.headers={};return response
    def test_wrong_public_checksum_discards_partial_and_never_creates_final(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest=Path(tmp)/'download.dmg';opener=Mock();opener.open.return_value=self.response(b'synthetic wrong artifact')
            with patch.object(a.urllib.request,'build_opener',return_value=opener):
                with self.assertRaisesRegex(a.dist.GateError,'checksum'):a.anonymous_download('https://example.invalid/synthetic',dest,'0'*64)
            self.assertFalse(dest.exists());self.assertFalse(dest.with_name(dest.name+'.partial').exists())
            request=opener.open.call_args.args[0];self.assertIsNone(request.get_header('Authorization'));self.assertIsNone(request.get_header('Cookie'))
    def test_anonymous_download_enforces_size_before_promotion(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest=Path(tmp)/'download.dmg';opener=Mock();opener.open.return_value=self.response(b'oversized synthetic artifact')
            with patch.object(a.urllib.request,'build_opener',return_value=opener):
                with self.assertRaisesRegex(a.dist.GateError,'size limit'):a.anonymous_download('https://example.invalid/synthetic',dest,max_bytes=3)
            self.assertFalse(dest.exists());self.assertFalse(dest.with_name(dest.name+'.partial').exists())
    def test_https_redirect_cannot_downgrade_to_http(self):
        with self.assertRaises(a.dist.GateError):a.HTTPSOnlyRedirect().redirect_request(None,None,302,'Found',{},'http://example.invalid/asset')
if __name__=='__main__':unittest.main()
