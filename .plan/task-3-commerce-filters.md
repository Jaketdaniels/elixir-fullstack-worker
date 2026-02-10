# Task 3: Token Purchase System & User Filtering

## Overview
Implement proper token commerce with pricing tiers + a filtering system for the nearby users map, both following Dark Phoenix aesthetic and Disney animation principles.

---

## Part A: Schema Changes (schema.sql)

### 1. Add `tribe` column to profiles
```sql
ALTER TABLE profiles ADD COLUMN tribe TEXT DEFAULT '';
```
Since we use `CREATE TABLE IF NOT EXISTS`, we add the column directly to the profiles CREATE statement (no migration needed -- schema.sql is applied fresh).

### 2. Add `token_transactions` table
```sql
CREATE TABLE IF NOT EXISTS token_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES user(id),
  type TEXT NOT NULL,          -- 'purchase', 'daily_claim', 'message_sent', 'signup_bonus'
  amount INTEGER NOT NULL,     -- positive for credits, negative for debits
  tier TEXT DEFAULT '',        -- 'starter', 'popular', 'whale' for purchases
  balance_after INTEGER NOT NULL,
  created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_token_txns_user ON token_transactions(user_id, created_at DESC);
```

---

## Part B: Token Purchase System

### Pricing Tiers
| Tier | Name | Tokens | Price | Per-token | Visual |
|------|------|--------|-------|-----------|--------|
| starter | Spark | 50 | $2.99 | ~$0.06 | Single ember icon |
| popular | Blaze | 150 | $6.99 | ~$0.047 | Fire icon + "Most popular" badge |
| whale | Inferno | 500 | $14.99 | ~$0.03 | Phoenix icon + "Best value" badge |

### Router Changes (router.ex.eex)

1. **`api_tokens_purchase`** -- Replace the stub:
   - Accept `tier` param (starter/popular/whale) instead of raw `amount`
   - Map tier to token amount: starter=50, popular=150, whale=500
   - Update tokens table
   - Insert into `token_transactions` with type='purchase'
   - Return updated balance

2. **`api_tokens_daily`** -- Enhance:
   - Insert into `token_transactions` with type='daily_claim'
   - Return `next_reset` timestamp

3. **New: `GET /api/tokens/history`** route:
   - Returns last 50 transactions for the user
   - Used by the transaction history view

4. **Enhance `api_nearby`** -- Add filter support:
   - Read query params: `max_distance`, `min_age`, `max_age`, `body_type`, `position`, `tribe`, `online_only`
   - After fetching locations from KV, do profile lookups for the returned user IDs
   - Apply filters in Elixir (age range, body_type match, position match, tribe match)
   - For distance: calculate haversine between requester's lat/lng and each user's lat/lng
   - For online_only: already handled by KV TTL (5 min), but add a tighter `updated_within` check

### Views Changes (views.ex.eex)

1. **`frag_tokens/2`** -- Complete rewrite:
   - Token balance hero card with animated count
   - Three pricing tier cards in a grid:
     - Each card: icon, tier name, token count, price, per-token rate
     - "Most popular" / "Best value" badges on Blaze/Inferno
     - Selected state with fire border glow
   - Daily claim section with countdown timer
   - Transaction history section (loaded via JS from `/api/tokens/history`)
   - Pass `tokens` data including `daily_reset_at` for countdown

### Assets Changes (assets.ex.eex)

#### CSS additions (dp- prefix):

```
.dp-tier-grid         -- 3-column grid for tier cards
.dp-tier-card         -- Individual tier card (dark bg, fire border on hover)
.dp-tier-card.dp-tier-selected  -- Selected state: fire gradient border, glow
.dp-tier-card.dp-tier-popular   -- "Most popular" badge
.dp-tier-card.dp-tier-best      -- "Best value" badge
.dp-tier-badge        -- Badge overlay (positioned absolute top-right)
.dp-tier-icon         -- SVG icon area
.dp-tier-name         -- Tier title
.dp-tier-tokens       -- Token count (large, fire gradient text)
.dp-tier-price        -- Price display
.dp-tier-rate         -- Per-token rate (muted)
.dp-tier-card:hover   -- Scale up slightly, border glow intensifies

.dp-balance-hero      -- Large centered balance display
.dp-balance-number    -- Animated number (fire gradient, huge font)

.dp-daily-section     -- Daily claim area
.dp-countdown         -- Countdown timer display
.dp-countdown-segment -- Individual h:m:s segment

.dp-txn-table         -- Transaction history table
.dp-txn-row           -- Individual row
.dp-txn-type          -- Type badge (color-coded)
.dp-txn-amount        -- Amount (+green, -red)

.dp-purchase-modal    -- Purchase confirmation modal content
.dp-purchase-success  -- Success animation overlay
```

