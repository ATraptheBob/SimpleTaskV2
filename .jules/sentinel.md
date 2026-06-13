## 2024-06-10 - Unbounded Local Data Input Resource Exhaustion
**Vulnerability:** CoreData/SwiftData entities allowed unbounded text inputs (title, notes) and unvalidated image sizes, causing UI rendering freezes and potential JetSam memory crashes when excessively large strings or 100MB+ images were loaded into SwiftUI view states.
**Learning:** Even entirely local, offline apps require strict input bounds. Local persistence frameworks can be easily DOSed by the user (or via synced external data) if arbitrary sizes are allowed to serialize into the main context or views.
**Prevention:** Always enforce logical limits directly on SwiftUI text fields using `.onChange` text truncation, strictly limit unbounded arrays (like steps), and validate `Data` object sizes before persisting them.

## 2026-06-13

### Vulnerability
Sensitive User Data Exposure in Notifications

### Learning
Displaying user-generated or sensitive data (like habit names or task titles) directly in the text body of local notifications exposes that information on the user's lock screen. Anyone who can see the lock screen can view this private data.

### Prevention
Avoid including sensitive user information in notification titles or bodies. Use generic messaging, such as "You just finished a task!" instead of listing the specific task, unless an explicit privacy setting allows the user to opt-in to displaying this info.
