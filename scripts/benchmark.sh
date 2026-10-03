#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/environment.sh"
python3 scripts/generate-project.py --check
mkdir -p "$PHOTOAXIS_BUILD_ROOT/test-results"
result="$PHOTOAXIS_BUILD_ROOT/test-results/Benchmark-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
xcodebuild -project PhotoAxis.xcodeproj -scheme PhotoAxisBenchmark -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$PHOTOAXIS_BUILD_ROOT/DerivedData" \
  -resultBundlePath "$result" -only-testing:PhotoAxisAppTests/BenchmarkTests \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= ENABLE_TESTABILITY=YES test
echo "Benchmark result: $result"
python3 - "$result" <<'PY_CHECK'
import json,subprocess,sys
r=json.loads(subprocess.check_output(['xcrun','xcresulttool','get','test-results','summary','--path',sys.argv[1]]))
assert r['passedTests']==3 and r['failedTests']==0 and r['skippedTests']==0, 'Benchmark was not actually measured: '+str({k:r[k] for k in ['passedTests','failedTests','skippedTests']})
print('PASS: all 3 Release benchmark cases executed, no skips')
PY_CHECK
