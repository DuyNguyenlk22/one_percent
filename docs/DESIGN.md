# Design System: One Percent Habit Tracker

> Extracted from Google Stitch Project: `One Percent Habit Tracker` (`projects/12234759688445532359`)

---

## 1. Visual Theme & Atmosphere

The design system is rooted in the philosophy of **incremental growth and mindfulness ("1% better every day")**. It is tailored for individuals seeking daily personal development without the stress or noise of aggressive gamification.

- **Primary Style:** Modern Minimalist with Soft-Tactile influences.
- **Atmosphere:** Quiet confidence, calm, and serene. It eliminates the medical sterility of healthcare apps and the neon urgency of generic fitness trackers in favor of a warm, lifestyle-oriented experience.
- **Whitespace Philosophy:** High-quality negative space functions as an active structural element to eliminate cognitive overload and guide focus toward a single point of daily intention.

---

## 2. Color Palette & Roles

Inspired by natural transitions—dawn, earth, and flora.

| Role | Token / Name | Hex Code | Purpose & Function |
| :--- | :--- | :--- | :--- |
| **Canvas** | `surface` / `background` | `#FBF9F4` | Warm cream canvas base that prevents eye strain |
| **Primary** | `primary` | `#4D6054` (`#7C9082`) | Sage Green: Completion states, active progress, primary CTA |
| **Primary Container** | `primary_container` | `#66796C` | Tonal badge background, selected filters |
| **On Primary** | `on_primary` | `#FFFFFF` | Text and icons on top of primary buttons |
| **Secondary** | `secondary` | `#7C5454` (`#D4A3A3`) | Dusty Rose: Soft highlights, reflections, secondary streaks |
| **Secondary Container**| `secondary_container`| `#FFCACA` | Tonal rose badges and tags |
| **Tertiary** | `tertiary` | `#4C5F69` (`#A7BBC7`) | Sky Slate: Focus sessions, hydration/habits metadata |
| **Tertiary Container** | `tertiary_container` | `#647782` | Secondary metrics containers |
| **Surface Low** | `surface_container_low`| `#F5F3EE` | Recessed inputs and inactive habit tile backgrounds |
| **Surface Card** | `surface_container` | `#F0EEE9` | Primary habit card surface |
| **Surface High** | `surface_container_high`| `#EAE8E3` | Elevated modal sheets and popovers |
| **Text Primary** | `on_surface` / `ink` | `#1B1C19` | Deep Charcoal Ink for headlines and high-contrast body |
| **Text Muted** | `on_surface_variant` | `#434844` | Secondary metadata, dates, streaks counter |
| **Outline / Border** | `outline_variant` | `#C3C8C2` | 1px subtle divider lines and input focus boundaries |
| **Error** | `error` | `#BA1A1A` | Destructive actions, streak breaks, error states |

---

## 3. Typography Rules

- **Font Family:** `Manrope` (Humanist Geometric Sans)
- **Casing:** Sentence-case for natural, humble conversational tone. Avoid all-caps except for functional small labels (`label-sm`).

### Typographic Scale

| Style Token | Size | Weight | Line Height | Tracking | Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `display` | `40px` | Bold (`700`) | `48px` | `-0.02em` | Daily motivational headlines, splash screens |
| `headline-lg` | `32px` (`28px` mob) | SemiBold (`600`) | `40px` (`36px`) | `-0.01em` | Screen titles ("Today", "Routines", "Insights") |
| `headline-md` | `24px` | SemiBold (`600`) | `32px` | `0em` | Section headers, modal sheet headers |
| `body-lg` | `18px` | Regular (`400`) | `28px` | `0em` | Lead habit descriptions, quote body text |
| `body-md` | `16px` | Regular (`400`) | `24px` | `0em` | Standard list items, form inputs, notes |
| `label-md` | `14px` | Medium (`500`) | `20px` | `+0.01em` | Button labels, chip tags, filter toggles |
| `label-sm` | `12px` | SemiBold (`600`)| `16px` | `+0.05em` | Streak badges ("🔥 5 DAYS"), timestamps |

---

## 4. Spacing, Shapes & Elevation

### Spacing Tokens
- **Container Margin:** `24px` (outer horizontal safe-area padding)
- **Stack Gap:** `16px` (vertical gap between habit cards)
- **Section Gap:** `40px` (gap between distinct habit categories or sections)
- **Touch Target:** Minimum `56px` for primary tap areas (ensuring effortless one-handed use)
- **Card Padding:** `20px` to `24px`

### Radii & Shapes
- **Habit Cards:** `24px` (`rounded-2xl` / `rounded-lg`)
- **Buttons & Chips:** Pill-shaped (`9999px` / `rounded-full`)
- **Form Inputs:** Pill-shaped (`9999px` / `rounded-full`) with light sand background (`#F5F3EE`)
- **Bottom Navigation Bar:** Floating glass capsule with `32px` rounded corners

### Elevation & Ambient Depth
- **No Harsh Drop Shadows:** Ambient, diffused shadows with primary tint (Blur `30px`, Opacity `4%`).
- **Tactile Feedback:** On card/button press, scale down subtly (`0.98x`) and reduce shadow depth.
- **Glassmorphism:** Navigation bar and dialog overlays utilize `backdrop-filter: blur(20px)` with `rgba(251, 249, 244, 0.85)` fill.

---

## 5. Component Stylings

### A. Habit Card
- **Layout:** Horizontal split — Left: habit name + category dot + streak tag; Right: large circular completion button (`48px` – `56px`).
- **Style:** Borderless card on `surface_container` (`#F0EEE9`), `24px` border radius, subtle ambient shadow.
- **Check-off State:** Tap animates checkmark stroke with soft ripple; card shifts from neutral to subtle Sage tint with a gentle "bloom" effect.

### B. Action Buttons
- **Primary CTA:** Pill-shaped, Sage Green background (`#4D6054`), White text (`#FFFFFF`), `56px` height, tactile scale down on press.
- **Secondary / Ghost:** Pill-shaped, transparent fill with `1.5px` Sage Green border and Sage text.

### C. Floating Bottom Navigation Bar
- **Form:** Floating dock positioned `16px` above bottom screen inset, rounded `32px`.
- **Material:** Frosted glass (`backdrop-filter: blur(20px)`), `rgba(251, 249, 244, 0.85)`.
- **Icons:** Thin-stroke (`1.5px` – `2.0px`) organic minimalist line icons.

### D. Progress & Streaks ("Blooming" Metaphor)
- **Visuals:** Progress is visualized using expanding organic circular loops and rings rather than harsh progress bars.
- **Daily 1% Win:** Subtle golden shimmer effect on the completion ring once all daily habits are checked off.

---

## 6. Anti-Patterns & Banned Clichés

- **NO Pure Black (`#000000`):** Always use `#1B1C19` (Charcoal Ink) for soft, natural contrast.
- **NO Harsh Neon / Violet Glows:** Use organic Sage green, Dusty Rose, and Warm Cream tones.
- **NO Overlapping Text/Images:** Clean, uncrowded spatial separation.
- **NO Generic 3-Column Equal Grids:** Respect single-column mobile flow with 24px margins.
- **NO System Default Fonts:** Strictly utilize **Manrope**.
- **NO Filler Scroll Text:** Never add "Scroll down" or bouncing arrows.
