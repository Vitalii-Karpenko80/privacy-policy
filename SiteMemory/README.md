# SiteMemory

> Digital memory of a construction site. Photograph what goes *behind* the wall
> before it is closed up, pin it to a real place, and find it again months later.

SiteMemory is structured so it can either be **embedded into FieldReport** as a
new capability, or shipped as a **standalone app** for the EU and North American
markets — without forking the code. The whole design turns on one rule:

> **`SiteMemoryCore` imports nothing but `Foundation`.**
> Everything Apple-specific (Vision, ARKit, SwiftUI, PhotoKit) and everything
> host-specific (FieldReport's storage, reports, invoices) lives behind
> protocols in separate targets.

That is what makes it dual-mode: the host supplies the platform and the storage;
the core supplies the domain, the geometry and the search.

---

## The chain it completes

```
Measure → Build → Photograph before closing → Report → Invoice → SiteMemory
```

FieldReport stops being "an app that makes a PDF" and becomes the durable memory
of the building. One avoided drilled pipe, or one instantly located embed
(закладная), pays for a year of subscription — which is why this can carry a
higher price than a generic utility.

---

## Package layout

| Target | Depends on | Imports | Role |
|---|---|---|---|
| **SiteMemoryCore** | — | Foundation only | Domain model, units & geometry, the planar measurement engine, and every protocol (stores, search, spatial, host bridge). Fully unit-tested, portable. |
| **SiteMemoryPersistence** | Core | Foundation | Local-first stores: `InMemoryStore` (previews/tests) and `FileStore` (standalone default). Nothing leaves the app container. |
| **SiteMemoryVision** | Core | Vision, CoreImage | On-device semantic photo search. `#if canImport(Vision)`. |
| **SiteMemoryARKit** | Core | ARKit | LiDAR/world-map spatial anchors — the "point the phone at the finished wall" overlay. `#if canImport(ARKit)`. |
| **SiteMemoryUI** | Core | SwiftUI | Thin, optional views + the `WallMemoryViewModel`. `#if canImport(SwiftUI)`. |

```
Project → Building → Floor → Room → Wall → SitePhoto → HiddenObjectAnnotation
```

Entities are flat value types linked by typed `ID<Entity>` (parent-id, not
nesting), so any one loads/saves without dragging its subtree — the shape a
SQLite/SwiftData/Core Data store maps onto directly.

---

## How the MVP measures without LiDAR

`PlanarMeasurementEngine` is the trick: the user taps a **reference** on the
photo whose real length they know (e.g. the 4.2 m wall width), then taps the
hidden objects. One known distance turns every other tap into an approximate
real position from the surface edges — *"Water pipe — 320 mm from left, 1.18 m
up"*.

Its assumptions (roughly fronto-parallel shot, lens distortion ignored) are
documented in code and reflected in a `confidence` on every result, so the UI
stays honest. **v2** swaps the engine's guts for an ARKit 3D solve behind the
*same* `SpatialAnchoring` contract — no caller changes.

---

## How search works (offline first, AI second)

A natural-language question becomes a structured `SiteQuery`, run through the
`HiddenObjectSearching` protocol:

- **`MetadataSearchIndex` (Core, always on, no AI)** — matches explicit
  annotations, saved tags, notes and dates. Zero dependencies, works on a plane.
- **`VisionHiddenObjectSearching` (Vision, on-device)** — classifies photos the
  user never hand-tagged, mapping what the model sees onto the object taxonomy,
  so *"show every wall with a water pipe behind it"* finds untagged photos too.

Both run entirely on the device. A fine-tuned Core ML model for rough-in photos
drops in behind the same protocol later.

---

## Embedding into FieldReport

FieldReport conforms to three seams in `Integration/FieldReportBridge.swift`:

- `FieldReportLinking` — tie a SiteMemory `Project` to a host project/invoice id.
- `ReportEmbedding` — receive a `WallMemoryReport` (built by the pure
  `WallMemoryReportBuilder`) and drop a *"Behind the walls"* section into its PDF.
- The `ProjectStore` / `PhotoStore` protocols — FieldReport implements these over
  its **existing** database, so wall memory reuses the host's storage.

Standalone, the app instead uses `FileStore` from `SiteMemoryPersistence` and
skips the bridge. SiteMemory never imports FieldReport in either mode.

---

## Roadmap

1. **MVP** — hierarchy, capture, two-tap reference measurement, offline search,
   PDF section. (Types, engine and tests for this are in place here.)
2. **v2 — LiDAR/ARKit** — spatial anchors + live "x-ray" overlay via
   `SpatialAnchoring` / `relocalize`.
3. **v3 — richer AI** — Core ML model trained on rough-in photos; LLM parsing of
   free-text questions into `SiteQuery`.

---

## Market / compliance notes (EU + NA)

- **Local-first by construction.** No accounts, no analytics, no third-party SDKs
  (the manifest has zero dependencies), on-device Vision. This inherits and keeps
  FieldReport's privacy posture and is the simplest possible GDPR story for EU
  jobsites — personal/site data never leaves the device.
- **Units are a presentation concern.** Everything is stored in metres; `Length`
  formats to mm (EU) or inch/foot (NA), defaulting from the site's country code.
- **Localization-ready.** `ObjectCategory` display strings resolve through the UI
  bundle, so `de`/`fr`/`es`/`en-GB`/`en-US` are added as `.strings`, not code.

> A privacy-policy page for SiteMemory can follow the existing pattern in this
> repo (`index.html`, `koshtorys-privacy.html`) when the app is submitted.

---

## Building & testing

```bash
cd SiteMemory
swift test        # exercises SiteMemoryCore (engine, search, units) on macOS/Linux-with-Foundation
```

> Note: this package was scaffolded on a Linux box without a Swift/Xcode
> toolchain, so it has **not been compiled here**. The Core target and its tests
> are written to build with Foundation alone; the Vision/ARKit/SwiftUI targets
> are guarded with `#if canImport(...)` and are meant to be built from Xcode
> against an iOS SDK.
