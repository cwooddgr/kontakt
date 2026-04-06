# Kontakt — A Contacts App for Humans

**Product Specification v1.0**
*DGR Labs — April 2026*

---

## Vision

Kontakt is a free, beautifully designed drop-in replacement for Apple's iOS Contacts app. It reads and writes the system contact store directly — no account, no sync service, no lock-in. It is the contacts app Apple would ship today if they started from scratch: purposeful, calm, and respectful of your time.

Design language: Strictly adherent to Apple Human Interface Guideilnes for iOS 26, iPadOS 26, and macOS 26 for the respective apps. Furthermore, and where it doesn't conflict with Apple's HIG, strongly Dieter Rams-inspired. Less, but better. Every element earns its place. No visual noise, no feature creep, no CRM ambitions. Just the core experience of managing the people in your life, done with craft and care. 

Offered completely free of charge — no IAP, no subscription, no ads — as a gift to the community from a solo developer who was tired of cringing every time he opened Apple's Contacts app.

---

## The Problem

Apple's Contacts app has been functionally neglected for over a decade. The community frustration is deep and well-documented:

- **Pasting an address is torture.** You copy a single-line address from a text or website, then manually distribute it across four separate fields (street, city, state, zip). Apple's own Maps, Mail, and Siri all parse freeform addresses. Contacts never got that treatment.

- **Editing feels like a government form.** Modal edit screens, rigid field-by-field entry, no inline editing. Every change requires tap → Edit → scroll → change → Done. It's 2007-era interaction design preserved in amber.

- **Search is shallow.** You can't reliably search by company, city, notes content, or partial name. If you can't remember someone's exact first or last name, good luck.

- **Duplicate management is clumsy.** iOS 16 finally brought duplicate detection (a feature macOS had since 2005), but the merge UI is still awkward, the matching is simplistic, and bulk operations are nonexistent.

- **Notes are buried and unreliable.** Users report notes disappearing after edits. The notes field is invisible until you're in edit mode. There's no timestamp capability, no way to append quickly.

- **Copying contact info is broken.** In recent macOS/iOS versions, you can't reliably copy a contact's name, company, or other fields. Pasting a name into an email produces oversized centered text.

- **No sense of recency or frequency.** The only view is the A–Z scroll list. There's no way to surface the 20 people you actually contact regularly without manually maintaining a Favorites list.

- **Visual design is dated.** Excessive padding wastes screen space. The giant contact poster / initials circle consumes half the screen for no functional benefit. Information density is poor.

- **Bulk cleanup is impossible.** You can't easily identify and remove stale contacts: no photo, no email, not contacted in years. Cleaning up 800 contacts means reviewing them one by one.

---

## Design Principles

1. **Less, but better.** Every screen, every control, every pixel earns its place. If it doesn't help you manage or reach a person, it doesn't exist.

2. **Freeform first.** Wherever Apple forces structured input, Kontakt accepts natural text and parses it. Addresses, phone numbers, names — paste it in, we'll figure it out.

3. **The list is the app.** The contact list is the primary surface. Search, browse, act — all from one screen. No navigation mazes.

4. **Information density with breathing room.** Show more contacts per screen without feeling cramped. Generous but purposeful whitespace. Type-forward design inspired by the best of Swiss graphic design.

5. **Zero lock-in.** Reads and writes the system `CNContactStore`. Every edit is immediately reflected in Apple's Contacts and vice versa. You can switch back anytime.

---

## Technical Foundation

### Platform
- iOS 18+ (SwiftUI-first, fully custom UI — no ContactsUI dependency)
- iPhone-only at launch (iPad in future update)

### Data Layer
- **CNContactStore** — the system contact database. No proprietary data store.
- All reads and writes go through Apple's Contacts framework
- `CNChangeHistoryFetchRequest` for efficient change tracking
- Background fetch with `CNContactStoreDidChange` notification for live updates

