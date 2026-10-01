# Student Fees web app update

This update changes the Firebase-hosted web app (`index.html`). The Flutter source in `lib/` is unchanged.

## Install

Upload/replace `index.html` and add `year-utils.mjs` together at the repository/hosting root. Keep all other existing files. The local Node server also needs the included `server.js` change so `.mjs` files are served as JavaScript. Redeploy through the existing Firebase Hosting setup, then refresh the browser.

Do not clear Firebase, recreate the project, or import replacement student data. The update uses the existing Firebase project and existing student document IDs.

## Changes

- Fixed cream, forest-green and gold palette with oval controls, rounded glass panels and metallic highlights; custom colour selection removed. Light/dark mode is retained within that palette.
- Teacher dashboard has year folders. Current and next year appear automatically; previous years remain accessible.
- Students without a year field are displayed in the original 2026 register without changing their stored documents. New students and newly approved requests store `academicYear` for the selected register.
- Class lists and monthly/yearly finance reports use the selected register. A year switch exits open profiles so their records cannot be confused with another register.
- New Year creates an empty register on this browser. Once a student is added, the year is also discovered from the saved student on other devices. Current/next year folders are available on every device.
- New teacher-created accounts use a separate Firebase Auth instance so the teacher stays signed in.
- PDF/note and personal-file sending, receiving, viewing, uploading and deleting controls are removed. Previously stored file metadata and storage objects are untouched. Profile photo upload stays available.

## Validation

Run `node --test test/year-registers.test.mjs`. Four tests cover legacy-year handling, separate totals, rollover, invalid year metadata and non-mutation of existing payments/signatures/files. JavaScript syntax and DOM ID references were also checked. DOM integration with a mocked Firebase adapter passed startup, year switching, class filtering, monthly/yearly totals, creation into 2027, teacher-session preservation and unchanged legacy data.

Live Firebase sign-in/writes and browser rendering still need checking after deployment. No production data was accessed or edited during this update.
