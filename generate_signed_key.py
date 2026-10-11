import sys
import json
import time
import base64
from cryptography.hazmat.primitives.asymmetric import ed25519

MASTER_SEED_HEX = "21f7e0b59e44c07d32b47b1aa0f0094e9ce664a45f169a7e8fb84b3eb7b34437"
MASTER_PUB_HEX  = "4d33b73ef90afd009626442d74ce1d593cd6db64f1d23b83d1ecbcb33a9588e9"

def generate_signed_key(driver_name: str, days: int = 30, custom_key: str = None) -> dict:
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
    seed_bytes = bytes.fromhex(MASTER_SEED_HEX)
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
