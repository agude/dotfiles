// Prevent crash recovery from restoring tabs
user_pref("browser.sessionstore.resume_from_crash", false);

// Start with blank page, not restored session
user_pref("browser.startup.page", 0);

// Don't show "Restore Previous Session" button on homepage
user_pref("browser.startup.couldRestoreSession.count", -1);
