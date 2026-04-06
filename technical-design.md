**Note:** This spec has been superseded by people-spec-update-april6.md. The app has been renamed from Kontakt to People.

# People — Technical Design & Refined Spec

**Supplement to contacts-app-spec.md**
*DGR Labs — April 2026*

---

## App Architecture

### Pattern: Observation-based MVVM

SwiftUI + `@Observable` (iOS 18+). No Combine unless interfacing with older APIs that require it.

```
Kontakt/
├── App/
│   ├── KontaktApp.swift              # @main entry point
│   └── AppState.swift                # App-wide observable state (selected contact, active sheet, etc.)
├── Services/
│   ├── ContactStore.swift            # Wraps CNContactStore — single source of truth
│   ├── ContactChangeObserver.swift   # Listens to CNContactStoreDidChange, triggers refresh
│   ├── AddressParser.swift           # Freeform address → CNPostalAddress (delegates to AI or regex)
│   ├── ContactParser.swift           # Freeform text → CNMutableContact (delegates to AI or regex)
│   ├── AIParsingService.swift        # Foundation Models wrapper — @Generable structs, availability checks
│   ├── RegexParsingService.swift     # Fallback parser for non-AI devices
│   └── SearchEngine.swift            # Multi-field ranked search with fuzzy matching
├── Models/
│   ├── ContactWrapper.swift          # Lightweight wrapper around CNContact for display
│   ├── ParsedAddress.swift           # @Generable — intermediate parsed address with confidence
│   ├── ParsedContact.swift           # @Generable — intermediate parsed contact fields
│   ├── ContactFieldType.swift        # Field types: modern (phone, email, etc.) vs legacy (Jabber, ICQ, etc.)
│   └── SearchResult.swift            # Ranked result with match metadata
├── Views/
│   ├── ContactList/
│   │   ├── ContactListView.swift     # Primary screen — the list IS the app
│   │   ├── ContactRowView.swift      # Single row in the list
│   │   ├── SectionIndexView.swift    # A–Z scrubber
│   │   └── PinnedSection.swift       # Pinned contacts at top
│   ├── ContactCard/
│   │   ├── ContactCardView.swift     # Detail view for a single contact
│   │   ├── ActionBarView.swift       # Call / Message / FaceTime / Email / Directions
│   │   ├── FieldView.swift           # Single field row (tap to act, long-press to copy)
│   │   └── NotesView.swift           # Notes with quick-append
│   ├── Editing/
│   │   ├── InlineFieldEditor.swift   # Tap-to-edit overlay for a single field
│   │   ├── FullEditView.swift        # Structural editing (add/remove/reorder fields)
│   │   └── FreeformAddressInput.swift # The headline feature — paste & parse
│   ├── Creation/
│   │   ├── NewContactView.swift      # Freeform + fallback field-by-field
│   │   └── ParsePreviewView.swift    # Live preview of parsed fields
│   └── Shared/
│       ├── CopyConfirmation.swift    # Haptic + toast on long-press copy
│       └── ContactPhoto.swift        # Small rounded-rect thumbnail
├── Utilities/
│   ├── CNContact+Extensions.swift    # Computed properties for display (full name, formatted phone, etc.)
│   ├── String+PhoneNormalization.swift # Strip formatting for search comparison
│   └── HapticManager.swift           # Centralized haptic feedback
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings
```

### Why this structure

- **Services layer** owns all `CNContactStore` interaction. Views never touch the Contacts framework directly.
- **ContactWrapper** exists because `CNContact` is immutable and expensive to fetch with all keys. The wrapper holds only the keys needed for the current view, with lazy loading for deeper detail.
- **No Core Data / SwiftData.** The system contact store IS the database. We don't duplicate it.

---

## Data Flow

```
CNContactStore
    ↕ (read/write via ContactStore service)
ContactStore (@Observable)
    ↓ (publishes contact list, handles caching)
Views (observe ContactStore directly)
```

### Contact Fetching Strategy

Fetching all contacts with all keys is expensive. People uses a **two-tier fetch**:

1. **List fetch** — minimal keys for the contact list display:
   - `CNContactGivenNameKey`, `CNContactFamilyNameKey`
   - `CNContactOrganizationNameKey`
   - `CNContactThumbnailImageDataKey` (only in Standard density mode)
   - `CNContactIdentifierKey`

