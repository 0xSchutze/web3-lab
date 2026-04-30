import ecdsa
from Crypto.Hash import keccak

def keccak256(data):
    k = keccak.new(digest_bits=256)
    k.update(data)
    return k.digest()

alice_sig = bytes.fromhex("ab1dcd2a2a1c697715a62eb6522b7999d04aa952ffa2619988737ee675d9494f2b50ecce40040bcb29b5a8ca1da875968085f22b7c0a50f29a4851396251de121c")
voucherHash = bytes.fromhex("87f1c8cd4c0e19511304b612a9b4996f8c2bd795796636bd25812cd5b0b6a973")
v = alice_sig[64]

curve = ecdsa.SECP256k1
G = curve.generator
n = curve.order

recid = v - 27

# Use _with_digest to pass the pre-computed hash!
public_keys = ecdsa.keys.VerifyingKey.from_public_key_recovery_with_digest(alice_sig[:64], voucherHash, curve)
Q = public_keys[recid].pubkey.point

uncompressed = Q.x().to_bytes(32, 'big') + Q.y().to_bytes(32, 'big')
alice_addr = keccak256(uncompressed)[12:]
print("Recovered Alice address: 0x" + alice_addr.hex())

# 2. Pick random u1 and u2 to forge a signature
u1 = 12345
u2 = 67890

# 3. Calculate R = u1*G + u2*Q
R = u1 * G + u2 * Q
forged_r = R.x() % n

# 4. Calculate forged_s and forged_z (amount)
u2_inv = pow(u2, n - 2, n)
forged_s = (forged_r * u2_inv) % n
forged_z = (u1 * forged_r * u2_inv) % n

forged_v = 27 + (R.y() % 2)

if forged_s > n // 2:
    forged_s = n - forged_s
    forged_v = 28 if forged_v == 27 else 27

print("EXISTENTIAL FORGERY SUCCESSFUL")
print(f"uint256 forgedAmount = {forged_z};")
print(f"bytes memory forgedTokenOwnerSignature = hex\"{forged_r:064x}{forged_s:064x}{forged_v:02x}\";")
