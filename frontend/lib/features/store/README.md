# Store Feature

Handles store inventory management, product listings, inbound orders, and fulfillment.

## Layering Rule
- `presentation/`: UI screens and controllers.
- `domain/`: Store models and repository interfaces.
- `data/`: Store repository implementations communicating with `ApiClient`.