2. **Detail fetch** — full keys when opening a contact card:
   - All phone numbers, emails, addresses, URLs, social profiles
   - Notes, dates, relationships
   - Full-size image data

This means navigating to a contact card triggers a second fetch. Acceptable latency — `CNContactStore` keyed fetch by identifier is fast.

### Change Observation

```swift
NotificationCenter.default.publisher(for: .CNContactStoreDidChange)
```

On change notification: re-fetch the full list (tier 1 keys). This handles edits made in Apple's Contacts, iCloud sync, and other apps. Debounce to 0.5s to avoid rapid-fire refreshes during bulk sync.

---

## Freeform Address Parsing — Design

### Tier 1: Foundation Models (iPhone 15 Pro+, iOS 26+)

The primary parsing engine on supported devices. Uses `@Generable` for structured output:

```swift
@Generable
struct ParsedAddress {
    @Guide(description: "Street address including apartment/suite/unit")
    let street: String
    @Guide(description: "City name")
    let city: String
    @Guide(description: "State or province, abbreviated if US (e.g., TX)")
    let state: String
    @Guide(description: "ZIP or postal code")
    let postalCode: String
    @Guide(description: "ISO country code if identifiable, empty if ambiguous")
    let countryCode: String
}
```

Advantages over regex:
- Handles international address formats naturally
- Tolerates typos, abbreviations, and non-standard formatting
- Can parse ambiguous input ("123 Main Austin Texas" — no commas, no zip)
- Streaming output shows fields appearing in real-time (✦ indicator visible)

Validation: pass the AI-parsed result through `CNPostalAddressFormatter` to confirm it round-trips cleanly.

### Tier 2: Regex + MKLocalSearch fallback (older devices)

Used when Foundation Models is unavailable:

**Step 1: Regex heuristics (fast, offline)**
Pattern-match common US address formats:
- `{number} {street}, {city}, {state} {zip}`
- `{number} {street}\n{city}, {state} {zip}`
- Handle Apt/Suite/Unit variations
- State abbreviation + full name dictionary
- Covers ~70% of pasted US addresses.

**Step 2: MKLocalSearch (network, higher accuracy)**
If regex produces low-confidence results:
- Feed the freeform text to `MKLocalSearch`
- Use the structured result to populate address fields
- Handles international addresses, ambiguous formats, and typos

**Step 3: CNPostalAddressFormatter (reverse validation)**
- Format the parsed `CNPostalAddress` back to a string for confirmation
- If it differs significantly from input, highlight uncertain fields

### Confidence scoring (both tiers)
Each parsed field gets a confidence: `.high`, `.medium`, `.low`
- `.high` — AI parsed with high confidence, or regex matched unambiguously, or MKLocalSearch confirmed
- `.medium` — AI parsed but ambiguous, or regex matched with assumptions
- `.low` — best guess, should be highlighted in the preview UI

### UX flow
1. User pastes or types in the single text field
2. After 0.3s debounce, parsing begins
3. If Tier 1: streaming result with ✦ sparkle indicator; if Tier 2: instant result
4. Preview appears below: street / city / state / zip in labeled fields
5. Low-confidence fields shown with subtle accent highlight
6. User can tap any parsed field to manually correct
7. "Edit fields individually" link drops into traditional mode

---

## Freeform Contact Creation — Parsing Design

### Tier 1: Foundation Models (iPhone 15 Pro+, iOS 26+)

```swift
@Generable
struct ParsedContact {
    @Guide(description: "Name prefix/title such as Dr., Mr., Ms.")
    let namePrefix: String
    let givenName: String
    let familyName: String
    @Guide(description: "Job title or role")
    let jobTitle: String
    @Guide(description: "Company or organization name")
    let organization: String
    @Guide(description: "Phone numbers found in the input")
    let phoneNumbers: [String]
    @Guide(description: "Email addresses found in the input")
    let emailAddresses: [String]
}
```

