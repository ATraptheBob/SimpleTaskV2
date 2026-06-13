# 2024-05-18

**Vulnerability:**
Unimplemented data deletion functionality leaving user data exposed when they intend to erase it. The 'Erase All Data' action was a non-functional stub.

**Learning:**
Security isn't just about preventing unauthorized access; it's also about fulfilling user expectations regarding data lifecycle. If an application provides a mechanism to delete sensitive user data, that mechanism must be fully functional. A stub that pretends to delete data but does not is a security flaw that compromises data minimization and user autonomy.

**Prevention:**
Always verify that data deletion features perform the requested operation on the underlying data store (e.g., SwiftData `ModelContext`). Additionally, enforce confirmation prompts for destructive actions to prevent accidental data loss. Implement integration tests that verify records are actually removed from the persistent store when deletion actions are triggered.
