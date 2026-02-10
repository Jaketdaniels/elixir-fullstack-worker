# Task 2: Private Chat with Media Sharing and Virtual Scroll

## Plan

### 1. Schema Changes (schema.sql)

Add two columns to the `messages` table:
- `media_url TEXT DEFAULT ''` - stores either a base64 data URI (for small images <500KB) or an R2 URL
- `message_type TEXT DEFAULT 'text'` - values: `text`, `image`, `media` (for future audio/video)

Add a `typing_indicators` table (transient, could use KV instead but D1 is simpler for the polling model):
```sql
CREATE TABLE IF NOT EXISTS typing_indicators (
  user_id TEXT NOT NULL,
  conversation_with TEXT NOT NULL,
  updated_at TEXT DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, conversation_with)
);
```

Add index on messages for cursor-based pagination:
```sql
CREATE INDEX IF NOT EXISTS idx_messages_cursor ON messages(from_id, to_id, id DESC);
```

### 2. API Endpoints (router.ex.eex)

**New routes:**
- `POST /api/messages/:id/typing` - Set typing indicator (upsert into typing_indicators, auto-expires after 5s by check on read)
- `GET /api/messages/:id/new?after=<msg_id>` - Get only messages newer than a given ID (for efficient polling)
- `GET /api/messages/:id/older?before=<msg_id>&limit=30` - Load older messages for virtual scroll (cursor-based pagination)

**Modified routes:**
- `POST /api/messages` - Accept optional `media_url` and `message_type` fields
- `GET /api/messages/:id` - Include `media_url`, `message_type` in response; add `typing` boolean for other user; return messages with new fields

