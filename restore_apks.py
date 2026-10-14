import os
import shutil

rb_dir = r"F:\$RECYCLE.BIN\S-1-5-21-194288298-3412382942-335905099-1001"
dst_dir = r"F:\download\saudia cleint"

src_base = os.path.join(rb_dir, "$RZQAQQW.apk")
src_dc   = os.path.join(rb_dir, "$RLURQYR.apk")

dst_base = os.path.join(dst_dir, "base.apk")
dst_dc   = os.path.join(dst_dir, "Driving_Care_v1.0.apk")

print(f"Copying {src_base} ({os.path.getsize(src_base)} bytes) -> {dst_base}")
shutil.copyfile(src_base, dst_base)

print(f"Copying {src_dc} ({os.path.getsize(src_dc)} bytes) -> {dst_dc}")
shutil.copyfile(src_dc, dst_dc)

print("SUCCESSFULLY RESTORED BOTH APKS!")