#### CSS Animations (Disney principles):

1. **Tier card hover** (Anticipation + Follow-through):
   - On hover: slight squish down (anticipation, 60ms), then scale up to 1.04 with border glow (80ms settle)
   - Ease: `cubic-bezier(.34,.03,.25,1.17)` (anticipate), settle with `cubic-bezier(.16,1,.3,1)`

2. **Tier card selection** (Staging + Secondary action):
   - Selected card scales to 1.02, fire gradient border animates (rotating gradient via `@property`)
   - Unselected cards dim slightly (opacity 0.6, scale 0.97)
   - Transition: 320ms with elastic ease

3. **Purchase confirmation modal** (Overlap + Slow in/out):
   - Modal slides up from bottom with slight overshoot
   - Confirmation button has breathing pulse animation
   - On confirm: button transforms to checkmark with success glow burst

4. **Purchase success** (Appeal + Exaggeration):
   - Large checkmark draws in (SVG stroke-dasharray animation)
   - Token count does a dramatic count-up with overshoot
   - Fire particle burst from the balance number
   - Auto-dismiss after 2s

5. **Daily claim countdown** (Staging):
   - Numbers flip with a subtle 3D rotation on each second tick
   - When claimable: button pulses with fire glow, "CLAIM" text scales up

6. **Token count animation** (Slow in/out + Overshoot):
   - Count-up: cubic-bezier eased, overshoots target by ~5%, settles back
   - Duration: 800ms for balance changes

#### JS additions:

1. **Token tier selection**:
   - Click handler on `.dp-tier-card` elements
   - Sets `dp-tier-selected` class, stores selected tier
   - Animates deselected cards (opacity/scale transition)

2. **Purchase flow**:
   - "Buy tokens" button opens confirmation modal
   - Modal shows: tier name, token count, price
   - "Confirm" posts to `/api/tokens/purchase` with `{tier: "popular"}`
   - On success: close modal, show success animation, update balance with count-up
   - On error: shake modal, show error toast

3. **Daily countdown timer**:
   - Calculate time until `daily_reset_at` (stored in token data, passed as data attribute)
   - `setInterval` every 1000ms updates h:m:s display
   - When countdown reaches 0: show "Claim now!" with pulse animation
   - Claim button handler: POST `/api/tokens/daily`, animate balance update

4. **Transaction history**:
   - Lazy-load from `/api/tokens/history` when user scrolls to section or clicks "View history"
   - Render rows with stagger animation
   - Type badges: purchase (amber), daily (green), message (red), bonus (purple)

5. **animateCountOvershoot(el, from, to, duration)**:
   - Enhanced count animation with overshoot
   - Overshoots target by 5%, settles back
   - Uses requestAnimationFrame

---

## Part C: User Filtering System

### Filter Categories

| Filter | UI Control | Values |
|--------|-----------|--------|
| Distance | Segmented buttons | Any, <1km, <5km, <10km, <50km |
| Age | Dual range slider | 18-99 (min/max) |
| Body type | Checkboxes (multi-select) | Slim, Athletic, Average, Muscular, Stocky, Bear |
| Position | Checkboxes (multi-select) | Top, Bottom, Vers, Side |
| Tribe/Type | Checkboxes (multi-select) | Bear, Twink, Jock, Otter, Daddy, Wolf, Cub, Geek, Rugged |
| Online now | Toggle switch | On/Off (users with location < 5 min old) |

### Profile Schema Update
- Add `tribe` to profiles table (already planned above)
- Add `tribe` to profile edit form (views.ex.eex `frag_profile_edit`)
- Add `tribe` to `api_profile_update` handler
- Add `tribe` to `api_profile_get` response

### Router Changes

