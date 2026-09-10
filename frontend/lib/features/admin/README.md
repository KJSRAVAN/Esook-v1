# Admin Feature

Handles platform overview, store verifications, dispute resolutions, and platform settings.

## Layering Rule
- `presentation/`: UI screens and controllers.
- `domain/`: Admin models and repository interfaces.
- `data/`: Admin repository implementations communicating with `ApiClient`.
