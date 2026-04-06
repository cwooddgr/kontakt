# Kontakt

A beautifully designed drop-in replacement for Apple's iOS Contacts app.

Less, but better.

---

## Why

Apple's Contacts app has been functionally neglected for over a decade. Pasting an address is torture. Search is shallow. Editing feels like a government form. The design wastes half the screen on a giant monogram circle.

Kontakt fixes all of it.

## What

- **Freeform address input** — paste a full address, Kontakt parses it. No more distributing text across four fields.
- **On-device AI parsing** — on iPhone 15 Pro+ with iOS 26, the Foundation Models framework handles all natural language parsing (addresses, contact creation, duplicate detection). Older devices get a regex + MapKit fallback.
- **Smart search** — searches across name, company, email, phone, address, and notes. Fuzzy matching, phone number normalization, relevance ranking.
- **Inline editing** — tap any field to edit in place. No Edit → scroll → change → Done ceremony.
- **Contact cleanup** *(Phase 2)* — card-stack triage UI for pruning stale contacts.
- **Zero lock-in** — reads and writes the system `CNContactStore`. No proprietary database, no account, no sync service. Switch back anytime.

## Design

Strictly adherent to Apple Human Interface Guidelines for iOS 26. Additionally Dieter Rams-inspired: every element earns its place. No visual noise, no feature creep.

- Information density prioritized — more contacts per screen than Apple's app
- Monochrome palette with a single slate blue accent
- Whitespace separates, not lines
- No colored contact backgrounds, no giant avatar circles
- Action buttons only shown when data exists — no greyed-out buttons

## Tech Stack

- **SwiftUI** — iOS 18+, fully custom UI (no `CNContactViewController`)
- **Foundation Models** — on-device LLM with `@Generable` structured output (Tier 1, iOS 26+)
- **NaturalLanguage + Regex** — fallback parsing (Tier 2, iOS 18–25)
- **Contacts framework** — `CNContactStore` as the sole data layer
- **Swift 6** — strict concurrency, `@Observable`, `Sendable`

## Project Structure

```
Kontakt/
├── App/            # Entry point, app state
├── Models/         # ContactWrapper, parsed types, search results
├── Services/       # ContactStore, parsers (AI + regex), search engine
├── Views/
│   ├── ContactList/   # Primary screen, row, section index
│   ├── ContactCard/   # Detail view, action bar, fields, notes
│   ├── Editing/       # Inline editor, full edit, freeform address
│   ├── Creation/      # New contact, parse preview
│   └── Shared/        # Onboarding, settings, design components
├── Utilities/      # Design tokens, extensions, haptics
└── Resources/      # Assets, localization
```

## Building

Requires Xcode 16+ with iOS 18+ SDK.

```bash
# Generate the Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Build
xcodebuild build -scheme Kontakt -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Test
xcodebuild test -scheme Kontakt -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Or open `Kontakt.xcodeproj` in Xcode and hit Run.

## Development Phases

| Phase | Scope | Status |
|-------|-------|--------|
| 1 — Foundation | Contact list, card, search, freeform input, editing, pinning | **Complete** |
| 2 — Cleanup | Triage card-stack, smart filters, widgets, My Card QR | Planned |
| 3 — Refinement | Groups, CallKit recents, iPad, localization, Shortcuts | Planned |
| 4 — macOS | macOS support | Planned |

## Free

No IAP, no subscription, no ads, no analytics, no tracking. A gift to the community from [DGR Labs](https://github.com/cwooddgr).

---

*Built with taste by one person who was tired of cringing every time he opened Apple's Contacts app.*
