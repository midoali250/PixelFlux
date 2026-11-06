#!/usr/bin/env bash
set -euo pipefail
APK=$(find android/app/build/outputs/apk/debug -name '*.apk' -type f -print -quit);test -n "$APK"
PKG=com.pixelflux.app
ACT=com.bitvaultengine.retrocollection.MainActivity
adb install "$APK"
adb shell wm size 640x1280
adb logcat -G 16M || true
adb logcat -c
adb shell am start -n "$PKG/$ACT" --ez pixel_ci_smoke true
for i in $(seq 1 60); do if adb logcat -d -s AKG_ANDROID:I | grep PLAYER_READY >/dev/null;then break;fi;sleep 2;done
adb logcat -d -s AKG_ANDROID:I | grep PLAYER_READY >/dev/null
adb shell input swipe 50 270 115 270 350
adb logcat -d -s AKG_ANDROID_INPUT:I | tr -d '\r' > "${RUNNER_TEMP:-/tmp}/pixel-input.log"
grep -q 'core=128$' "${RUNNER_TEMP:-/tmp}/pixel-input.log" || { echo 'FAIL: joystick direction did not reach the core';exit 1; }
for DATA in '1152 448 1' '1024 512 2' '1024 384 4' '896 448 8';do
 read -r X Y FACE <<< "$DATA";adb shell input swipe "$X" "$Y" "$X" "$Y" 300
 adb logcat -d -s AKG_ANDROID_TOUCH:I > "${RUNNER_TEMP:-/tmp}/pixel-touch.log"
 grep -q "faces=$FACE" "${RUNNER_TEMP:-/tmp}/pixel-touch.log" || { echo "FAIL: face button $FACE not recorded";exit 1; }
done
for i in $(seq 1 90); do if adb logcat -d -s AKG_ANDROID_SMOKE:I | grep 'PASS' >/dev/null;then break;fi;sleep 2;done
adb logcat -d -s AKG_ANDROID_SMOKE:I | grep PASS
echo 'PASS PixelFlux Android four face controls and free joystick reached core'
echo "PASS debug game input smoke"
adb shell am force-stop "$PKG";adb logcat -c;adb shell am start -n "$PKG/$ACT"
for i in $(seq 1 40); do if adb logcat -d -s AKG_ANDROID:I | grep PLAYER_READY >/dev/null;then break;fi;sleep 2;done
adb logcat -d -s AKG_ANDROID:I | grep PLAYER_READY >/dev/null
python3 - <<'PY'
import subprocess,time,xml.etree.ElementTree as ET,re
for _ in range(15):
 try:
  subprocess.run(['adb','shell','uiautomator','dump','/sdcard/pixel-home.xml'],check=True,stdout=subprocess.DEVNULL,timeout=30)
  xml=subprocess.check_output(['adb','exec-out','cat','/sdcard/pixel-home.xml'],timeout=20).decode();root=ET.fromstring(xml)
  texts=[n.get('text','') for n in root.iter('node')]
  if 'PixelFlux' in texts and 'Settings' in texts and 'About' in texts:
   assert not any(re.search(r'\bplay\b',x,re.I) for x in texts),texts
   print('PASS Android launch automatically opens embedded cartridge without a Play button');break
 except Exception:pass
 time.sleep(1)
else:raise RuntimeError('Embedded home screen failed')
PY
adb shell input swipe 860 595 860 595 250
for i in $(seq 1 20); do if adb logcat -d -s PIXELFLUX_LAYOUT:I | grep GAME_FULLSCREEN >/dev/null;then break;fi;sleep 1;done
adb logcat -d -s PIXELFLUX_LAYOUT:I | grep GAME_FULLSCREEN >/dev/null
adb shell input tap 640 45
python3 - <<'PY'
import subprocess,time,re,xml.etree.ElementTree as ET
def adb(*a):return subprocess.check_output(['adb',*a],timeout=30)
def tap_text(text):
 for i in range(15):
  try:
   adb('shell','uiautomator','dump','/sdcard/pixel-back.xml');root=ET.fromstring(adb('exec-out','cat','/sdcard/pixel-back.xml'))
   n=next(n for n in root.iter('node') if n.get('text','').casefold()==text.casefold())
   m=re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',n.get('bounds',''));x1,y1,x2,y2=map(int,m.groups());adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));return
  except Exception:time.sleep(1)
 raise RuntimeError('Menu item unavailable: '+text)
tap_text('Back to cartridge menu');tap_text('Return to menu')
PY
for i in $(seq 1 20); do if adb logcat -d -s PIXELFLUX_LAYOUT:I | grep CORE_RESET >/dev/null;then break;fi;sleep 1;done
adb logcat -d -s PIXELFLUX_LAYOUT:I | grep CORE_RESET >/dev/null
echo 'PASS Android expands on Start and returns to cartridge menu'