1. **`api_nearby`** enhancement:
   - Parse query params from conn URL
   - After fetching location data from KV, batch-fetch profiles for those user_ids from D1
   - Apply filters:
     - `max_distance`: haversine distance calc (need user's own lat/lng from their KV entry)
     - `min_age` / `max_age`: check profile.age
     - `body_type`: check if profile.body_type is in the comma-separated filter value
     - `position`: check if profile.position is in the comma-separated filter value
     - `tribe`: check if profile.tribe is in the comma-separated filter value
     - `online_only`: all KV entries are < 5 min, so this is implicit; can add tighter check via ts
   - Return enriched user objects: include profile fields (age, body_type, position, tribe) alongside location data

### Views Changes

1. **`frag_map/1`** -- Add filter button to map controls:
   - Filter icon button in `.dp-map-controls`
   - Active indicator (dot/badge) showing number of active filters

### Assets Changes

#### CSS additions:

```
.dp-filter-panel      -- Slide-out panel (from right side or bottom sheet on mobile)
.dp-filter-panel.open -- Open state (translateX(0))
.dp-filter-backdrop   -- Semi-transparent backdrop
.dp-filter-header     -- Panel header with title + close + "Clear all" + "Apply"
.dp-filter-section    -- Individual filter category section
.dp-filter-section h4 -- Section title
.dp-filter-count      -- Active filter count badge on the filter button

.dp-segment-group     -- Segmented button group (for distance)
.dp-segment           -- Individual segment button
.dp-segment.active    -- Active segment (fire gradient bg)

.dp-range-dual        -- Dual range slider container
.dp-range-track       -- Track background
.dp-range-fill        -- Filled portion between thumbs (fire gradient)
.dp-range-thumb       -- Draggable thumb
.dp-range-labels      -- Min/max labels below slider

.dp-checkbox-group    -- Checkbox group container
.dp-check-pill        -- Pill-shaped checkbox (togglable)
.dp-check-pill.active -- Active state (fire border, subtle glow)

.dp-filter-toggle     -- Toggle switch for online-only
```

#### CSS Animations (Disney principles):

1. **Filter panel open** (Anticipation + Follow-through):
   - Backdrop fades in (200ms)
   - Panel slides in from right with slight overshoot (400ms, elastic ease)
   - Content sections stagger in (reveal animation, 44ms delay each)

2. **Filter panel close** (Overlapping action):
   - Panel slides out faster than it came in (200ms, ease-in)
   - Backdrop fades simultaneously

3. **Segment/pill toggle** (Squash & stretch):
   - On tap: squish horizontally (0.94x), then expand to 1.04x, settle to 1.0x
   - Active pill: fire gradient border animates in (border-image transition)
   - Deactivated: subtle fade out of glow

4. **Range slider drag** (Follow-through):
   - Thumb scales up 1.2x on grab
   - Fill bar color intensifies during drag
   - On release: thumb bounces back to 1.0x with elastic ease

5. **Filter count badge** (Secondary action):
   - Count changes trigger scale bump (same as dp-count-bump)
   - Badge appears with pop-in animation when going from 0 to 1 active filter

#### JS additions:

1. **Filter panel management**:
   - `openFilterPanel()` / `closeFilterPanel()`
   - Creates panel DOM, applies stagger
   - Reads current filter state from localStorage

2. **Filter state management**:
   - `getFilters()` -- reads from localStorage key `dp_filters`
   - `setFilters(filters)` -- saves to localStorage
   - `countActiveFilters()` -- returns count for badge
   - Default state: all empty (no filtering)

3. **Distance segments**:
   - Click handler swaps `.active` class
   - Updates filter state

4. **Dual range slider** (custom, no library):
   - Two thumb elements on a track
   - Pointer events for drag
   - Updates min_age / max_age in filter state
   - Labels update in realtime during drag

5. **Checkbox pills**:
   - Toggle `.active` class on click
   - Multi-select: build comma-separated string for filter value

6. **Apply filters**:
   - "Apply" button in panel header
   - Builds query string from filter state
   - Modifies `pollNearby()` to append filter params to `/api/nearby?max_distance=5&min_age=25&max_age=40&body_type=athletic,muscular&position=top,vers&tribe=bear,jock&online_only=1`
   - Closes panel
   - Updates filter count badge

7. **Clear all**:
   - Resets all filter UI to defaults
   - Clears localStorage `dp_filters`
   - Updates badge to 0

8. **Integration with pollNearby()**:
   - Modified to read current filters and append as query params
   - `/api/nearby` endpoint parses these and filters server-side
   - Nearby list and map markers update automatically on next poll

---

## Implementation Order

1. **schema.sql** -- Add tribe to profiles, add token_transactions table
2. **router.ex.eex** -- Enhance token APIs, add history endpoint, add filter support to nearby, add tribe to profile APIs
3. **views.ex.eex** -- Rewrite frag_tokens, add tribe to profile edit, add filter button to map
4. **assets.ex.eex CSS** -- All new CSS classes (tier cards, filter panel, animations)
5. **assets.ex.eex JS** -- Token purchase flow, countdown, filter panel, dual range slider, localStorage persistence

---

## Key Technical Notes

- No external libraries (no range slider libs, no animation libs)
- All distance calculation happens server-side in Elixir (haversine formula)
- Filter panel is created/destroyed in JS DOM (not server-rendered)
- Tier selection state lives in JS; purchase requires explicit confirmation
- Transaction history loads lazily via API call
- Countdown timer uses `daily_reset_at` from token data
- All `dp-` CSS prefix maintained
- Mobile: filter panel becomes bottom sheet (full width, slides up)
- Mobile: tier cards stack vertically
- Haversine helper function added to router.ex.eex as `defp haversine_km/4`
