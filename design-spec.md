# Kontakt — Design Specification

**Visual & Interaction Design Reference**
*DGR Labs — April 2026*

---

## Design Philosophy

Dieter Rams' "less, but better" applied to iOS contact management. Every element earns its place. The design should feel **quiet** — confident enough not to shout.

### Guiding Principles
1. **Content over chrome.** Names and data are the interface. Minimize decorative UI.
2. **Density without claustrophobia.** Show more per screen than Apple's Contacts, but maintain clear visual hierarchy and breathing room.
3. **Touch targets, not tap puzzles.** Generous hit areas (minimum 44pt), clear affordances, obvious state changes.
4. **Systematic consistency.** Every spacing value, color, and typographic choice comes from a defined system. No one-off values.

---

## Design Tokens

### Spacing Scale (8pt grid)

| Token | Value | Usage |
|-------|-------|-------|
| `space-xs` | 4pt | Inline padding, icon-to-label gap |
| `space-s` | 8pt | Compact internal padding |
| `space-m` | 12pt | Standard internal padding |
| `space-l` | 16pt | Section padding, card margins |
| `space-xl` | 24pt | Section gaps, screen margins |
| `space-2xl` | 32pt | Major section separation |

All spacing derives from these tokens. No magic numbers in code.

### Typography

Built on SF Pro, fully respecting Dynamic Type. All sizes listed are defaults at the "Large" (system default) text size.

| Token | Spec | Usage |
|-------|------|-------|
| `title-primary` | SF Pro Medium, 17pt | Contact name in card view |
| `title-secondary` | SF Pro Regular, 15pt, secondary color | Company name, subtitle |
| `body` | SF Pro Regular, 15pt | Field values, notes content |
| `label` | SF Pro Regular, 13pt, tertiary color | Field labels ("mobile", "work", "home") |
| `label-caps` | SF Pro Regular, 11pt, tertiary color, small caps tracking +0.5 | Section headers, metadata |
| `list-primary` | SF Pro Regular, 16pt | Contact name in list row |
| `list-secondary` | SF Pro Regular, 13pt, secondary color | Company/label in list row |
| `action` | SF Pro Medium, 13pt | Action bar button labels |
| `search` | SF Pro Regular, 16pt | Search field input |

**Dynamic Type behavior:** All sizes scale proportionally. Layout must accommodate up to AX5 (the largest accessibility size) without truncation of critical info — names and phone numbers wrap rather than truncate.

### Color Palette

Minimal. Monochrome foundation with a single accent.

#### Light Mode

