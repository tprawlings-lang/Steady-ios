# Build readiness

This documents how far the iOS app was verified without a Mac, and the exact
steps to complete a real Xcode build.

## The constraint, stated plainly

The app was built and reviewed in a Linux environment with **no macOS, no
Xcode, and no Apple SDKs** (SwiftUI, SwiftData, AVFoundation, CoreHaptics are
Apple-only). A genuine iOS compile can only happen on a Mac. Everything below is
what *was* verifiable here, plus the one command that finishes the job on a Mac.

## What was verified here

1. **Syntax — every file, real Swift grammar.** All 36 Swift files were parsed
   with `tree-sitter-swift`. Result: **0 real syntax errors.** The parser
   flagged `Networking/SyncEngine.swift`, which was traced to a known
   *grammar limitation* — it can't parse the valid Swift form
   `if let x = try? await f()`. Neutralizing only those two lines makes the file
   parse with 0 errors, confirming the flags are false positives, not defects.

2. **Project file integrity.** `Steady.xcodeproj/project.pbxproj` has balanced
   delimiters and every object reference resolves. It uses Xcode 16 synchronized
   file groups, so all files — including the newer `Networking/` and
   `Views/Pipeline/` folders — are included automatically. A **shared scheme**
   is included so `xcodebuild` works headlessly.

3. **Symbol cross-checks (catches real "no such member" compile errors).**
   - Every `Color.<name>` used is defined in the palette (no undefined colors).
   - Every `backend.<method>` call site resolves to a method defined on
     `Backend` (no missing endpoints).
   - Every file using SwiftData imports it; every `@Observable` type is imported
     and injected; no duplicate top-level type names.

4. **Contract match with the server.** Every DTO's fields and JSON keys were
   checked against the live API responses, which were themselves **exercised
   end-to-end against a real database** (full onboarding pipeline, check-in
   gating, session start/finish, and the companion incl. crisis routing). So the
   data the app decodes is known to match what the server sends.

5. **Logic correctness.** The deterministic safety/scoring ports were
   cross-checked against the original TypeScript with 23 test vectors (all
   passed), and the clinical instruments are scored server-side, not in the app.

## What could NOT be verified here

Full Swift **type-checking of the SwiftUI code** (argument labels on framework
APIs, view-builder type inference, `@MainActor` isolation under strict
concurrency). These need the Apple SDKs. The code was manually audited for the
common blockers and targets **iOS 17.0** (every API used is ≤ 17). The project
is set to **Swift 5 language mode**, which avoids strict-concurrency errors.
Expect that a first real build *may* surface a small fix or two — that's the
honest residual risk.

## Finish the build on a Mac (one command)

Requires Xcode 16+. No paid account or device needed — a Simulator build
compiles every file.

```bash
unzip Steady-iOS.zip && cd Steady
chmod +x build.sh
./build.sh            # Simulator build (fastest full compile)
```

Or directly:

```bash
xcodebuild -project Steady.xcodeproj -scheme Steady \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGNING_ALLOWED=NO clean build
```

Or just open `Steady.xcodeproj` in Xcode, pick a simulator, and press ⌘B.

If anything fails to compile, send me the exact `error:` lines and I'll fix them
fast — the surface area is small and every error message points to a file and
line.

## To actually run on your iPhone

Open in Xcode → select the **Steady** target → **Signing & Capabilities** → set
your Team and change the bundle id from `com.steady.emdr` to something unique →
pick your device → ▶︎. (For haptics and stereo tones, use a real device; the
Simulator has neither.)
