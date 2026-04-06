# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

People is a free iOS contacts app — a drop-in replacement for Apple's Contacts. It reads/writes the system `CNContactStore` directly with no proprietary data store, no account, no sync service.

## Naming

- **App name (everywhere):** People
- **Developer:** DGR Labs

## Technical Stack

- **Platform:** iOS 18+, iPhone-only at launch
- **UI:** SwiftUI-first, pure SwiftUI. No UIKit bridging — all editing UI is fully custom (no `CNContactViewController`).
- **Data:** Apple Contacts framework (`CNContact`, `CNMutableContact`, `CNSaveRequest`, `CNContactStore`). Change tracking via `CNChangeHistoryFetchRequest` and `CNContactStoreDidChange` notifications.
- **Parsing (Tier 1):** Foundation Models framework (`@Generable`, `@Guide`) for on-device AI parsing on iPhone 15 Pro+ / iOS 26+. Primary engine for address parsing, contact creation, and duplicate detection.
- **Parsing (Tier 2):** NaturalLanguage framework + regex + MapKit (`MKLocalSearch`) as fallback on older devices.
- **Design system:** SF Pro typography, SF Symbols icons, 8pt grid, monochrome palette with single muted accent color (slate blue), Light/Dark mode

## Architecture Decisions

- **Zero lock-in:** All data lives in the system contact store. No app-specific database.
- **Freeform-first input:** Addresses, phone numbers, and names accept natural text and parse it, rather than requiring structured field-by-field entry.
- **The list is the app:** Single primary screen (contact list) with search, pinned, recent, and A-Z sections. Avoid navigation mazes.
- **Inline editing:** Tap any field on the contact card to edit in place. Full edit mode only for structural changes (add/remove/reorder fields).
- **Fully custom edit UI:** No `CNContactViewController`. Apple's edit UI is the problem we're solving. Legacy field types (Twitter, Jabber, ICQ, etc.) supported but hidden behind a "Legacy" disclosure group.
- **On-device AI indicator:** Show ✦ sparkle near parsed results when Foundation Models is active, so users know the app is using on-device AI.

## Design Principles

Strictly follows Apple HIG for iOS 26. Additionally Dieter Rams-inspired: less, but better. Key constraints:

- Every element must earn its place — no visual noise, no feature creep
- Information density prioritized over Apple's default padding
- Cards/sections separated by whitespace, not lines or borders
- Subtle purposeful animations only; respect Reduce Motion accessibility setting
- No colored backgrounds per contact, no giant avatar circles
- Action buttons only shown when the contact has the relevant data (no greyed-out buttons)

## Development Phases

1. **Foundation (MVP):** Contact list + search, contact card + action bar, freeform address input, inline quick edit, full edit mode, pin contacts, Light/Dark mode
2. **Cleanup & Polish:** Triage card-stack UI, smart filters, freeform new contact creation, My Card with QR
3. **Refinement:** Groups, recent contacts (CallKit), iPad, accessibility audit, localization, Shortcuts/Siri
4. **macOS:** macOS support

## Key Frameworks Reference

- `Contacts` — CNContact, CNMutableContact, CNSaveRequest, CNContactStore
- `FoundationModels` — on-device LLM with @Generable structured output (iOS 26+, A17 Pro+)
- `NaturalLanguage` — address and name parsing (Tier 2 fallback)
- `MapKit` — MKLocalSearch for address autocompletion (Tier 2 fallback)
- `CallKit` — CXCallObserver for recent contacts (Phase 3)
