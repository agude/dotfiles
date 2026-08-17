// Prevent crash recovery from restoring tabs
user_pref("browser.sessionstore.resume_from_crash", false);

// Start with blank page, not restored session
user_pref("browser.startup.page", 0);

// Don't show "Restore Previous Session" button on homepage
user_pref("browser.startup.couldRestoreSession.count", -1);

// Don't persist open tabs as closed-tabs across sessions (Firefox 134+)
user_pref("browser.sessionstore.persist_closed_tabs_between_sessions", false);