### Key Frameworks
- **Contacts** — `CNContact`, `CNMutableContact`, `CNSaveRequest`, `CNContactStore`
- **Foundation Models** (iOS 26+, Apple Intelligence devices) — on-device LLM for freeform parsing (addresses, contact creation, duplicate detection). Primary parsing engine on supported devices.
- **NaturalLanguage** — address and name parsing (fallback for non-AI devices)
- **MapKit** — address autocompletion and geocoding for the freeform address input

### On-Device AI Strategy
- **Tier 1 (iPhone 15 Pro+, iOS 26+):** Foundation Models framework with `@Generable` structured output for all natural language parsing. Richer, more forgiving, handles international formats and ambiguous input. A key differentiator.
- **Tier 2 (older devices / iOS 17–25):** Regex + MKLocalSearch + NaturalLanguage framework fallback. Functional but less capable.
- When Tier 1 is active, indicate to the user via a subtle sparkle indicator (✦) near parsed results that on-device AI is being used.
- No `ContactsUI` framework dependency — all editing UI is fully custom.

### Permissions
- Full Contacts access required (iOS 18+ limited access mode supported as fallback with clear upgrade prompt)

---

## Core Features

### 1. The List

The primary screen. A single, searchable, scrollable list of all contacts.

**Layout:**
- Each row: Name (primary), company or relationship label (secondary), and a subtle communication indicator (last contacted method/time, if available from Recents)
- Optional contact photo thumbnail — small and tasteful, not a giant circle
- Section index (A–Z scrubber) on the trailing edge
- Pull-to-search at top (search bar appears on pull-down, stays visible once active)

**Smart sections:**
- **Pinned** — user-pinned contacts, always at top (replaces Favorites with a more flexible model)
- **Recent** — contacts from recent Phone/Messages/FaceTime activity (sourced via `CallKit` / `CXCallObserver` where available, otherwise optional)
- **A–Z** — the full alphabetical list

**Density control:**
- Compact mode (name + company, no photos) vs. Standard mode (with thumbnails)
- User toggleable; defaults to Compact

### 2. Freeform Address Input

The headline feature. When adding or editing an address:

- Present a single multiline text field instead of separate Street / City / State / ZIP fields
- Accept pasted addresses in any common format:
  - `1234 Main St, Austin, TX 78704`
  - `1234 Main St\nAustin, TX 78704`
  - `1234 Main Street, Apt 2B, Austin, Texas 78704`
- Use a combination of `CNPostalAddressFormatter` (reverse), `MKLocalSearch`, and regex heuristics to parse into `CNPostalAddress` fields
- Show a live preview of the parsed result below the input: Street, City, State, ZIP separated into labeled fields that the user can tap to correct individually
- If parsing is ambiguous, highlight the uncertain field in a subtle accent color

**Fallback:** User can always tap "Edit fields individually" to drop into the traditional structured view.

### 3. Smart Search

Search that actually works:

- Searches across: given name, family name, company, department, job title, email addresses, phone numbers, physical addresses (city, state), notes, and relationship labels
- Partial and fuzzy matching — "Jenn" finds Jennifer, Jenny, Jenn
- Phone number search strips formatting — searching `512555` finds `(512) 555-1234`
- Results ranked by relevance: exact matches first, then partial, then field-type weighting (name > company > notes)
- Search is live/incremental — results update with each keystroke

### 4. The Contact Card

A clean, information-dense view of a single contact.

**Layout:**
- Name and company at top — clean typography, no giant avatar circle consuming half the screen
- Contact photo (if present) displayed tastefully — small, rounded rectangle, tappable to view full size
- **Action bar** — a row of icon buttons: Call, Message, FaceTime, Email, Directions. Only shows actions that are possible for this contact (no greyed-out buttons for missing data)
- **Fields** — displayed in a clean vertical stack. Each field is tappable (initiates the relevant action) and long-pressable (copies to clipboard with haptic confirmation)
- **Notes** — prominently displayed (not buried). Supports a quick-append button that adds a timestamped entry without entering full edit mode
- **Pin button** — pin/unpin this contact from the Pinned section

**Copy behavior:**
- Long-press any field → copies that specific value to clipboard
- Long-press the name → copies "First Last" as plain text
- Share button → standard share sheet with vCard, or a formatted text block of selected fields

