# PairSlice — Xcode Setup Guide

A step-by-step guide to get the project building and running in Xcode.

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| Xcode | 15.0 |
| macOS (dev machine) | 13.0 Ventura |
| iOS deployment target | 16.0 |
| Swift | 5.9 / Swift 6 |

---

## Step 1 — Create the Xcode Project

1. Open Xcode → **File › New › Project**
2. Choose **iOS › App**
3. Fill in:
   - **Product Name**: `PairSlice`
   - **Bundle Identifier**: `com.pairslice.app` (or your own)
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Include Tests**: Optional (recommended)
4. Save in the folder **above** this `PairSlice/` directory.
5. **Delete** the auto-generated `ContentView.swift` — it will be replaced by our files.

---

## Step 2 — Add Source Files

Drag the entire **`Sources/`** folder (from this directory) into the Xcode project navigator.  
When prompted, select:
- ✅ **Copy items if needed**
- ✅ **Create groups**
- Target membership: **PairSlice**

The final folder structure in Xcode should mirror:
```
PairSlice/
├── PairSliceApp.swift
├── Models/
├── Services/
├── ViewModels/
└── Views/
    └── Components/
```

---

## Step 3 — Enable Mac Catalyst

1. Select the **PairSlice** target in Xcode
2. **General** tab → **Deployment Info**
3. Check **Mac** (Mac Catalyst)
4. Set **Mac Idiom** to **Scale to match iPad** (safer for pixel-based UI)

---

## Step 4 — Add Google Mobile Ads SDK (AdMob)

1. **File › Add Package Dependencies…**
2. Search for: `https://github.com/googleads/swift-package-manager-google-mobile-ads`
3. Set version rule: **Up to Next Major → 11.0.0**
4. Add to target: **PairSlice** only (not test targets)
5. In **Frameworks, Libraries, and Embedded Content**: set `GoogleMobileAds.xcframework` to **Embed & Sign**

---

## Step 5 — Configure Info.plist

Open `Info.plist` and add the keys from `Info.plist.template`:

| Key | Your value |
|---|---|
| `GADApplicationIdentifier` | Your AdMob App ID (format: `ca-app-pub-…~…`) |
| `NSUserTrackingUsageDescription` | Already filled in template |
| `NSPhotoLibraryAddUsageDescription` | Already filled in template |

