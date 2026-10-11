import os
import subprocess
import zipfile
import shutil

BASE_DIR = r"F:\download\saudia cleint"
SRC_APK = os.path.join(BASE_DIR, "Driving_Care_v1.0.apk")
UNSIGNED_APK = os.path.join(BASE_DIR, "Driving_Care_unsigned.apk")
ALIGNED_APK = os.path.join(BASE_DIR, "Driving_Care_aligned.apk")
FINAL_APK = os.path.join(BASE_DIR, "Driving_Care_v2.0_Installable.apk")
KEYSTORE = os.path.join(BASE_DIR, "driving_care.keystore")

ZIPALIGN = r"F:\tools\android-sdk\build-tools\34.0.0\zipalign.exe"
APKSIGNER = r"F:\tools\android-sdk\build-tools\34.0.0\apksigner.bat"
JAVA_HOME = r"F:\tools\jdk-17"

env = os.environ.copy()
env["JAVA_HOME"] = JAVA_HOME
env["PATH"] = f"{JAVA_HOME}\\bin;{os.path.dirname(APKSIGNER)};" + env.get("PATH", "")

print("Step 1: Stripping all existing META-INF files...")
with zipfile.ZipFile(SRC_APK, 'r') as zin:
    with zipfile.ZipFile(UNSIGNED_APK, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            # Strip EVERYTHING under META-INF so no orphaned .version or signature files remain
            if item.filename.startswith('META-INF/'):
                continue
            data = zin.read(item.filename)
            # Store uncompressed for .so and resources.arsc to allow zipalign 4-byte alignment
            if item.filename.endswith('.so') or item.filename == 'resources.arsc':
                zinfo = zipfile.ZipInfo(item.filename)
                zinfo.compress_type = zipfile.ZIP_STORED
                zout.writestr(zinfo, data)
            else:
                zout.writestr(item, data)

print(f"Created clean unsigned APK: {UNSIGNED_APK} ({os.path.getsize(UNSIGNED_APK)} bytes)")

print("Step 2: Running Google Android SDK zipalign...")
res = subprocess.run([ZIPALIGN, "-p", "-f", "4", UNSIGNED_APK, ALIGNED_APK], capture_output=True, text=True, env=env)
print("zipalign stdout:", res.stdout)
print("zipalign stderr:", res.stderr)
if res.returncode != 0:
    print("Zipalign failed!")
    exit(1)

print(f"Aligned APK created: {ALIGNED_APK} ({os.path.getsize(ALIGNED_APK)} bytes)")

print("Step 3: Signing with official Google apksigner (v1, v2, v3)...")
sign_cmd = [
    APKSIGNER, "sign",
    "--ks", KEYSTORE,
    "--ks-pass", "pass:driving123",
    "--key-pass", "pass:driving123",
    "--ks-key-alias", "drivingcare",
    "--v1-signing-enabled", "true",
    "--v2-signing-enabled", "true",
    "--v3-signing-enabled", "true",
    "--out", FINAL_APK,
    ALIGNED_APK
]
res = subprocess.run(sign_cmd, capture_output=True, text=True, env=env)
print("apksigner stdout:", res.stdout)
print("apksigner stderr:", res.stderr)
if res.returncode != 0:
    print("Apksigner sign failed!")
    exit(1)

print(f"SUCCESS: Final installable APK created: {FINAL_APK} ({os.path.getsize(FINAL_APK)} bytes)")

print("Step 4: Verifying final APK with apksigner verify...")
verify_cmd = [APKSIGNER, "verify", "-v", "--print-certs", FINAL_APK]
res = subprocess.run(verify_cmd, capture_output=True, text=True, env=env)
print(res.stdout[:500])
if "Verifies" in res.stdout and "Verified using v1 scheme (JAR signing): true" in res.stdout and "Verified using v2 scheme (APK Signature Scheme v2): true" in res.stdout:
    print("VERIFICATION 100% PASSED! APK IS READY FOR MOBILE PHONES!")
else:
    print("Verification warning:", res.stderr)
