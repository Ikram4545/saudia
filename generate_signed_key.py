import sys
import os
import re
import json
import time
import base64
from cryptography.hazmat.primitives.asymmetric import ed25519

# Rotated Master Ed25519 Public Key (Verified in client code)
MASTER_PUB_HEX = "d63f4fcdd57a0c44e3084f0c4cdd74d83864f3f2f1bf3c7c070c561df779627e"

def get_master_seed() -> str:
    # 1. Check environment variable first
    env_seed = os.environ.get("DRIVING_CARE_MASTER_SEED")
    if env_seed and len(env_seed.strip()) == 64:
        return env_seed.strip()
    
    # 2. Check local untracked config file (gitignored)
    config_path = os.path.join(os.path.dirname(__file__), "cpanel_deploy", "api", "license_keys_config.php")
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                content = f.read()
                m = re.search(r"['\"]seedHex['\"]\s*=>\s*['\"]([a-fA-F0-9]{64})['\"]", content)
                if m:
                    return m.group(1)
        except Exception:
            pass
            
    raise ValueError(
        "Master Private Seed not found!\n"
        "Security Rule: Master seed is never hardcoded in repo files.\n"
        "Set the DRIVING_CARE_MASTER_SEED environment variable or create untracked cpanel_deploy/api/license_keys_config.php"
    )

def generate_signed_key(driver_name: str, days: int = 30, custom_key: str = None) -> dict:
    seed_hex = get_master_seed()
    key_id = custom_key.upper().strip() if custom_key else f"DC-{int(time.time()) % 10000:04d}"
    exp_ms = int((time.time() + (days * 86400)) * 1000)
    
    payload = {
        "key": key_id,
        "name": driver_name.strip(),
        "days": days,
        "exp": exp_ms
    }
    
    payload_json = json.dumps(payload, separators=(',', ':'), ensure_ascii=False)
    payload_b64 = base64.b64encode(payload_json.encode('utf-8')).decode('ascii')
    
    # Sign payload_b64 using Ed25519
    seed_bytes = bytes.fromhex(seed_hex)
    priv_key = ed25519.Ed25519PrivateKey.from_private_bytes(seed_bytes)
    sig_bytes = priv_key.sign(payload_b64.encode('utf-8'))
    sig_b64 = base64.b64encode(sig_bytes).decode('ascii')
    
    signed_key = f"DCS-{payload_b64}.{sig_b64}"
    
    return {
        "key": key_id,
        "name": driver_name,
        "days": days,
        "expires_at": time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(exp_ms / 1000)),
        "signed_key": signed_key
    }

if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "Saudi Driver"
    days = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    custom = sys.argv[3] if len(sys.argv) > 3 else None
    
    res = generate_signed_key(name, days, custom)
    print("=" * 60)
    print("DRIVING CARE (SAUDI) — OFFLINE CRYPTOGRAPHIC SIGNED KEY")
    print("=" * 60)
    print(f"Driver Name:  {res['name']}")
    print(f"Key ID:       {res['key']}")
    print(f"Validity:     {res['days']} Din ({res['expires_at']})")
    print("\nOFFLINE SIGNED KEY (Copy & Give to Driver):")
    print("-" * 60)
    print(res['signed_key'])
    print("-" * 60)
    print("NOTE: Ye key Airplane Mode mein bhi 100% unlock karti hai!")
    print("=" * 60)
