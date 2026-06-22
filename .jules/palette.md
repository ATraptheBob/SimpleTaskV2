## 2026-06-22 - Accessible Tapable Images
**Learning:** Tapable `Image` views used as buttons lack VoiceOver traits by default.
**Action:** Always apply `.accessibilityAddTraits(.isButton)` and conditional `.accessibilityLabel` strings (e.g. 'Mark complete' vs 'Mark incomplete') to icon-only tapable images.
