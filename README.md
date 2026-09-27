# Surgical Logbook — Free Android-first PWA

## 1. Supabase
You already created the `cases` table and private `case-files` bucket. Run `setup.sql` in Supabase SQL Editor.

## 2. Connect the app
Open `config.js` and replace the two placeholders with your Supabase **Project URL** and **Publishable key**. Never use the secret/service_role key.

## 3. Run locally
Serve the folder over HTTP (not file://), e.g. with VS Code Live Server or any static host.

## 4. GitHub Pages
Upload all files to a GitHub repository. Enable Pages from the repository Settings. Open the Pages URL on Android Chrome and choose Install app/Add to Home screen.

## Notes
- Supabase Auth is used for accounts.
- Cases are stored in PostgreSQL; RLS restricts each user to their own cases.
- `case-files` is private and policies expect paths beginning with the authenticated user UUID.
- The service worker caches the app shell for offline opening. Case offline queueing can be extended in the next build.


## Password recovery
The app includes a Forgot password flow and a secure reset-password screen. The recovery email redirects back to the GitHub Pages app.

## v6 case-entry upgrade
- Sectioned Add/Edit Case form
- Better mobile-friendly operative entry layout
- Attachment image/PDF preview before upload
- Required-field/date validation
- Private attachment opening through temporary signed URLs
- Existing authentication and password recovery retained