The on-device LLM handles ambiguous inputs that regex can't:
- "Bob from the plumber" → given: Bob, organization: (empty), notes: "the plumber"
- "Dr. Maria García-López, UNAM" → prefix: Dr., given: Maria, family: García-López, organization: UNAM
- Multi-line pasted text blocks from email signatures, business cards, etc.

### Tier 2: Regex + NaturalLanguage fallback (older devices)

Extraction order:
1. **Email** — regex for `*@*.*` patterns (most unambiguous, extract first)
2. **Phone** — regex for digit sequences with optional formatting: `(xxx) xxx-xxxx`, `xxx-xxx-xxxx`, `xxx.xxx.xxxx`, `+1xxxxxxxxxx`
3. **Name** — whatever remains after extracting email/phone, with NaturalLanguage `NLTagger` for person name recognition
4. **Company / Title** — heuristic: if comma-separated segments remain after name extraction, treat as "Title, Company" or "Company"

### Example inputs and expected parses (both tiers)
```
"Jennifer Smith 512-555-1234 jen@example.com"
→ Given: Jennifer, Family: Smith, Phone: (512) 555-1234, Email: jen@example.com

"Dr. Robert Jones, Cardiologist, Heart Health Associates"
→ Given: Robert, Family: Jones, Prefix: Dr., Title: Cardiologist, Company: Heart Health Associates

"jen@example.com"
→ Email: jen@example.com (name fields empty — prompt user)
```

---

## Smart Search — Implementation

### Index structure
On app launch / contact list refresh, build an in-memory search index:

```swift
struct SearchableContact {
    let identifier: String
    let tokens: [(field: SearchField, value: String, normalized: String)]
}

enum SearchField: Comparable {
    case givenName, familyName   // highest weight
    case organization, jobTitle  // medium weight
    case email, phone            // medium weight
    case address, notes          // lower weight
}
```

Normalization: lowercase, strip diacritics, strip phone formatting.

### Search algorithm
1. Normalize query the same way
2. For each contact, score = sum of field matches weighted by `SearchField` rank
3. Match types: prefix match (strongest), contains match (moderate), fuzzy match via Levenshtein distance ≤ 2 (weakest)
4. Sort results by score descending
5. Return incrementally — show results as they're found, don't wait for full scan

### Performance target
- 1,000 contacts: < 10ms per keystroke
- 10,000 contacts: < 50ms per keystroke
- If needed, move search to a background actor and debounce input by 100ms

---

## Pinned Contacts — Storage

Since we can't add custom fields to `CNContact`, pinned state is stored in **UserDefaults**:

```swift
// Key: "pinnedContactIdentifiers"
// Value: [String] — array of CNContact.identifier values
```

This is the ONE exception to "no app-specific storage." It's a small, non-critical piece of metadata. If the user uninstalls People, pins are lost — acceptable tradeoff vs. adding a full database.

**Alternative considered:** Using a CNGroup named "People-Pinned" to store pins in the system contact store. Rejected because it pollutes the user's groups and would be visible in Apple's Contacts app.

---

## Inline Editing — Interaction Model

### Single-field edit (the common case)
1. User taps a field value (e.g., email address)
2. The field transforms in-place to a text input (same position, same size)
3. Keyboard appears with appropriate type (email keyboard for email, phone pad for phone, etc.)
4. User edits and either:
   - Taps away → save automatically via `CNSaveRequest`
   - Presses Return → save and advance to next field
5. Brief haptic confirmation on save

### Edge cases
- **Save failure** (e.g., contact was deleted by another app during edit): show inline error, offer to retry or discard
- **Concurrent edit** (CNContactStoreDidChange fires during edit): finish current edit, then refresh. Don't yank the field away mid-typing.
- **Phone number formatting**: auto-format as user types using `CNPhoneNumber` formatting

### Full edit mode
Fully custom from day one — no `CNContactViewController` bridge. For adding new fields, deleting fields, reordering, changing field labels (Home vs. Work):
- Accessed via Edit button on the contact card
- Custom list-based editing UI (add/delete/reorder rows)
- "Add field" picker shows modern field types prominently (phone, email, address, URL, date, notes)
- Legacy field types (Twitter, Jabber, ICQ, AIM, Yahoo IM, MSN, etc.) hidden behind a "Legacy" disclosure group in the field type picker — supported for reading/display always, but not pushed as options for new fields
- Must handle all `CNContact` property types to ensure zero data loss when editing

