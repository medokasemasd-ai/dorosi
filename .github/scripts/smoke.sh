#!/usr/bin/env bash
# Installs the APK on the emulator, opens the app and checks it is still
# running without errors. Leaves a screenshot and the log in smoke/.
set -x
mkdir -p smoke
# Install an older release first, so the new build must install over it like on the phone.
if [ -f previous.apk ]; then
  adb install previous.apk || { echo "::error::Could not install the previous release"; exit 1; }
  if ! adb install -r dorosi.apk 2>&1 | tee smoke/upgrade.txt; then :; fi
  if ! grep -q Success smoke/upgrade.txt; then echo "::error::The new build does not install over the previous release"; exit 1; fi
else
  adb install -r dorosi.apk
fi
adb shell pm grant com.aboelkasem.dorosi android.permission.POST_NOTIFICATIONS || true
adb logcat -c
adb shell am start -W -n com.aboelkasem.dorosi/.MainActivity
sleep 30
adb exec-out screencap -p > smoke/screen.png
adb logcat -d > smoke/logcat.txt
adb shell pidof com.aboelkasem.dorosi > smoke/pid.txt || true
grep -E "flutter|AndroidRuntime|dorosi" smoke/logcat.txt | tail -80
fail=0
if ! [ -s smoke/pid.txt ]; then echo "::error::The app is not running"; fail=1; fi
if grep -q "FATAL EXCEPTION" smoke/logcat.txt; then echo "::error::The app crashed"; fail=1; fi
if grep -q "Unhandled Exception" smoke/logcat.txt; then echo "::error::Dart error on start"; fail=1; fi
exit $fail
