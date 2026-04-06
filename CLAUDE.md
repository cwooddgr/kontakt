# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

People is a free iOS contacts app — a drop-in replacement for Apple's Contacts. It reads/writes the system `CNContactStore` directly with no proprietary data store, no account, no sync service. App-specific metadata (stars, tags, interaction logs, recently deleted) is stored as JSON in Application Support.

## Naming

- **App name (everywhere):** People
- **Developer:** DGR Labs

## Technical Stack

- **Platform:** iOS 18+, iPhone-only at launch
- **UI:** SwiftUI-first, pure SwiftUI. No UIKit bridging — all editing UI is fully custom (no `CNContactViewController`).
- **Data:** Apple Contacts framework (`CNContact`, `CNMutableContact`, `CNSaveRequest`, `CNContactStore`). Change tracking via `CNChangeHistoryFetchRequest` and `CNContactStoreDidChange` notifications.
- **App-specific data:** JSON files in `Application Support/People/` for tags, interaction logs, and recently deleted contacts. Stars stored in UserDefaults.
- **Parsing (Tier 1):** Foundation Models framework (`@Generable`, `@Guide`) for on-device AI parsing on iPhone 15 Pro+ / iOS 26+. Primary engine for address parsing, contact creation, and duplicate detection.
- **Parsing (Tier 2):** NaturalLanguage framework + regex + MapKit (`MKLocalSearch`) as fallback on older devices.
- **Design system:** SF Pro typography, SF Symbols icons, 8pt grid, monochrome palette with single muted accent color (slate blue), Light/Dark mode

## Architecture Decisions

- **Zero lock-in:** All contact data lives in the system contact store. No app-specific database. Supplementary metadata (tags, interaction logs) stored as JSON sidecar files.
- **Three-flow architecture:**
  - **Lookup (search-first):** Launch opens to a search bar with a stars grid below it. Typing filters contacts instantly via `SearchEngine`. Search covers name, phone, email, organization, job title, tags, address, and notes.
  - **Capture (freeform creation):** Paste or type natural text, AI/regex parses it into structured fields. `ContactMatchingService` checks for duplicates (phone/email exact match, name exact/fuzzy match) before saving.
  - **Hygiene (maintenance):** Recently deleted with 30-day recovery, tag browser for bulk organization.
- **Stars:** Replace pins. Starred contacts appear as a grid on the launch screen below the search bar. Stored as a `Set<String>` of contact identifiers in UserDefaults (migrated from legacy "pinnedContactIdentifiers").
- **Tags:** Freeform string labels attached to contacts, replacing rigid groups. Searchable, stackable, with recent suggestions. Stored in `TagStore`.
- **Interaction Log:** Per-contact timestamped micro-notes ("lunch 2/20", "plumber came 3/15"). Stored in `InteractionLogStore`.
- **Recently Deleted:** Soft-delete with 30-day vCard-backed recovery. Contacts serialized to vCard format before removal from CNContactStore, restorable via `RecentlyDeletedStore`.
- **Freeform-first input:** Addresses, phone numbers, and names accept natural text and parse it, rather than requiring structured field-by-field entry.
- **Inline editing:** Tap any field on the contact card to edit in place. Field swipe and long-press context menus for copy, delete, and other actions. Full edit mode only for structural changes (add/remove/reorder fields).
- **Fully custom edit UI:** No `CNContactViewController`. Apple's edit UI is the problem we're solving. Legacy field types (Twitter, Jabber, ICQ, etc.) supported but hidden behind a "Legacy" disclosure group.
- **On-device AI indicator:** Show sparkle near parsed results when Foundation Models is active, so users know the app is using on-device AI.

## Design Principles

Strictly follows Apple HIG for iOS 26. Additionally Dieter Rams-inspired: less, but better. Key constraints:

- Every element must earn its place — no visual noise, no feature creep
- Information density prioritized over Apple's default padding
- Cards/sections separated by whitespace, not lines or borders
- Subtle purposeful animations only; respect Reduce Motion accessibility setting
- No colored backgrounds per contact, no giant avatar circles
- Action buttons only shown when the contact has the relevant data (no greyed-out buttons)

## Development Phases

1. **Phase 1 — Foundation (MVP):** Contact list + search, contact card + action bar, freeform address input, inline quick edit, full edit mode, pin contacts, Light/Dark mode. **Complete.**
2. **Phase 2 — Spec Update:** Stars (replacing pins), tags with TagStore, interaction log, recently deleted with 30-day recovery, freeform new contact creation with AI/regex parsing, contact matching/deduplication, search-first launch with stars grid, tag browser, field swipe/long-press context menus. **Complete.**
3. **Phase 3 — Refinement:** Groups, recent contacts (CallKit), iPad, accessibility audit, localization, Shortcuts/Siri
4. **Phase 4 — macOS:** macOS support

## Services Reference

| Service | Type | Purpose |
|---|---|---|
| `ContactStore` | `@Observable class` | Central data store wrapping `CNContactStore`. Manages contacts list, authorization, starring, saving, deleting. |
| `SearchEngine` | `Sendable class` | Stateless search index builder and ranked multi-field search with fuzzy matching. Indexes tags when provided. |
| `ContactMatchingService` | `enum` (stateless) | Matches parsed contacts against existing contacts. Phone/email exact match, name exact/fuzzy match. Computes field diffs and merges new fields. |
| `TagStore` | `@Observable class` | Manages per-contact tags with JSON persistence. Tracks recent tags for suggestions. |
| `InteractionLogStore` | `@Observable class` | Stores timestamped interaction notes per contact with JSON persistence. |
| `RecentlyDeletedStore` | `@Observable class` | Manages soft-deleted contacts with 30-day vCard-backed recovery window. |
| `ContactParser` | — | Orchestrates parsing: routes to `AIParsingService` (Tier 1) or `RegexParsingService` (Tier 2). |
| `AIParsingService` | — | On-device LLM parsing via Foundation Models (`@Generable`). iOS 26+ / A17 Pro+. |
| `RegexParsingService` | — | Regex + NaturalLanguage fallback parser for older devices. |
| `AddressParser` | — | Freeform address parsing with MapKit autocompletion fallback. |
| `ContactChangeObserver` | — | Listens for `CNContactStoreDidChange` notifications and triggers refresh. |
| `VCardService` | — | vCard import/export utilities. |

## Key Frameworks Reference

- `Contacts` — CNContact, CNMutableContact, CNSaveRequest, CNContactStore
- `FoundationModels` — on-device LLM with @Generable structured output (iOS 26+, A17 Pro+)
- `NaturalLanguage` — address and name parsing (Tier 2 fallback)
- `MapKit` — MKLocalSearch for address autocompletion (Tier 2 fallback)
- `CallKit` — CXCallObserver for recent contacts (Phase 3)

## Key Models

| Model | Purpose |
|---|---|
| `ContactWrapper` | Lightweight `Sendable` value-type snapshot of `CNContact` for list display. |
| `ParsedContact` | Intermediate parsed contact with per-field confidence. Converts to `CNMutableContact`. |
| `ParsedAddress` | Intermediate parsed address with per-field confidence. Converts to `CNPostalAddress`. |
| `SearchResult` | Search result with score, matched field, and matched value. |
| `SearchField` | Enum of searchable fields (givenName, familyName, organization, jobTitle, tag, email, phone, address, notes) with weights. |
