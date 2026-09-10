# Customer Feature

Handles customer-facing market, browsing, cart, checkout, and order tracking.

## Layering Rule
- `presentation/`: UI screens and controllers.
- `domain/`: Customer models and repository interfaces.
- `data/`: Customer repository implementations communicating with `ApiClient`.
