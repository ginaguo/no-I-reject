# App Store Connect — submission copy

Copy each of these into the matching field in App Store Connect.
Length limits noted in parentheses.

---

## App Name (30 chars max)

```
NoIReject
```

## Subtitle (30 chars max)

```
Track your moments. Own your day.
```

(That's exactly 33 — shorten to one of:)

- `Moments worth tracking.` (23)
- `Own your day, one moment.` (25)
- `Tiny moments, big patterns.` (27)

## Promotional Text (170 chars, can change without resubmission)

```
The simplest way to notice what really shifts your mood. Log uncomfortable
and exciting moments in seconds, then watch the patterns emerge.
```

## Description (4000 chars)

```
NoIReject is a quiet, honest journal for the moments that actually move you.

Log a moment in 5 seconds. Pick a type — uncomfortable or exciting. Slide an
intensity. Tag it (Work, Family, Gym, your own). Add a note if you want.
That's it.

Then look back. The Calendar shows your days at a glance. The Year view
turns 365 days into a single beautiful map of your life. Insights tell you
what tags actually make you happy, and which ones drain you — based on what
you logged, not on what you remember.

Why "moments"?
Because feelings don't show up as essays — they show up as moments. A small
rejection. An unexpected compliment. A tough meeting. A great walk. Tracking
those tiny shifts is how you find out what's really running your life.

What it does
• Today: log a moment, see today's score
• Calendar: every day, color-coded
• Year: a full-year heat map
• Insights: discover the tags that lift you up or wear you down
• Goals & "what helps me": a private place to remember why you're doing this

What it doesn't do
• No ads. Ever.
• No tracking. Ever.
• No streaks-shaming, no badges, no notifications guilting you back.

Sync everywhere
Sign up once and your data follows you between iPhone and the web app at
no-i-reject.vercel.app. Sign in with Apple is supported.

Your data is yours
Stored securely in your private account. Delete it anytime — there's a
button right in the app.

Free. Forever. No subscription.
```

(Edit to taste — the "what it doesn't do" section is the strongest selling point.)

## Keywords (100 chars total, comma-separated, no spaces)

```
mood,journal,moments,tracker,emotions,wellbeing,mindfulness,habit,reflection,mental,health,gratitude
```

## Category

- Primary: **Health & Fitness**
- Secondary: **Lifestyle**

## Age Rating

- 4+

## URLs

- **Support URL**: `https://no-i-reject.vercel.app/contact.html`
- **Marketing URL** (optional): `https://no-i-reject.vercel.app/`
- **Privacy Policy URL**: `https://no-i-reject.vercel.app/privacy.html`

## App Review Information

- **First name / Last name**: your real name
- **Phone**: yours (Apple won't show this publicly)
- **Email**: ginaguo1996@gmail.com
- **Demo account**:
  - email: `appreview@noireject.app` (create this account on TestFlight before submission)
  - password: a throwaway, e.g. `AppleReview2026!`
- **Notes for reviewer**:

```
Sign in with the demo account above, or use Sign in with Apple.
The app stores moments in Supabase Postgres; the same account works on the
web at https://no-i-reject.vercel.app/.

Account deletion: profile menu (top-left) → Delete Account. This calls a
Supabase Edge Function that permanently removes the user and cascades all
their data.
```

## App Privacy (Data Type questionnaire)

When asked "do you collect data from this app", answer **Yes**, then declare:

- **Email Address**
  - Linked to user: Yes
  - Used for tracking: No
  - Purpose: App Functionality, Account Management
- **User Content** (the moments, tags, goals)
  - Linked to user: Yes
  - Used for tracking: No
  - Purpose: App Functionality

Skip everything else (no analytics, no ads, no health data classification).

## Pricing

- Free
- All territories

## Version

- 1.0 / build 1

---

## What you still need to produce

- [ ] **Screenshots** (6.7" iPhone, 1290×2796):
  - Today screen with a few moments
  - Calendar view
  - Year heat map
  - Insights with goals + tag stats
- [ ] **App Preview video** (optional)
- [ ] **Demo account** created on the production app