### 5. Inline Quick Edit

Editing without the modal ceremony:

- Tap any field on the contact card to edit it in place
- Keyboard appears, cursor in the field, edit, tap away to save
- No "Edit" / "Done" button required for single-field changes
- For structural changes (adding new field types, reordering, deleting fields), a full edit mode is available via an Edit button — but the common case of "fix a typo in an email address" is instant

### 6. Contact Triage / Cleanup

A dedicated cleanup flow for pruning stale contacts. Accessed from a menu item or toolbar button.

**Smart filters** surface contacts that may need attention:
- **No phone number** — contacts with only an email
- **No email** — contacts with only a phone number
- **No photo** — contacts without any image
- **Incomplete** — contacts with only a name and nothing else
- **Possible duplicates** — fuzzy name + data matching, more aggressive than Apple's built-in detection
- **Stale** — contacts not in any recent call/message history (if data available)

**Triage UI:**
- Card-stack interface (swipe-based, like the original concept)
- Swipe right to keep, swipe left to delete, swipe up to merge (when viewing a duplicate pair)
- Running counter: "Reviewed 47 of 128 contacts needing attention"
- Undo support — deleted contacts go to a 30-day internal trash before permanent removal via `CNSaveRequest`

### 7. Quick Contact Creation

Adding a new contact should be fast and forgiving:

- **Freeform entry** — single text field at the top of the New Contact screen. Type or paste:
  - `Jennifer Smith 512-555-1234 jen@example.com`
  - `Dr. Robert Jones, Cardiologist, Heart Health Associates`
  - Kontakt parses name, phone, email, company, title from the natural language input
- Show live preview of parsed fields below the input
- User taps "Save" or taps individual fields to correct
- Also supports the traditional field-by-field entry as a fallback

### 8. Groups / Lists

Minimal but functional group support:

- Display existing contact groups from the system store
- Create, rename, delete groups
- Add/remove contacts from groups via the contact card (tag-style UI) or via multi-select in the list
- Filter the main list by group

### 10. My Card / Sharing