**Media upload strategy:**
Since the WASM layer cannot handle binary data efficiently, media upload will be handled in `index.js`:
- `POST /api/media/upload` - New endpoint in index.js (JS layer) that accepts multipart form data, validates image (max 500KB, image/* MIME), converts to base64 data URI, and returns `{ url: "data:image/jpeg;base64,..." }`. For images under 500KB, base64 in D1 is acceptable. No R2 needed for MVP.

### 3. index.js Changes

Add a media upload handler before the WASM pass:
```javascript
if (url.pathname === "/api/media/upload" && request.method === "POST") {
  // Check auth
  // Read multipart form data
  // Validate: image/* MIME, <500KB
  // Convert to base64 data URI
  // Return JSON { url: "data:..." }
}
```

### 4. Virtual Scroll (assets.ex.eex - JS)

**Approach: Intersection Observer + scroll position tracking**

The virtual scroll uses a hybrid approach:
1. **Sentinel elements** at top and bottom of the message list
2. **Intersection Observer** on the top sentinel to trigger loading older messages
3. **Scroll position preservation** when prepending older messages (save scrollHeight before prepend, restore after)
4. **DOM recycling**: Keep a maximum of ~200 messages in DOM. When loading older messages pushes past 200, remove from bottom. When scrolling back down and hitting bottom sentinel, reload recent messages.

**Data flow:**
- Initial load: fetch last 50 messages via existing `GET /api/messages/:id`
- Scroll up to top sentinel: `GET /api/messages/:id/older?before=<oldest_msg_id>&limit=30`
- Polling for new messages: `GET /api/messages/:id/new?after=<newest_msg_id>` (replaces current full-refetch polling)
- Each message DOM node has `data-mid` attribute for tracking

**Virtual scroll state:**
```javascript
{
  messages: [],        // in-memory array of all loaded messages
  oldestId: null,      // cursor for loading older
  newestId: null,      // cursor for loading newer
  hasOlder: true,      // false when server returns < limit
  loading: false,      // debounce flag
  renderedRange: { start: 0, end: 0 }  // currently visible window
}
```

For simplicity (given that conversations rarely exceed 1000 messages), we will keep all loaded messages in an array and only use the intersection observer for **lazy loading older messages** rather than full DOM virtualization. This keeps complexity manageable while solving the core UX issue of not loading 100+ messages at once.

### 5. Message Grouping by Time (views.ex.eex + assets.ex.eex)

Messages are grouped by day in the client-side renderer:
- Compare each message's `created_at` to the previous message
- If the day differs, insert a `<div class="dp-msg-date-divider">` with the formatted date
- Format: "Today", "Yesterday", or "Mon, Feb 10"
- Time within bubbles shown as "HH:MM" (short format)

### 6. Read Receipts (visual indicators)

Add visual read receipt indicators to sent messages:
- After a message bubble from the current user, show a small status indicator:
  - Single check (sent): `dp-receipt-sent` - gray checkmark
  - Double check (delivered/read): `dp-receipt-read` - amber checkmark
- The `read` field already exists in the messages table
- When polling, the response includes `read` status for each message
- CSS: small SVG checkmarks below the bubble timestamp, animated on state change

### 7. Typing Indicators

- When user types in the input, send `POST /api/messages/:id/typing` (debounced, max once per 3s)
- When polling for new messages, the response includes `typing: true/false` for the other user
- Display: animated dots ("...") below the last received message, with the dp-typing-indicator class
- Auto-hide after 5s if no new typing signal

### 8. Disney Animation Principles Applied

All animations use the existing CSS custom properties (`--dp-ease`, `--dp-anticipate`, `--dp-settle`, `--dp-elastic`).

**a) New message enter (bubble-in-new):**
- **Anticipation**: Scale down to 0.92 and slight translateY(8px)
- **Overshoot**: Scale up to 1.04, translateY(-2px)
- **Settle**: Scale to 1.0, translateY(0)
- Duration: 0.4s with `--dp-anticipate` easing
- Sent messages slide from right, received from left (using translateX)

**b) Sent message "sending" state:**
- **Staging**: Reduced opacity (0.6), desaturated filter
- On success: quick scale pulse (0.98 -> 1.02 -> 1.0) with opacity snap to 1
- CSS class: `dp-bubble-pending` (exists) -> `dp-bubble-confirmed` (new)

**c) Media loading in chat:**
- **Anticipation**: Placeholder shimmer (like existing loading rows)
- **Follow-through**: Image fades in with slight scale from 0.96 to 1.0
- Skeleton has the aspect ratio of the image (if known) to avoid layout shift

**d) Typing indicator dots:**
- **Overlapping action**: Three dots animate with staggered delays
- Each dot: scale 0.6 -> 1.2 -> 0.8 -> 1.0 (elastic bounce)
- 0.8s duration, each dot delayed by 0.15s

**e) Read receipt appear:**
- **Secondary action**: Fade in with translateX(3px) -> 0, 0.2s duration
- Subtle, doesn't draw attention away from conversation

**f) Date divider enter:**
- Fade in with scale(0.9) -> scale(1.0), centered origin
- 0.3s duration

**g) Virtual scroll - older messages prepend:**
- Messages fade in from top with translateY(-10px), staggered by 20ms each
- Preserves scroll position so user doesn't jump

**h) Image preview modal:**
- Backdrop: fade in 0.25s
- Image: scale from 0.85 with slight rotation (-1deg -> 0deg), overshoot to 1.02
- Close: reverse with faster timing (0.18s)

### 9. Elixir/JS Split

**Elixir (WASM) handles:**
- All message CRUD (send, fetch, mark read)
- Typing indicator read/write in D1
- Cursor-based pagination queries
- HTML fragment rendering for initial conversation load
- Message validation (length, spam checks)

**JS (index.js) handles:**
- Media upload endpoint (binary handling)
- Auth extraction (already exists)
- Rate limiting (already exists)

**Client JS (assets.ex.eex) handles:**
- Virtual scroll logic (Intersection Observer)
- Message rendering with grouping
- Typing indicator debouncing and display
- Read receipt visual updates
- Media preview/lightbox
- All animations

### 10. CSS Classes (all dp- prefixed)

New classes to add:
- `dp-msg-date-divider` - date separator between message groups
- `dp-typing-indicator` - container for typing dots
- `dp-typing-dot` - individual animated dot
- `dp-receipt` - read receipt container
- `dp-receipt-sent` - single check
- `dp-receipt-read` - double check (amber)
- `dp-bubble-image` - image message bubble styling
- `dp-media-preview` - image inside bubble
- `dp-media-shimmer` - loading placeholder for images
- `dp-media-lightbox` - fullscreen image viewer
- `dp-lightbox-backdrop` - overlay for lightbox
- `dp-msg-input-row` - updated input row with media button
- `dp-media-btn` - image upload button in chat input
- `dp-media-preview-strip` - preview of selected image before sending
- `dp-bubble-confirmed` - animation for confirmed sent message
- `dp-scroll-sentinel` - invisible div for Intersection Observer
- `dp-loading-older` - spinner shown when loading older messages

New keyframe animations:
- `@keyframes bubble-in-sent` - right-origin message enter
- `@keyframes bubble-in-received` - left-origin message enter
- `@keyframes bubble-confirm` - sent -> confirmed transition
- `@keyframes typing-bounce` - dot bounce animation
- `@keyframes receipt-in` - receipt fade-slide
- `@keyframes media-reveal` - image load-in
- `@keyframes divider-in` - date divider enter
- `@keyframes lightbox-in` - fullscreen image enter

### 11. Implementation Order

1. Schema changes (schema.sql) - add columns and typing_indicators table
2. Router changes (router.ex.eex) - new endpoints and modified message handlers
3. Views changes (views.ex.eex) - updated conversation fragment with new HTML structure
4. CSS additions (assets.ex.eex css()) - all new classes and animations
5. JS rewrite of conversation (assets.ex.eex js()) - virtual scroll, media, typing, receipts
6. index.js - media upload endpoint