> **Get your AdMob App ID** at [admob.google.com](https://admob.google.com) →  
> Apps → Add App → iOS → Copy the App ID.

---

## Step 6 — Configure AdMob Ad Unit ID

1. In AdMob console: Apps → your app → Ad units → **+ Create ad unit**
2. Choose **Rewarded** type
3. Copy the ad unit ID (format: `ca-app-pub-…/…`)
4. Open `Sources/Services/AdManager.swift`
5. Replace the test ID:
   ```swift
   // TODO: Replace with your real AdMob Rewarded Ad Unit ID
   static let adUnitID = "ca-app-pub-3940256099942544/1712485313"
   // ↑ Change this to your real ID ↑
   ```

---

## Step 7 — Enable In-App Purchase Capability

1. Select **PairSlice** target → **Signing & Capabilities**
2. Click **+ Capability** → add **In-App Purchase**
3. Sign in to your Apple Developer account if prompted

---

## Step 8 — Set Up App Store Connect Product

> Skip this during initial development — the local `.storekit` file handles testing.

For production:
1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Create a new App with Bundle ID `com.pairslice.app`
3. **In-App Purchases** → **+** → **Non-Consumable**
4. Reference Name: `PairSlice Premium`
5. Product ID: `com.pairslice.premium`
6. Price: **$2.99** (Tier 3)
7. Add localizations and submit for review alongside the app

---

## Step 9 — Configure Local StoreKit Testing

1. Drag `PairSlice.storekit` from this folder into the Xcode project navigator
2. **Edit Scheme** (⌘⇧<) → **Run** → **Options** tab
3. Set **StoreKit Configuration** → `PairSlice.storekit`
4. Now purchases work in the simulator without a real App Store account

---

## Step 10 — Enable AdMob SDK in Code

Once you have your real AdMob App ID in `Info.plist`:

1. Open `Sources/PairSliceApp.swift`
2. Uncomment the two `GADMobileAds.sharedInstance().start()` lines (there are two — one in `init()` and one in `requestTrackingPermission()`)

---

## Step 11 — Build & Run

```
Product › Run  ⌘R
```

Test on:
- **iPhone Simulator** (iOS 16+) — full functionality
- **Mac (My Mac - Designed for iPad)** — Watch Ad button hidden, purchase works

---

## Monetisation Flow Summary

```
User taps "Split Image"
        │
        ▼
purchaseState == .premium?
   YES → Split immediately
   NO
        │
        ▼
PaywallView sheet appears
        │
        ├── Watch Ad → rewarded ad → split unlocked
        └── $2.99 → StoreKit purchase → premium forever
```

---

## TODO Items Checklist

- [ ] Replace `GADApplicationIdentifier` in `Info.plist` with real AdMob App ID  
- [ ] Replace `adUnitID` in `AdManager.swift` with real Rewarded Ad Unit ID  
- [ ] Uncomment `GADMobileAds.sharedInstance().start()` in `PairSliceApp.swift`  
- [ ] Create product `com.pairslice.premium` in App Store Connect  
- [ ] Design and export App Icon (1024×1024 px, black background with scissors)  
- [ ] Test purchase flow in sandbox (testflight or real device)  
- [ ] Test ad flow with test device ID added to AdMob console  
- [ ] Add `NSATSExceptionDomains` if any ad networks require HTTP (AdMob uses HTTPS only)  

---

## Common Issues

| Problem | Fix |
|---|---|
| App crashes on launch | `GADApplicationIdentifier` missing or wrong in `Info.plist` |
| "Product not available" | StoreKit config not set in scheme, or product ID mismatch |
| Ad never loads | Test ID works only in debug; real device needs real ad unit ID |
| Photos not saving on Mac | Expected — `PHPhotoLibrary` on Mac Catalyst behaves differently; test on iPhone |
| Split line on wrong axis | EXIF orientation normalization handles this automatically |

---

## Project File Map

```
PairSlice/
├── SETUP.md                          ← this file
├── PairSlice.storekit                ← local in-app purchase sandbox config
├── Info.plist.template               ← copy keys into Xcode's Info.plist
│
└── Sources/
    ├── PairSliceApp.swift            ← @main entry point
    │
    ├── Models/
    │   ├── SplitResult.swift         ← { left: UIImage, right: UIImage }
    │   ├── PurchaseState.swift       ← enum: unknown / premium / free
    │   └── AppError.swift            ← all app errors
    │
    ├── Services/
    │   ├── ImageSplitterService.swift ← pixel-accurate vertical crop
    │   ├── StoreManager.swift         ← StoreKit 2: purchase / entitlement
    │   ├── AdManager.swift            ← AdMob rewarded ads
    │   ├── ImageLoaderService.swift   ← URLSession image download
    │   └── PhotoLibraryService.swift  ← Camera Roll save
    │
    ├── ViewModels/
    │   ├── HomeViewModel.swift        ← all 4 load paths → UIImage
    │   ├── SplitViewModel.swift       ← paywall gate + split orchestration
    │   └── PaywallViewModel.swift     ← purchase + ad coordination
    │
    └── Views/
        ├── HomeView.swift             ← drop zone, pickers, URL sheet
        ├── PreviewView.swift          ← image + split-line overlay
        ├── ResultView.swift           ← both halves + save button
        ├── PaywallView.swift          ← Watch Ad / Unlock $2.99
        └── Components/
            ├── DropZoneView.swift     ← animated dashed border
            └── ImageThumbnailView.swift
```
