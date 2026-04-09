# Proxy Pattern & Upgradeability

## Problem

Smart contract'lar deploy edildikten sonra immutable'dır — kod değiştirilemez.
Gerçek protokoller bug fix, yeni feature ve güvenlik yamaları yapmak zorunda kalır.
Çözüm: Proxy Pattern.

---

## Temel Mimari

```
Kullanıcı → Proxy (sabit adres) ──delegatecall──► Implementation (değişebilir)
```

- **Proxy:** Adres sabittir. Kendi logic'i yoktur. Gelen her isteği implementation'a yönlendirir.
- **Implementation:** Asıl iş mantığı burada. Upgrade = yeni implementation deploy et, proxy'nin işaret ettiği adresi değiştir.
- **State:** Her zaman Proxy'de kalır. Implementation upgrade edilse bile data bozulmaz.

---

## delegatecall

EVM'deki iki farklı çağrı tipi:

| | `call` | `delegatecall` |
|---|---|---|
| Çalışan kod | Hedef kontratın kodu | Hedef kontratın kodu |
| Storage | Hedef kontratın storage'ı | **Çağıran kontratın storage'ı** |
| `msg.sender` | Çağıran kontrat | **Orijinal kullanıcı korunur** |

`delegatecall` ile Implementation'ın bytecode'u Proxy'nin içinde, Proxy'nin ortam değişkenleriyle çalışır.
Implementation asla tetiklenmez — sadece kodu ödünç alınır.

```solidity
// Proxy._delegate() içinde:
let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
// → impl'in kodu çalışır ama storage değişiklikleri Proxy'e yazılır
```

---

## Storage Layout ve Collision

EVM state değişkenlerini slot numarasına göre saklar (uint256, 0'dan başlar):

```solidity
contract Implementation {
    uint256 public counter; // slot 0
}

contract Proxy {
    address public implementation; // slot 0  ← ÇAKIŞMA!
}
```

Proxy, `delegatecall` ile Implementation'ı çalıştırdığında,
`counter += 1` komutu aslında `implementation` adresinin üzerine yazar.
Proxy kullanılamaz hale gelir. Bu olaya **Storage Collision** denir.

---

## EIP-1967 — Çözüm

Proxy'nin hayati verilerini (implementation adresi, admin adresi) sıradan
Slot 0/1/2 yerine keccak256 hash'inden türetilmiş rastgele bir slota yaz:

```solidity
bytes32 constant _IMPLEMENTATION_SLOT =
    bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

bytes32 constant _ADMIN_SLOT =
    bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
```

`2^256` olasılıklı uzayda bu hash değerleriyle normal değişken çakışması
matematiksel olarak imkânsızdır. Bu slotlara Assembly ile erişilir:

```solidity
// Yazmak (sstore):
assembly { sstore(slot, value) }

// Okumak (sload):
assembly { value := sload(slot) }
```

---

## Transparent Proxy Akışı

Kullanıcı Proxy'ye `increment()` çağırır:
1. Proxy'de `increment()` diye bir fonksiyon yoktur.
2. `fallback()` tetiklenir.
3. `fallback` → `_delegate()` çağırır.
4. `_delegate()` içinde `_IMPLEMENTATION_SLOT`'tan implementation adresi okunur.
5. `delegatecall(impl, calldata)` — Implementation'ın kodu Proxy'de çalışır.
6. Dönen veri (`returndatacopy`) olduğu gibi kullanıcıya iletilir.

Admin `upgradeTo(newImpl)` çağırır:
1. `onlyOwner` modifier: `_ADMIN_SLOT` okunur, `msg.sender == admin` kontrol edilir.
2. `_IMPLEMENTATION_SLOT`'a yeni adres yazılır.
3. Bir sonraki kullanıcı çağrısında yeni implementation devreye girer.
4. Proxy storage'ı (tüm state) bozulmadan kalır.

---

## Transparent vs UUPS

| | Transparent Proxy | UUPS |
|---|---|---|
| Upgrade fonksiyonu | Proxy'nin içinde | Implementation'ın içinde |
| Gas maliyeti | Daha yüksek (her çağrıda admin kontrolü) | Daha düşük |
| Güvenlik riski | Admin selector clash riski | Upgrade mantığını yeni implementation'a taşıma riski |
| Yaygınlık | OpenZeppelin v4 ve öncesi varsayılan | OpenZeppelin v5 önerilen |

---

## Güvenlik Notları

**Function Selector Clash:**
Proxy'nin kendi public fonksiyonları (upgradeTo, admin) Implementation'daki bir
fonksiyonla aynı 4-byte selector'a sahip olabilir. Transparent Proxy bunu önlemek
için admin çağrılarını direkt işler, diğerlerini delegatecall'a yollar.

**Storage Collision:**
Implementation V2 yazılırken V1 ile aynı storage layout korunmalıdır.
Yeni değişkenler her zaman en sona eklenir, aradaki hiçbir şey değiştirilmez.

**Uninitialized Implementation:**
`upgradeTo(address(0))` veya `upgradeTo(randomAddress)` çağrısı Proxy'yi kaldırmaz
ama kullanılamaz hale getirir. İyi implementasyonlar yeni adresin kontrat olduğunu
doğrular (`newImpl.code.length > 0`).

---

## Referanslar

- [EIP-1967 — Standard Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [OpenZeppelin Proxy Contracts](https://docs.openzeppelin.com/contracts/4.x/api/proxy)
- Uygulama: `web3-lab/contracts/07_upgradeable-proxy/`
