# Steady — native iOS app (first version)

A native **SwiftUI** iOS app for **Steady**, the self-guided EMDR-based wellness
program. This is a from-scratch native build — not a WebView wrapper — that
reimplements the core member experience with faithful ports of the web app's
safety logic and content, plus native capabilities a web app can't offer:
smooth Core Animation bilateral stimulation, real stereo audio panning, and
**Core Haptics** left/right taps.

> Prototype, wellness lane. Not therapy, not medical care, not for emergencies.
> If you are in danger, call or text 988 or call 911.

## Requirements

- Xcode 16 or newer
- iOS 17.0+ (uses SwiftData, `@Observable`, `TimelineView`)
- A physical device is recommended to feel the **haptics** and stereo tones
  (the Simulator has no haptics and limited audio panning).

## Open & run

1. Open `Steady.xcodeproj` in Xcode.
2. Select the **Steady** scheme and a device/simulator.
3. Set your own Team under *Signing & Capabilities* (bundle id is
   `com.steady.emdr` — change it to yours).
4. Press ▶︎.

The project uses Xcode 16 **synchronized file groups**, so every file under
`Steady/` is included automatically — there's no per-file list to maintain. If
the project ever fails to open, regenerate it: `brew install xcodegen` then
`xcodegen generate` (see `project.yml`).

## What's implemented

Everything here runs **fully on-device**, no backend required:

- **Onboarding** — wellness acknowledgment, preferred name, calm-place word,
  audio-only (photosensitivity) preference.
- **Daily check-in** — the 7-item readiness check, with the exact deterministic
  routing from the web app (`Checkin.evaluate`, ported from `evaluateCheckin`):
  crisis → grounding-only → stabilization → cleared.
- **Guided session player** — the heart of the app. Ported step-for-step from
  the web `SessionPlayer`:
  - Bilateral stimulation, native: a `TimelineView` moving dot, **stereo**
    396 Hz tones panned hard left/right (`AVAudioEngine`), and synchronized
    **haptic** taps (`CoreHaptics`). Audio-only mode for photosensitivity.
  - SUDS distress ratings between sets, with the real safety rules
    (`SessionSafety`, ported from `session-safety.ts`): pause at 8, hard-stop at
    9, mid-session rise ≥ 3 → pause, wind-down at 35 min, hard cap at 45 min.
  - "Ground me" persistent exit, grounding flow, and the hard-stop safety
    screen with crisis routing.
  - Guided talk-through narration (authored "beats", `{calmPlace}`/`{name}`
    slots), one line at a time.
- **Program** — all **12 modules** ported verbatim (`ModuleCatalog`), tiered
  (autonomous / specialist-gated / maintenance). Gated modules are locked and
  can be simulated open in Settings.
- **Grounding tools** — always-open breathing pacer, 5-4-3-2-1, calm place.
- **Crisis resources** — region-aware, tap-to-call/text, with the
  "not monitored in real time" honesty line.
- **History & trend** — sessions and check-ins persist via **SwiftData**; the
  dashboard shows a distress trend across recent sessions.

## Project structure

```
Steady/
  SteadyApp.swift            App entry + SwiftData container
  Theme/Theme.swift          Brand palette (ported from globals.css) + components
  Safety/                    Pure, deterministic logic — direct ports
    SessionSafety.swift      sudsDecision + caps  (session-safety.ts)
    Checkin.swift            evaluateCheckin      (gating.ts)
    Readiness.swift          scoreReadiness       (safety/readiness.ts)
  Models/
    Module.swift             TherapyModule + all 12 modules (modules.ts)
    Records.swift            SwiftData models (sessions, check-ins)
    CrisisResources.swift    crisis-resources.ts
  Session/                   The native session engine
    SessionPlayerView.swift  State machine (SessionPlayer.tsx)
    BLSVisualView.swift      Moving-dot bilateral stimulation
    BilateralEngine.swift    Stereo audio + haptics
    AudioPulser.swift        Audio-only pulse timer
    NarrationView.swift      Guided talk-through
  Views/                     Onboarding, Dashboard, Check-in, Grounding, Crisis,
                             ModuleDetail, Root/Settings
  Store/AppState.swift       Profile + preferences (UserDefaults)
```

## Collaborative sync with the web app (implemented)

The app now works standalone **and** syncs with the shared Steady account when
signed in, so one person can move between the website and the phone with their
check-ins, sessions, and progress following them.

How it works:

- **On-device by default.** With no server configured, the app runs fully
  locally exactly as before — no account needed.
- **Sign in to sync.** Set a **Server URL** and sign in (Settings → Account &
  sync, or the login screen that appears once a server is set) with the same
  member account as the website. The app authenticates with the web app's own
  HMAC session token as a Bearer token.
- **What syncs:** daily check-ins, sessions + SUDS trails and outcomes, and
  in-session safety events (`ground_me_pressed`, `suds_pause`, time caps) — the
  same audit trail the clinician dashboard reads. Module locks are
  server-governed when signed in (`checkModuleAccess`), so the phone shows the
  same availability the web does.
- **Offline-first & safe.** The deterministic safety rules always run locally
  and never wait on the network. Writes are saved locally immediately;
  check-ins created offline are queued (`synced` flag) and pushed on the next
  sync, and the account's history is pulled down and merged (deduped by server
  id / calendar day) so nothing double-counts.

The networking lives in `Steady/Networking/` (`Backend.swift` API client,
`DTOs.swift` contract, `SyncEngine.swift` reconcile, `Keychain.swift` token,
plus `LoginView.swift`). The matching server-side API ships separately as
`steady-backend-mobile-api.zip` (drop-in files for your Next.js repo) — see its
`MOBILE-API.md` for endpoints and install steps.

### The server side (already built)

The web app's member features run on **Next.js Server Actions**, not a REST
API. The companion `steady-backend-mobile-api.zip` adds the thin **JSON API
layer** that both clients share. It currently exposes:

- **Auth / session** — `login` (Bearer token) + `me` (user, gating, modules).
- **Gating** — server-governed module access + today's check-in gate.
- **Sync** — submit + list check-ins; start / finish / list sessions.
- **Safety telemetry** — `ground_me_pressed`, `suds_pause`, `session_time_cap`,
  `session_winddown_shown`, and hard-stops → the clinician audit log.

Still to wire (future): the AI companion + in-session live responder (keep the
Anthropic key server-side, never in the app), and pushing the trigger map to the
encrypted server store.

The deterministic safety rules are deliberately duplicated **client-side**
(they must work with no network and never depend on a server round-trip); the
server stays the source of truth and the client copy is a safety floor.

## Notes & deliberate scope cuts for v1

- No signup/billing/consent/screening flow in-app yet — sign-in assumes an
  existing member account created on the web; those gates are enforced
  server-side (a signed-in member who hasn't finished consent/screening will see
  the matching lock reason on modules).
- No AI companion or voice — those require the backend + API key.
- Specialist gating is server-governed when signed in; simulated locally
  (Settings toggle) in on-device mode.
- Offline sessions stay local until you're signed in and online; check-ins queue
  and push automatically.
- Crisis numbers carry a `lastVerified` date — keep them current (owner + review
  cadence as in the web app).
