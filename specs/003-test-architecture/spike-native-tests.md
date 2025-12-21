# Spike Results: Native secp256k1 C Tests (T006/T007)

**Date**: 2025-12-18  
**Task**: T006 - Test Tuist commandLineTool for native C tests  
**Status**: ✅ **SUCCESS** (after retry with subtree extraction)

---

## Attempt 1: Direct Vendor Path (FAILED)

Added `NativeSecp256k1Tests` target pointing directly to `../Vendor/secp256k1/src/tests.c`:

**Result**: ❌ Linking failed — missing precomputed tables

```
Undefined symbols: _secp256k1_ecmult_gen_prec_table, _secp256k1_pre_g, _secp256k1_pre_g_128
```

---

## Attempt 2: Subtree Extraction (SUCCESS)

### Solution

1. Added extraction to `subtree.yaml`:
```yaml
- from:
  - 'src/tests.c'
  - 'src/precomputed_ecmult.c'
  - 'src/precomputed_ecmult_gen.c'
  to: Projects/Sources/NativeSecp256k1Tests/
```

2. Updated `Projects/Project.swift` with proper configuration matching root Package.swift

### Result: ✅ BUILD SUCCEEDED

```
test count = 1
random seed = 3934896d5c5ebee938afb6b09041f4cf
no problems found
Exit code: 0
```

---

## Final Configuration

### subtree.yaml extraction
```yaml
- from:
  - 'src/tests.c'
  - 'src/precomputed_ecmult.c'
  - 'src/precomputed_ecmult_gen.c'
  to: Projects/Sources/NativeSecp256k1Tests/
```

### Project.swift target
```swift
.target(
    name: "NativeSecp256k1Tests",
    destinations: [.mac],
    product: .commandLineTool,
    bundleId: "dev.21.NativeSecp256k1Tests",
    sources: ["Sources/NativeSecp256k1Tests/**"],
    settings: .settings(
        base: [
            "GCC_PREPROCESSOR_DEFINITIONS": [
                "$(inherited)", "VERIFY=1",
                "ECMULT_GEN_PREC_BITS=4", "ECMULT_WINDOW_SIZE=15",
                "ENABLE_MODULE_ECDH=1", "ENABLE_MODULE_ELLSWIFT=1",
                "ENABLE_MODULE_EXTRAKEYS=1", "ENABLE_MODULE_MUSIG=1",
                "ENABLE_MODULE_RECOVERY=1", "ENABLE_MODULE_SCHNORRSIG=1"
            ],
            "HEADER_SEARCH_PATHS": [
                "$(inherited)",
                "$(SRCROOT)/../Vendor/secp256k1",
                "$(SRCROOT)/../Vendor/secp256k1/src",
                "$(SRCROOT)/../Vendor/secp256k1/include"
            ]
        ]
    )
)
```

---

## Key Learnings

1. **Precomputed tables are required** — `tests.c` includes `secp256k1.c` which needs the precomputed ecmult tables
2. **Subtree extraction is cleaner** — Using `subtree.yaml` keeps sources managed and versioned
3. **Header paths resolve correctly** — Test headers like `testrand_impl.h` resolve via HEADER_SEARCH_PATHS to Vendor/

## Files Modified

- `subtree.yaml` — Added extraction for tests.c and precomputed tables
- `Projects/Project.swift` — Added NativeSecp256k1Tests commandLineTool target
- `Projects/Sources/NativeSecp256k1Tests/src/` — Extracted C source files
