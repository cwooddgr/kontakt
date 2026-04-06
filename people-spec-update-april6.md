# People — Spec Update (April 6, 2026)

New design decisions to merge into the existing project spec.

---

## App Name Change

Rename from **Kontakt** to **People**. These aren't business contacts — they're all the people in your life. The name should reflect that.

---

## Three Core Flows

The entire UI is organized around three flows in priority order:

1. **Lookup** — find someone's information
2. **Capture** — add or update information
3. **Hygiene** — clean up the database

If a feature doesn't serve one of these three, it doesn't belong.

---

## Launch Screen (The Ready State)

- Opens with **search field focused and keyboard showing**. The default assumption is you're here to find someone.
- Below search: **Stars grid** — a compact grid of starred people showing face photos (initials as fallback). Visible even with keyboard up. These are your 10-20 most important people, manually curated.
- **"+" button** — always one tap away, opens the Capture flow.
- **Browse All** — subtle link below stars. Dismisses keyboard and shows the full A-Z list.
- No "recents" section. Stars are intentional and stable; recents are reactive and noisy.

---

## Lookup: Search Behavior

- Live/incremental as you type
- Matches against **all fields**: name, company, address, phone, email, tags, notes
- Partial and fuzzy matching — "plum" finds the plumber, "80517" finds everyone at that zip
- Results show enough context to avoid tapping in: name, matching field highlighted, primary phone/email visible in the result row

---

## Lookup: Person View (The Card)

- **Photo large at top** — faces are primary. If no photo, show initials + subtle "Add photo" prompt.
- **Name** big and clear
- **Tags** as horizontal tappable pills below the name
- **Info fields ordered by usefulness**: phone/email first (most actionable), then address, company/title, notes
- **Every field tappable** to act (call, email, open Maps)
- **Swipe or long-press any individual field** to edit/delete just that field — no global "edit mode" for small fixes
- **Delete accessible directly** from person view — not buried behind edit → scroll → delete
- **Star toggle** available here
- **Interaction log** at bottom — timestamped micro-notes ("plumber came 3/15", "lunch 2/20"). A "Log" button to quickly append. This answers "when did I last see this person?" without needing system-level access to Messages or Calendar.

---

## Capture: The Single Input Field

- "+" opens one screen, one large text field. Placeholder: "Paste or dictate anything about anyone."
- User dumps in whatever they have — email signature, business card OCR, dictated sentence, pasted text.
- AI parses the input and determines:
  - **High-confidence match**: "This looks like new info for John Scalo — new address. Update?" Shows old vs. new.
  - **Low-confidence match**: "Is this the same Mike Johnson?" Yes/No.
  - **No match**: "New person. Here's what I parsed:" — shows extracted fields, user confirms and optionally tags.
- Never ask "new or existing?" — figure it out.
- Never present an empty form — parse first, confirm second.
- Offer tag assignment during capture with recent/frequent tags suggested.

---

## Tags Over Groups

Tags replace rigid groups. They're fluid and stackable — someone can be tagged "estes" AND "vendor" AND "plumber." Implementation:

- Inline tag creation (just type a new one)
- Tag-based filtering from search (tapping a tag = searching for it)
- Tag browser as secondary screen — all tags with counts, tap to see everyone

---

## Stars

- Simple boolean flag on the contact record
- Toggle from person view or long-press on any list
- No hard cap — trust the user
- Stars appear as the primary grid on the launch screen

---

## Hygiene: Three Entry Points

1. **Swipe-to-delete on any list view** — search results, tag lists, A-Z browse. Swipe left → delete → confirm → 30-day soft delete.
2. **Delete from person view** — always accessible, never buried.
3. **Cleanup mode** — the existing card-stack/tinder-style swipe from the original spec. Surfaces contacts by staleness. Can also surface duplicates.
4. **Recently Deleted** folder — 30-day recovery window.

---

## Photo Enrichment (Future — Separate Bucket)

Photos of people are a first-class priority. The resolution waterfall:

1. **Existing contact photo** — use it
2. **Photos library face match** — query PHAsset/PHPerson for tagged face clusters matching the contact name. Offer best candidates as a picker. Crop to face region.
3. **Linked social profiles** — if contact has LinkedIn/Facebook/Twitter URLs or handles, fetch public avatar. Also try OpenGraph `og:image` from any URL in the contact record. Cross-reference email for confidence. Always show and ask, never set silently.
4. **No photo available** — show initials, surface "Add photo" prompt

Photo enrichment can be triggered at capture time ("I found 48 photos of John in your library"), during hygiene sweeps, or from the person view's "Add photo" prompt. Photos are written back via `CNMutableContact.imageData` so they sync everywhere.

This is a significant feature area to design separately — noted here for direction.

---

## Calendar Integration (Optional, With Permission)

If the user grants EventKit access:

- Scan calendar events for attendees matching contacts (by email) or event titles fuzzy-matching contact names
- Surface "Coming Up" — people you're seeing in the next few days
- Feed calendar interactions into the person's interaction log automatically
- This enriches the "when am I seeing them next?" and "when did I last see them?" questions
