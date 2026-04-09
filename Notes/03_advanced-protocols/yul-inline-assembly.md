# Yul (Inline Assembly) — EVM Düzeyinde Programlama

## Nedir?

Yul, EVM'ye özel bir intermediate (ara) dildir. Normal assembly (x86/ARM) ile alakası yoktur.
Solidity kodu compile edilirken önce Yul'a, oradan EVM bytecode'una çevrilir:

```
Solidity → Yul (IR) → EVM Opcodes (Bytecode)
```

Solidity içinde `assembly { }` bloğu ile yazılır.

---

## Neden Gerekli?

Solidity bazı şeyleri yapamaz:

1. **Keyfi storage slot'una yazma/okuma**
   Solidity değişkenleri kendi layout sırasına göre yönetir.
   EIP-1967 gibi hesaplanmış bir slota ancak assembly ile ulaşılabilir.

2. **Bilinmeyen boyutlu return değeri**
   Proxy bir fonksiyonun ne döneceğini önceden bilemez (uint256 mü? string mi? struct mü?).
   Assembly ile dönen her şey tip kontrolü yapılmadan olduğu gibi iletilir.

3. **Maksimum gas optimizasyonu**
   Solidity arka planda onlarca güvenlik kontrolü ekler. Assembly bunları atlar.

---

## Temel Komutlar

### Storage (Kalıcı Depolama)

```solidity
// Yazmak: sstore(slot_numarası, değer)
assembly {
    sstore(0, 42)  // Slot 0'a 42 yaz
}

// Okumak: sload(slot_numarası) → değer döner
assembly {
    let x := sload(0)  // Slot 0'ı oku, x'e ata
}
```

### Memory (Geçici Hafıza)

```solidity
// Calldata'yı memory'ye kopyala
assembly {
    calldatacopy(0, 0, calldatasize())
    // calldatacopy(memory_offset, calldata_offset, boyut)
}

// Dönen veriyi memory'ye kopyala
assembly {
    returndatacopy(0, 0, returndatasize())
}
```

### delegatecall

```solidity
assembly {
    let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
    // delegatecall(gaz, hedef_adres, args_offset, args_boyut, ret_offset, ret_boyut)
    // Döner: 1 (başarılı) veya 0 (başarısız)
}
```

### Sonuç İşleme

```solidity
assembly {
    switch result
    case 0 { revert(0, returndatasize()) }   // Başarısız → revert
    default { return(0, returndatasize()) }  // Başarılı → return
}
```

---

## Assembly Sınırlamaları

**Constant'lar direkt kullanılamaz:**
```solidity
bytes32 constant MY_SLOT = keccak256("...");

// YANLIŞ — Assembly bunu tanımaz:
assembly { sstore(MY_SLOT, value) }

// DOĞRU — Önce yerel değişkene kopyala:
bytes32 slot = MY_SLOT;
assembly { sstore(slot, value) }
```

**`:=` atama operatörü:**
Assembly'de `=` yerine `:=` kullanılır. Yul syntax'ı, Solidity'den ayrıştırmak için.

---

## Solidity → Yul Dönüşümünü Görmek

```bash
forge inspect KontratAdı ir > output.yul
```

14 satırlık bir Solidity kontratı Yul'da 200+ satıra dönüşebilir.
Compiler'ın arkada eklediği tüm kontroller (taşma, type check, free memory pointer) orada görünür.

---

## Kullanım Alanları

| Alan | Örnek |
|---|---|
| Proxy pattern | EIP-1967 slot okuma/yazma, delegatecall forwarding |
| Gas optimizasyonu | Uniswap V3, Seaport (OpenSea) — kritik döngülerde |
| Bit manipülasyonu | Calldata'dan belirli byte aralıklarını çıkarma |
| CREATE2 | Deterministik kontrat adresi üretimi |

---

## Referanslar

- [Yul Docs (Solidity)](https://docs.soliditylang.org/en/latest/yul.html)
- [EVM Opcodes Reference](https://www.evm.codes/)
- Uygulama: `web3-lab/contracts/07_upgradeable-proxy/src/UpgradableProxy.sol`
