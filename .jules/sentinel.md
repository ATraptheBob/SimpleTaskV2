## 2024-06-10 - Unbounded Local Data Input Resource Exhaustion
**Vulnerability:** CoreData/SwiftData entities allowed unbounded text inputs (title, notes) and unvalidated image sizes, causing UI rendering freezes and potential JetSam memory crashes when excessively large strings or 100MB+ images were loaded into SwiftUI view states.
**Learning:** Even entirely local, offline apps require strict input bounds. Local persistence frameworks can be easily DOSed by the user (or via synced external data) if arbitrary sizes are allowed to serialize into the main context or views.
**Prevention:** Always enforce logical limits directly on SwiftUI text fields using `.onChange` text truncation, strictly limit unbounded arrays (like steps), and validate `Data` object sizes before persisting them.

## 2026-06-13 - Unimplemented Security and Privacy Features
**Vulnerability:** The application UI exposed "Export Backup" and "Erase All Data" actions that were unimplemented stubs containing only `print` statements.
**Learning:** Exposing unimplemented privacy or data management features creates a critical false sense of security for users. They may rely on a backup that was never created or assume sensitive data was deleted when it remains on the device, violating privacy expectations.
**Prevention:** Never ship UI elements for privacy, data export, or deletion features before the underlying functionality is fully implemented and tested. Remove stubbed privacy features from production code.