---

## Permissions & Onboarding

### First launch flow
1. Welcome screen — brief value prop (1 screen, no carousel)
2. Contact access request with clear explanation of why full access is needed
3. If granted → load contact list immediately
4. If denied → show a helpful screen explaining the app can't function without access, with a button to open Settings

### iOS 18+ Limited Access
If the user grants limited access instead of full:
- Show a banner at the top of the list: "People works best with full contact access"
- Tap banner → re-request or deep-link to Settings
- App still functions with the limited set — just shows fewer contacts

### No account, no tracking
Zero analytics, zero telemetry. The app never makes network requests except:
- `MKLocalSearch` for address parsing (user-initiated only)
- App Store review prompt (SKStoreReviewController, system-managed)

---

## Contact Triage / Cleanup — Technical Design (Phase 2)

### Smart filter queries
Each filter is a `CNContactFetchRequest` with appropriate predicates and post-fetch filtering:

- **No phone:** contacts where `phoneNumbers.isEmpty`
- **No email:** contacts where `emailAddresses.isEmpty`
- **No photo:** contacts where `imageDataAvailable == false`
- **Incomplete:** only has a name, nothing else
- **Possible duplicates:** On Tier 1 devices, Foundation Models can do semantic duplicate detection (e.g., "Bob Smith" vs "Robert Smith", "Jenny" vs "Jennifer"). On Tier 2, fuzzy match on normalized name + any matching phone/email. Build a similarity graph, present pairs.

### Card-stack UI
- Custom SwiftUI view with `DragGesture`
- Spring animation physics: `spring(response: 0.4, dampingFraction: 0.7)`
- Cards stacked with slight offset/scale for depth illusion (show 2 behind current)
- Swipe threshold: 120pt horizontal, 100pt vertical (for merge)

### Undo / Trash
- Deleted contacts are saved to a `CNSaveRequest` delete, but with a 30-day grace period
- Store deleted contact identifiers + serialized `CNContact` data in app-local storage (the only case where we use local storage beyond UserDefaults)
- Provide "Recently Deleted" section accessible from cleanup screen

---

## Performance Considerations

### Large contact lists (5,000+)
- Use `LazyVStack` in the contact list — never load all rows into memory
- Section index (A–Z scrubber) uses `ScrollViewReader` for instant jump
- Contact photos loaded asynchronously with a small LRU cache
- Search index built on a background thread at launch; subsequent updates are incremental

### Memory
- Thumbnail images are the biggest memory concern
- In Compact mode (default): no thumbnails loaded → minimal memory
- In Standard mode: thumbnails cached at display size (40x40pt), not original resolution
- Full-size photos loaded only on contact card, released on dismissal

---

## Accessibility

Baked in from day one, not bolted on in Phase 3:

- All interactive elements have accessibility labels and hints
- Dynamic Type support throughout (no hardcoded font sizes)
- VoiceOver: contact list navigable by section, action bar announced with context ("Call Jennifer's mobile")
- Reduce Motion: disable spring animations, use opacity transitions instead
- Minimum tap targets: 44x44pt per HIG
- High Contrast mode: ensure accent color meets WCAG AA on both light and dark backgrounds

---

## Resolved Design Decisions

1. **Sort order:** Read from `CNContactsUserDefaults.shared().sortOrder` (match system preference). Offer First/Last and Last/First in People's settings.

2. **Swipe actions on the list:** Left-swipe reveals delete. Right-swipe to pin/unpin.

3. **State management:** Single `ContactStore` (`@Observable`) owns all data and operations. `SearchEngine` extracted as a separate service due to algorithmic complexity. Refactor into multiple stores only if the single store grows past ~300 lines or testing becomes awkward.

4. **Minimum deployment target:** iOS 18+. Foundation Models (Tier 1 parsing) requires iOS 26 anyway; Tier 2 fallback covers iOS 18–25.

5. **Localization:** String Catalogs (`Localizable.xcstrings`) from day one. All user-facing strings localization-ready from Phase 1.

---

*This document is a living supplement to contacts-app-spec.md. Update as decisions are made and implementation reveals new considerations.*
