import importlib.util,json,unittest,tempfile,sys,plistlib
from pathlib import Path
spec=importlib.util.spec_from_file_location('distribution',Path(__file__).resolve().parents[2]/'scripts/distribution.py'); d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
class ReleasePolicyTests(unittest.TestCase):
    def valid(self):
        c={k:None for k in d.FIELDS};c.update(publisher='QA fixture publisher',appBundleID='org.photoaxisqa.application',coreBundleID='org.photoaxisqa.core',documentUTI='org.photoaxisqa.project',teamID='QA12345678',developerIDIdentity='Developer ID Application: QA fixture (QA12345678)',notaryKeychainProfile='QA-fixture-profile')
        return c
    def check(self,c,public=False):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'config.json';p.write_text(json.dumps(c));return d.config(p,public)
    def test_unknown_identity_and_missing_fields_are_blocked(self):
        with self.assertRaises(d.GateError):self.check({k:None for k in d.FIELDS})
    def test_apple_development_and_mismatched_team_are_blocked(self):
        c=self.valid();c['developerIDIdentity']='Apple Development: QA (QA12345678)'
        with self.assertRaises(d.GateError):self.check(c)
        c=self.valid();c['teamID']='ZZ12345678'
        with self.assertRaises(d.GateError):self.check(c)
    def test_no_secret_fields_and_no_development_namespace(self):
        c=self.valid();c['password']='synthetic forbidden field'
        with self.assertRaises(d.GateError):self.check(c)
        c=self.valid();c['appBundleID']='local.photoaxis.development'
        with self.assertRaises(d.GateError):self.check(c)
    def test_distinct_namespaces_and_missing_public_target(self):
        c=self.valid();c['documentUTI']=c['appBundleID']
        with self.assertRaises(d.GateError):self.check(c)
        with self.assertRaises(d.GateError):self.check(self.valid(),True)
    def test_false_release_ready_cannot_trigger_git_or_upload(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'rc.json';p.write_text(json.dumps({'releaseReady':False}))
            with self.assertRaisesRegex(d.GateError,'R02'):d.require_candidate(p)
    def test_tree_hash_detects_bytes_and_symlink_target_without_following(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);(p/'file').write_bytes(b'A');(p/'link').symlink_to('/Applications');a=d.tree_hash(p)
            (p/'file').write_bytes(b'B');self.assertNotEqual(a,d.tree_hash(p));b=d.tree_hash(p)
            (p/'link').unlink();(p/'link').symlink_to('/System');self.assertNotEqual(b,d.tree_hash(p))
    def test_machine_plist_stdout_is_not_corrupted_by_tool_stderr_warning(self):
        script="import sys,plistlib; sys.stdout.buffer.write(plistlib.dumps({'system-entities':[]})); print('tool deprecation warning',file=sys.stderr)"
        data=d.run([sys.executable,'-c',script],stdout_only=True)
        self.assertEqual(plistlib.loads(data.encode()),{'system-entities':[]})
    def test_existing_dmg_cannot_be_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'existing.dmg';p.write_bytes(b'prior-good')
            with self.assertRaises(d.GateError):d.create_dmg(Path(tmp)/'missing.app',p,Path(tmp)/'log')
            self.assertEqual(p.read_bytes(),b'prior-good')
if __name__=='__main__':unittest.main()