| Token | Value | Usage |
|-------|-------|-------|
| `background` | System Background (#FFFFFF) | Screen background |
| `surface` | Secondary System Background (#F2F2F7) | Cards, grouped sections |
| `text-primary` | Label (#000000, 100%) | Contact names, field values |
| `text-secondary` | Secondary Label (#3C3C43, 60%) | Company, subtitles |
| `text-tertiary` | Tertiary Label (#3C3C43, 30%) | Field labels, metadata |
| `accent` | Custom Slate Blue (#5B7B9A) | Interactive elements, pin indicator, links |
| `accent-subtle` | accent at 12% opacity | Low-confidence field highlight, selected state background |
| `destructive` | System Red (#FF3B30) | Delete actions |
| `separator` | Separator (#3C3C43, 12%) | Used sparingly — prefer whitespace |
| `success` | System Green (#34C759) | Save confirmation |

#### Dark Mode

| Token | Value | Usage |
|-------|-------|-------|
| `background` | System Background (#000000) | Screen background |
| `surface` | Secondary System Background (#1C1C1E) | Cards, grouped sections |
| `text-primary` | Label (#FFFFFF, 100%) | Contact names, field values |
| `text-secondary` | Secondary Label (#EBEBF5, 60%) | Company, subtitles |
| `text-tertiary` | Tertiary Label (#EBEBF5, 30%) | Field labels, metadata |
| `accent` | Custom Slate Blue (#7B9BB8) | Slightly lighter for dark mode contrast |
| `accent-subtle` | accent at 15% opacity | Low-confidence field highlight |
| `destructive` | System Red (#FF453A) | Delete actions |
| `separator` | Separator (#545458, 24%) | Used sparingly |
| `success` | System Green (#30D158) | Save confirmation |

**Accent color rationale:** Slate blue is calm, professional, gender-neutral, and reads as "trustworthy utility" rather than "fun consumer app." It has sufficient contrast against both light and dark backgrounds for WCAG AA (4.5:1 minimum for text).

#### High Contrast Mode
- `text-primary` → full black/white
- `accent` → increase saturation by 15%, ensure 7:1 contrast ratio (WCAG AAA)
- `separator` → increase opacity to 30%

### Iconography

SF Symbols exclusively. Consistent configuration:

| Context | Symbol Config |
|---------|--------------|
| Action bar | `.font(.system(size: 20, weight: .medium))`, `hierarchical` rendering |
| List accessories | `.font(.system(size: 14, weight: .regular))`, `secondary` color |
| Navigation | `.font(.system(size: 17, weight: .semibold))` |
| Empty states | `.font(.system(size: 48, weight: .thin))`, `tertiary` color |

No filled symbols in default state. Filled variants reserved for selected/active states only (e.g., `star.fill` for pinned contacts).

### Corner Radii

| Token | Value | Usage |
|-------|-------|-------|
| `radius-s` | 6pt | Small elements (tags, badges) |
| `radius-m` | 10pt | Contact photos, field editor |
| `radius-l` | 14pt | Cards, modal sheets |

### Shadows

Shadows used minimally — only for elements that float above content:

| Token | Spec | Usage |
|-------|------|-------|
| `shadow-card` | y: 2pt, blur: 8pt, #000 at 8% | Triage card stack |
| `shadow-sheet` | y: -2pt, blur: 16pt, #000 at 12% | Bottom sheets, modals |

No shadow on standard list rows or cards in the main flow.

---

## Screen Specifications

### 1. Contact List (Primary Screen)

```
┌─────────────────────────────┐
│ ← (nav if applicable)       │
│                              │
│ ┌──────────────────────────┐ │
│ │ 🔍 Search contacts...    │ │  ← pull-down to reveal, or always visible
│ └──────────────────────────┘ │
│                              │
│  PINNED                      │  ← label-caps style, space-l left margin
│  ┌──────────────────────────┐│
│  │ Alice Johnson             ││  ← list-primary
│  │ Acme Corp                 ││  ← list-secondary
│  ├──────────────────────────┤│
│  │ Bob Williams              ││
│  │ Self                      ││
│  └──────────────────────────┘│
│                              │  ← space-2xl between sections
│  A                           │
│  ┌──────────────────────────┐│
│  │ Aaron Mitchell            ││  ┌───┐
│  │ Design Studio             ││  │ A │
│  ├──────────────────────────┤│  │ B │  ← section index
│  │ Amelia Chen               ││  │ C │     scrubber on
│  │ Google                    ││  │ · │     trailing edge
│  └──────────────────────────┘│  │ · │
│                              │  │ · │
│  B                           │  │ Z │
│  ┌──────────────────────────┐│  └───┘
│  │ Brian Foster              ││
│  │                           ││  ← no company = single line row
│  └──────────────────────────┘│
│                              │
│         ┌─────┐              │
│         │  +  │              │  ← floating or toolbar add button
│         └─────┘              │
└─────────────────────────────┘
```

**Row specifications:**
- Height: 52pt compact (name + company, no photo), 60pt standard (with 40pt thumbnail)
- Left margin: `space-xl` (24pt)
- Internal vertical padding: `space-m` (12pt) top/bottom
- Name: `list-primary`
- Company/label: `list-secondary`, 2pt below name
- Photo (Standard mode): 40x40pt, `radius-m`, left-aligned before name
- No chevron or disclosure indicator — the whole row is tappable

**Section headers:**
- `label-caps` style
- `space-l` left margin, `space-s` bottom margin
- No background color, no border — just the label floating above the section

**Section index (A–Z scrubber):**
- Right-aligned, vertically centered
- `label` style, `accent` color
- Haptic feedback (light impact) on each letter change during scrub

**Empty state (no contacts / no access):**
- Centered large SF Symbol (`person.crop.circle.badge.questionmark`, thin weight)
- Title: "No Contacts" / "Contact Access Needed"
- Subtitle explaining what to do
- If permissions issue: prominent button to open Settings

### 2. Contact Card

```
┌─────────────────────────────┐
│ ← Back              Edit    │
│                              │
│  ┌────┐                     │
│  │foto│ Alice Johnson        │  ← title-primary, photo is 56x56 radius-m
│  └────┘ VP of Engineering    │  ← title-secondary
│         Acme Corp            │  ← title-secondary
│                              │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐│
│  │ 📞 │ │ 💬 │ │ 📹 │ │ ✉️ ││  ← action bar: only relevant actions
│  │Call │ │Msg │ │FT  │ │Mail││  ← action label style
│  └────┘ └────┘ └────┘ └────┘│
│                              │
│  mobile                      │  ← label style
│  (512) 555-1234              │  ← body, tappable (calls), long-press (copy)
│                              │
│  work                        │
│  (512) 555-5678              │
│                              │  ← space-l between field groups
│  email                       │
│  alice@acme.com              │  ← body, accent color for actionable
│                              │
│  work                        │
│  alice.johnson@acme.com      │
│                              │
│  home                        │
│  1234 Main Street            │  ← body, multi-line for addresses
│  Austin, TX 78704            │
│                              │
│  ────────────────────────── │  ← subtle separator only before notes
│                              │
│  NOTES                       │  ← label-caps
│  Met at WWDC 2025. Interested│  ← body
│  in our API platform.        │
│                   [+ Append] │  ← accent color, adds timestamped entry
│                              │
│            📌 Pinned         │  ← pin toggle, accent when active
└─────────────────────────────┘
```

**Action bar:**
- Horizontally centered, equal spacing
- Each button: 60pt wide, icon above label
- Icon: SF Symbol, 20pt, `accent` color
- Label: `action` style, `accent` color
- Only rendered for available data — if no email, no email button. Never show disabled/greyed buttons.
- Tap: initiate action (call, message, etc.). If multiple numbers/emails, show a picker sheet.

**Field display:**
- Label above value (not inline — better scannability)
- Label: `label` style
- Value: `body` style
- Tappable: initiates primary action (call for phone, compose for email, open Maps for address)
- Long-press: copy to clipboard, show `CopyConfirmation` (brief toast + haptic)
- Vertical spacing between fields: `space-l` (16pt)
- Field groups (all phones, all emails) separated by `space-xl` (24pt)

**Notes section:**
- Separated from fields by a single subtle line (the ONLY separator line in the card)
- Full-width text, `body` style
- "Append" button right-aligned, `accent` color
- Append adds: `\n[YYYY-MM-DD] ` prefix, then cursor for typing
- If no notes exist: show "Add a note..." placeholder, tappable

**Photo:**
- 56x56pt, `radius-m` (10pt)
- If no photo: show initials in `accent-subtle` background, `accent` text, SF Pro Medium
- Tappable to view full-size (present as a simple overlay with dismiss)

**Pin indicator:**
- Bottom of the card, centered
- SF Symbol `pin.fill` when pinned, `pin` when not
- `accent` color when pinned, `text-tertiary` when not
- Tappable to toggle

### 3. Freeform Address Input

```
┌─────────────────────────────┐
│ Cancel           Save       │
│                              │
│  ADDRESS                     │
│  ┌──────────────────────────┐│
│  │ 1234 Main St, Apt 2B    ││  ← single multiline text field
│  │ Austin, TX 78704         ││     body style, full width
│  │                           ││     min height: 3 lines
│  └──────────────────────────┘│
│                              │
│  PARSED RESULT               │  ← appears after 0.3s debounce
│                              │
│  street                      │
│  1234 Main St, Apt 2B       │  ← high confidence: text-primary
│                              │
│  city                        │
│  Austin                      │  ← high confidence
│                              │
│  state                       │
│  TX                          │  ← high confidence
│                              │
│  zip                         │
│  78704                       │  ← high confidence
│                              │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  Edit fields individually →  │  ← text-secondary, tappable
│                              │
└─────────────────────────────┘
```

**Confidence visualization:**
- High confidence fields: `text-primary` color, no background
- Medium confidence fields: `text-primary` color, `accent-subtle` background
- Low confidence fields: `accent` color text, `accent-subtle` background, with a small `?` indicator

**Each parsed field is tappable** to manually correct. Tap opens an inline editor for just that field.

**Animation:** Parsed result fades in (`opacity` transition, 0.2s) as parsing completes. Fields slide in sequentially with 50ms stagger.

### 4. Freeform Contact Creation

```
┌─────────────────────────────┐
│ Cancel              Save    │
│                              │
│  NEW CONTACT                 │
│  ┌──────────────────────────┐│
│  │ Type or paste contact    ││  ← placeholder text
│  │ info...                   ││     single multiline field
│  │                           ││
│  └──────────────────────────┘│
│                              │
│  ─── or enter manually ───  │  ← subtle divider with text
│                              │
│  First name                  │  ← traditional fields below
│  ┌──────────────────────────┐│     (collapsed by default,
│  │                           ││      expand on tap)
│  └──────────────────────────┘│
│  Last name                   │
│  ┌──────────────────────────┐│
│  │                           ││
│  └──────────────────────────┘│
│  ...                         │
└─────────────────────────────┘
```

When the user types in the freeform field, the parsed preview appears below (same pattern as address input). Once they tap Save, the parsed fields are saved. The traditional fields below are a fallback — if the user taps into them, the freeform field collapses.

### 5. Search (Active State)

```
┌─────────────────────────────┐
│  ┌──────────────────────────┐│
│  │ 🔍 jen                   ││  ← live search, results update per keystroke
│  └──────────────────────────┘│
│                              │
│  Jennifer Smith              │  ← "Jen" highlighted/bolded in result
│  Acme Corp                   │
│                              │
│  Jenny Park                  │
│  jenny@example.com           │  ← shows the field that matched if not name
│                              │
│  Jenn Ortiz                  │
│  512-555-1234                │
│                              │
│  3 results                   │  ← result count, text-tertiary
└─────────────────────────────┘
```

**Result highlighting:** The matching substring is shown in `text-primary` + Medium weight; the rest of the name in `text-primary` Regular. This is a subtle bold, not a color highlight.

**Secondary match display:** If the match was on a non-name field (email, phone, company, address), show that field as the subtitle instead of the company name.

### 6. Copy Confirmation

When the user long-presses a field to copy:

- Light impact haptic
- A small floating label appears near the copied field: "Copied" in `label-caps` style
- Background: `surface` with `shadow-card`
- Auto-dismisses after 1.5s with fade-out
- Does NOT use a system alert or full-width banner

---

## Motion & Animation

### Principles
- Every animation must have a purpose: confirm an action, show spatial relationship, or maintain context during a transition
- No animation exceeds 0.4s duration
- Respect `UIAccessibility.isReduceMotionEnabled` — replace motion with opacity transitions

### Specific animations

| Interaction | Animation | Duration | Curve |
|-------------|-----------|----------|-------|
| List row tap → card | Standard `NavigationLink` push | System default | System default |
| Card dismiss | Standard navigation pop | System default | System default |
| Field edit begin | Field background highlight fade-in | 0.15s | easeOut |
| Field edit save | Brief green flash on field, then fade | 0.3s | easeInOut |
| Copy confirmation | Fade in + slight scale (0.95→1.0) | 0.2s | spring(0.5, 0.7) |
| Parsed result appear | Fade in with 50ms stagger per field | 0.2s per field | easeOut |
| Pin toggle | Symbol effect (bounce) on pin icon | System default | System default |
| Search results | Cross-fade list content | 0.15s | easeInOut |
| Triage card swipe | Track finger, then spring to exit | 0.35s | spring(0.4, 0.7) |
| Triage card reveal | Next card scales 0.95→1.0 + slight y shift | 0.3s | spring(0.5, 0.8) |

### Reduce Motion alternatives
- Replace all spring/movement animations with 0.2s opacity crossfade
- Triage cards: instant transition instead of swipe physics
- Symbol effects: disabled

---

## Haptics

| Interaction | Haptic |
|-------------|--------|
| Copy to clipboard | `.impact(.light)` |
| Pin/unpin toggle | `.impact(.medium)` |
| Save successful | `.notification(.success)` |
| Save failed | `.notification(.error)` |
| Section scrubber letter change | `.selection` |
| Triage swipe threshold reached | `.impact(.medium)` |
| Triage delete confirmed | `.notification(.warning)` |

---

## Dark Mode Behavior

Not just inverted colors — the design adapts:

- Contact photos should feel slightly elevated in dark mode (thin 1px border at 8% white to separate from the dark background)
- The accent color shifts lighter (see color tokens) to maintain contrast
- Separator lines become slightly more visible (higher opacity) since whitespace separation is less effective on dark backgrounds
- Card backgrounds use `surface` color (elevated) rather than true black to create subtle depth

---

## What We Don't Do

These are deliberate design decisions, not oversights:

- **No colored contact backgrounds** — Apple's contact posters are visual noise
- **No monogram circles consuming half the screen** — initials are shown small, in context
- **No greyed-out action buttons** — if you can't call them, the call button doesn't exist
- **No lines between every row** — whitespace separates; lines are reserved for semantic breaks
- **No swipe-to-delete on the main list** — too destructive for a one-swipe gesture on contacts. Delete lives in the contact card's edit mode.
- **No pull-to-refresh** — the contact store observer handles updates automatically
- **No skeleton loading states** — the contact list loads fast enough from the local store that shimmer/skeleton is unnecessary theatrics
- **No onboarding carousel** — one screen, one ask (contacts permission), done
- **No tab bar** — the list is the app. Secondary features (cleanup, groups, settings) are accessed from the navigation bar or toolbar.

---

*This spec is the source of truth for visual and interaction design decisions. When in doubt during implementation, refer here. When this spec is insufficient, make the choice that favors simplicity and information density.*