- Designated "My Card" with QR code generation for easy sharing
- Selectable fields — choose what to include when sharing (don't expose your home address to a business contact)
- Landscape rotation triggers sharing mode (à la Cardhop)

---

## Design Language

### Typography
- SF Pro as the primary typeface (system font, respects Dynamic Type)
- Name display: SF Pro Medium, slightly larger than body
- Field labels: SF Pro Regular, secondary color, small caps or reduced size
- Notes: SF Pro Regular, body size, full width

### Color
- Minimal color palette. Monochrome with a single accent color (muted blue or warm gray-blue)
- No colored backgrounds per contact (unlike Apple's recent poster-heavy design)
- Light and Dark mode support, following system setting
- High contrast mode support

### Spacing & Layout
- Generous but purposeful margins — not the excessive padding Apple introduced in Tahoe/iOS 26
- Information density prioritized: more contacts visible per screen than Apple's app
- Cards and sections separated by whitespace, not lines or borders
- Consistent 8pt grid

### Iconography
- SF Symbols throughout
- Action icons: monoline, consistent weight
- No color fills on icons in the default state

### Motion
- Subtle, purposeful animations only
- List insertions/deletions with standard SwiftUI transitions
- Card-stack triage uses spring physics for swipe gestures
- No gratuitous motion — respect Reduce Motion accessibility setting

---

## What Kontakt Is Not

- **Not a CRM.** No deal tracking, no pipeline, no analytics.
- **Not a caller ID / spam blocker.** Stay focused on contact management.
- **Not a social network aggregator.** No Facebook/LinkedIn/Twitter photo import.
- **Not a dialer replacement.** Tapping a phone number hands off to the system Phone app.
- **Not cross-platform.** iOS only for now. iPadOS and macOS to follow. No Android, no web dashboard.

---

## Information Architecture

```
App Launch
├── The List (primary screen)
│   ├── Search (pull-down or tap)
│   ├── Pinned section
│   ├── Recent section (optional)
│   └── A–Z sections
│       └── Contact Card (tap a row)
│           ├── Action bar (call, message, etc.)
│           ├── Fields (tap to act, long-press to copy)
│           ├── Notes (with quick-append)
│           ├── Pin / Unpin
│           └── Edit (full edit mode)
├── New Contact (+ button)
│   ├── Freeform entry
│   └── Field-by-field fallback
├── Cleanup / Triage (toolbar)
│   ├── Filter selection
│   └── Card-stack swipe UI
├── Groups (toolbar / tab)
│   └── Group list → filtered contact list
└── Settings
    ├── My Card
    ├── Display options (compact/standard, sort order)
    ├── Default account (for new contacts)
    └── About / Acknowledgments
```

---

## Development Phases

### Phase 1 — Foundation (MVP)
- Contact list with search
- Contact card view with action bar
- Freeform address input (paste + parse)
- Inline quick edit for existing fields
- Full edit mode (bridging to `CNContactViewController` or custom)
- Pin contacts
- Light/Dark mode
- App icon and basic branding

### Phase 2 — Cleanup & Polish
- Triage / cleanup card-stack UI
- Smart filters (no photo, no email, duplicates, etc.)
- Freeform new contact creation (natural language parse)
- Widgets (Pinned Contacts, Quick Search)
- My Card with QR code sharing

### Phase 3 — Refinement
- Groups management
- Recent contacts section (CallKit integration)
- iPad support
- Accessibility audit (VoiceOver, Dynamic Type, Reduce Motion)
- Localization (start with English, Spanish)
- Shortcuts / Siri Intents integration

### Phase 4 — macOS
- macOS support
- Localization (start with English, Spanish)

---

## Competitive Landscape

| App | Price | Strengths | Weaknesses |
|-----|-------|-----------|------------|
| Apple Contacts | Free | System default, zero setup | Neglected UX, no freeform input, poor search, dated design |
| Cardhop | $4.75/mo | Natural language, great design, recent contacts | Subscription, overkill for most users |
| Contacts+ | Freemium | Cross-platform sync, social enrichment | CRM-oriented, 1K contact free cap, privacy concerns |
| iContacts | Free | Group management, bulk ops | Utilitarian design, not a full replacement |
| **Kontakt** | **Free** | **Freeform input, modern design, cleanup tools, zero lock-in** | **New, single developer, iOS only** |

---

## Success Metrics

Since Kontakt is a gift to the community, success is measured in impact, not revenue:

- App Store rating ≥ 4.7
- Organic press coverage (9to5Mac, MacStories, The Verge)
- "Editors' Choice" or "App of the Day" feature
- Community word-of-mouth — the app people recommend when someone complains about Apple's Contacts
- Personal satisfaction: never cringing when managing contacts again

---

## Name Rationale

**Kontakt** — German for "contact." A nod to Dieter Rams and Braun's design heritage. Short, memorable, distinctive on the App Store. The K distinguishes it from the generic "Contacts" while remaining immediately understandable.

Alternative candidates considered: Rolodex (trademark issues), People (too generic), Karte (German for card, less recognizable), Adressbuch (too long).

---

## Resolved Decisions

1. **Drop-in replacement.** Kontakt should be fully functional enough that the user never has to open Apple's Contacts app again.

2. **On-device AI as primary parser.** Foundation Models framework (iOS 26+, iPhone 15 Pro+) handles all natural language parsing — addresses, contact creation, duplicate detection. Regex + MKLocalSearch + NaturalLanguage framework as fallback on older devices. This tiered approach is a key differentiator.

3. **Marketing hook:** Deferred — decide closer to launch.

4. **App name:** Kontakt.

5. **Fully custom edit UI from day one.** No `CNContactViewController` bridge. Apple's edit UI is the problem we're solving — using it would undermine the entire app. Legacy contact field types (Twitter, Jabber, ICQ, etc.) are supported but hidden behind a "Legacy" disclosure group in the field type picker.

---

*Built with taste by one person who believes managing your address book shouldn't require patience, a manual, or a subscription.*
