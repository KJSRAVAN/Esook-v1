# Auth Feature

Handles user authentication, login, registration, and session lifecycle.

## Layering Rule
- `presentation/`: UI screens and controllers.
- `domain/`: Auth models and repository interfaces.
- `data/`: Auth repository implementations communicating with `ApiClient` and `SecureStorage`.
