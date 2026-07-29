import SwiftUI

/// Shared marketing/onboarding content, mirroring the web landing + signup
/// pages word-for-word so the story never shifts between platforms. Claims
/// policy matches the web: research claims are about the METHOD (with
/// citations), never this product; product claims describe shipped behavior
/// only; pricing matches lib/billing PLANS on the server.
enum Marketing {

    // Research stats band — RCT/meta-analysis claims only, citations on every
    // card (same three as the web landing page).
    struct ResearchStat: Identifiable {
        var id: String { stat }
        let stat: String
        let text: String
        let source: String
        let url: String
    }

    static let guidelinesLine =
        "EMDR is recommended as a frontline PTSD treatment in clinical guidelines from the World Health Organization, the UK's NICE, and the U.S. Department of Veterans Affairs."

    static let researchStats: [ResearchStat] = [
        ResearchStat(
            stat: "26 trials",
            text: "A meta-analysis of 26 randomized controlled trials spanning two decades found EMDR significantly reduced symptoms of PTSD, depression, and anxiety.",
            source: "Chen et al., PLOS ONE (2014)",
            url: "https://doi.org/10.1371/journal.pone.0103676"),
        ResearchStat(
            stat: "61%",
            text: "of participants in a randomized controlled trial no longer met PTSD criteria after just two EMDR sessions — versus 10% in the control group.",
            source: "Yurtsever et al., Frontiers in Psychology (2018)",
            url: "https://doi.org/10.3389/fpsyg.2018.00493"),
        ResearchStat(
            stat: "10 hospitals",
            text: "In a multisite randomized controlled trial across 10 hospitals, fully remote EMDR produced large reductions in PTSD, anxiety, and depression among frontline health workers.",
            source: "Jarero et al., multisite RCT (2020)",
            url: "https://doi.org/10.1080/20008198.2020.1860346"),
    ]

    static let researchCaveat =
        "Findings describe EMDR delivered by trained clinicians, in person and remotely. Steady is a self-guided companion, not a replacement for therapy, and screens for who it can safely serve."

    // The daily toolkit — every tile is shipped product (web #your-day).
    struct ToolkitTile: Identifiable {
        var id: String { name }
        let name: String
        let note: String
    }

    static let dailyToolkit: [ToolkitTile] = [
        ToolkitTile(name: "Breathe", note: "Five paced patterns, from a quick reset to a slow wind-down. No-hold options always available."),
        ToolkitTile(name: "Meditate", note: "Short guided practices — orienting, calm place, self-compassion — read aloud or as text."),
        ToolkitTile(name: "Move", note: "Gentle guided movement: orienting turns, rooting down, shaking off held stress. Seated options throughout."),
        ToolkitTile(name: "Sleep", note: "Wind-downs to do lying down in the dark, that trail off into permission to sleep."),
        ToolkitTile(name: "Learn", note: "Two-to-four-minute reads that make sense of the work — the window of tolerance, triggers, why the method helps."),
        ToolkitTile(name: "SOS", note: "One tap, on every screen: your calm place, your grounding tools, your safe person, and the crisis line."),
    ]

    static let titrationLine =
        "On harder days, gentler practices surface first — automatically."

    // Autopilot — the Premium story (web #autopilot). The safety framing is
    // the engine's real invariant, not marketing.
    static let autopilotHeadline = "Steady runs the program with you"
    static let autopilotBody =
        "Most apps wait for you to show up. Autopilot acts between sessions: it composes your day each morning from your check-in and your history, reaches out when you've gone quiet or a rough stretch shows in your measures, and adapts your pacing automatically — always inside the same safety gates, only ever making a day gentler."

    // Tier summary for signup/welcome previews. SubscribeView remains the
    // full picker; these mirror lib/billing PLANS labels/taglines/prices.
    struct TierSummary: Identifiable {
        var id: String { name }
        let name: String
        let tagline: String
        let price: String
    }

    static let tiers: [TierSummary] = [
        TierSummary(name: "Base", tagline: "A calmer daily practice", price: "$6.99 / month"),
        TierSummary(name: "Plus", tagline: "A program that remembers you", price: "$19.99 / month"),
        TierSummary(name: "Premium", tagline: "Steady runs your program with you", price: "$34.99 / month"),
    ]

    static let trialLine =
        "Every membership begins with 7 days of Premium, free — the full program, the companion, Autopilot, everything. Cancel anytime."

    static let safetyAlwaysOpenLine =
        "Crisis support, grounding, and SOS stay open to everyone — on every tier, and on none."
}
