# Testing Steady without your own Mac

Two separate pieces have to be running to test the app end-to-end:

1. **The backend** (the Next.js app) — hosted somewhere the phone can reach.
2. **The iOS app** — compiled by Xcode (needs Apple's toolchain) and run on a
   Simulator or a real iPhone.

The backend is easy to put online. The iOS app is the part that needs a Mac —
so below are the online ("cloud Mac") ways to do it without buying one.

---

## A. Get the backend online (10 minutes)

The web repo already ships deploy configs: `render.yaml`, `fly.toml`, and a
`Dockerfile`. Easiest is **Render**:

1. Push the web app repo to GitHub.
2. On render.com → New → Blueprint → pick the repo. It reads `render.yaml`,
   creates the service + a persistent disk, and auto-generates
   `EMDR_SESSION_SECRET` and `EMDR_DATA_KEY`.
3. In the service's **Environment** tab, optionally add `ANTHROPIC_API_KEY` to
   turn on the real AI companion (without it, the built-in rules engine still
   works). `render.yaml` already sets `EMDR_DEMO=1`, which also enables the
   live-voice responder.
4. You get an https URL like `https://steady-emdr-demo.onrender.com`. That's
   what you'll type into the app's **Server URL**.

(Fly.io works too: `fly launch` picks up `fly.toml`. Or run locally and expose
it with a tunnel like `cloudflared tunnel` / `ngrok http 3000`.)

### Backend env vars that matter for testing

| Var | Why |
|---|---|
| `EMDR_SESSION_SECRET` | Auth token signing (use 32+ random chars). Auto-set by render.yaml. |
| `EMDR_DATA_KEY` | Encrypts member free text at rest. Auto-set by render.yaml. |
| `ANTHROPIC_API_KEY` | Optional — enables the AI companion + voice rephrasing. Falls back to rules engine if absent. |
| `EMDR_DEMO=1` **or** `EMDR_LIVE_SESSION=1` | Enables the hands-free voice responder. render.yaml sets `EMDR_DEMO=1`. |

---

## B. Build & run the iOS app online (pick one)

You cannot compile a native iOS app in a plain browser — Apple's compiler only
runs on macOS. But you can rent/borrow a Mac in the cloud:

### 1. Just confirm it compiles — FREE, no Mac (GitHub Actions)
The included `.github/workflows/ios-build.yml` runs on Apple's macOS runners.
Push this project to GitHub and open the **Actions** tab — it compiles every
file and shows any `error:` lines. This is the fastest way to shake out compile
issues and it costs nothing on the free tier. It does **not** let you tap
through the app; it only verifies the build.

### 2. Actually tap through it — rent a cloud Mac (from a few $/hour)
Services give you a real macOS desktop in the browser with Xcode installed:
**MacinCloud**, **MyRemoteMac**, **AWS EC2 Mac**, **Scaleway Mac mini**. Open
`Steady.xcodeproj`, pick an iPhone Simulator, press ⌘R. Good for testing the UI
and all the flows.

### 3. Build in CI, then run in a browser Simulator
CI services (**Codemagic**, **Bitrise**, **Xcode Cloud**) build the app; upload
the resulting build to **Appetize.io** to run it in a browser Simulator you can
share. (Appetize runs a build — it can't create one.)

### 4. Run on your own iPhone
Open the project on any Mac (yours or a cloud Mac), set **Signing & Capabilities
→ Team**, change the bundle id from `com.steady.emdr` to something unique, plug
in your iPhone, press ▶︎.
- A **free Apple ID** works for a 7-day on-device install.
- The **Apple Developer Program** ($99/yr) is only needed for **TestFlight**
  (30-day, shareable with testers) or the App Store.

---

## C. What only works on a REAL iPhone (not the Simulator)

The three things that make this app special don't exist in the Simulator:

- **Haptics** — the bilateral left/right taps (Core Haptics). Simulator: none.
- **Stereo audio panning** — the alternating tones. Simulator: unreliable.
- **Microphone + on-device speech** — the hands-free voice responder. Simulator:
  no mic; speech recognition won't work.

So: use the **cloud-Mac Simulator** to verify the UI, onboarding, check-ins,
companion chat, and navigation — but to truly test **bilateral haptics and live
voice**, install on a **physical iPhone** (option B4). On first voice use the
app will ask for **microphone** and **speech recognition** permission — allow both.

---

## D. Fastest realistic path

1. Deploy the backend to Render (A).
2. Push this project to GitHub; let the Actions workflow confirm it compiles (B1).
3. Fix any compile errors it surfaces (send them to me — each points to a file
   and line).
4. For a real feel: spin up a cloud Mac (B2) or install on your iPhone via a
   cloud Mac (B4), set the Server URL to your Render URL, sign up, and go.
