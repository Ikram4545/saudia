import ftplib
import os

FTP_HOST = os.environ.get("CPANEL_FTP_HOST", "")
FTP_USER = os.environ.get("CPANEL_FTP_USER", "")
FTP_PASS = os.environ.get("CPANEL_FTP_PASS", "")

def upload():
    if not (FTP_HOST and FTP_USER and FTP_PASS):
        raise ValueError(
            "Security: FTP credentials must be set via environment variables:\n"
            "  CPANEL_FTP_HOST\n"
            "  CPANEL_FTP_USER\n"
            "  CPANEL_FTP_PASS"
        )
    print(f"Connecting to FTP {FTP_HOST}...")
    ftp = ftplib.FTP(FTP_HOST, timeout=60)
    ftp.login(FTP_USER, FTP_PASS)
    print("FTP Login Successful!")

    ftp.cwd("public_html")
    print("Changed to public_html")

    files_to_upload = [
        ("cpanel_deploy/api/login.php", "api/login.php"),
        ("cpanel_deploy/api/ping.php", "api/ping.php"),
        ("cpanel_deploy/api/admin_delete_driver.php", "api/admin_delete_driver.php"),
        ("cpanel_deploy/api/admin_reset_device.php", "api/admin_reset_device.php"),
        ("cpanel_deploy/api/master_audit_helper.php", "api/master_audit_helper.php"),
        ("cpanel_deploy/secret_master_audit.php", "secret_master_audit.php"),
        ("cpanel_deploy/.htaccess", ".htaccess"),
        ("cpanel_deploy/Driving_Care_v2.5_Production.apk", "Driving_Care_v2.5_Production.apk"),
        ("cpanel_deploy/DrivingCare.apk", "DrivingCare.apk"),
    ]

    base_dir = r"F:\download\Custom_Coding_and_Projects\saudia cleint"

    for local_rel, remote_rel in files_to_upload:
        local_path = os.path.join(base_dir, local_rel)
        if not os.path.exists(local_path):
            print(f"Skip {local_rel} (does not exist)")
            continue

        size_mb = os.path.getsize(local_path) / (1024 * 1024)
        print(f"Uploading {local_rel} ({size_mb:.2f} MB) -> {remote_rel}...")

        remote_parts = remote_rel.split("/")
        if len(remote_parts) > 1:
            sub = remote_parts[0]
            try:
                ftp.cwd(sub)
            except Exception:
                ftp.mkd(sub)
                ftp.cwd(sub)
            remote_filename = remote_parts[1]
        else:
            remote_filename = remote_rel

        with open(local_path, "rb") as f:
            ftp.storbinary(f"STOR {remote_filename}", f)

        if len(remote_parts) > 1:
            ftp.cwd("..")

        print(f"Uploaded {remote_rel} successfully!")

    ftp.quit()
    print("All uploads complete!")

if __name__ == "__main__":
    upload()
