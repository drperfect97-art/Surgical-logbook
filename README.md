# Surgical Logbook — production-oriented Android-first PWA

This build uses **Supabase PostgreSQL as the cloud source of truth** and **IndexedDB as the offline cache/queue**. It does not use localStorage for case persistence.

## Deploy to GitHub Pages
1. Extract this ZIP.
2. Upload the files inside the folder to the root of `Surgical-logbook`.
3. Keep `config.js` in the repo because it contains only the browser-safe publishable key; RLS protects data.
4. Commit changes and wait for GitHub Pages to finish.
5. Open the Pages URL over HTTPS and optionally install it from Chrome → Add to Home screen.

## Supabase migration
Run `setup.sql` once in Supabase SQL Editor. It adds production fields, UUIDs, timestamps, RLS, private storage policies, user profiles, the case-number RPC and Realtime publication.

If Supabase reports that `supabase_realtime` already contains `cases`, that single publication statement can be skipped; the rest of the migration remains valid.

## Important current capabilities
- Supabase Auth email/password + existing phone OTP UI
- Stable UUID case IDs
- IndexedDB offline cache and pending sync queue
- Cloud upsert + pull + Realtime case changes
- Auto-generated yearly case IDs when online
- Case entry, drafts, validation, attachments
- Search and filters
- Dashboard/statistics from stored records
- Trash/recovery through soft delete
- JSON/CSV export and print-to-PDF workflow
- PWA service worker with cache versioning

## Limitations that require a native/backend companion
Google Drive OAuth, full Android SAF integration, biometric/PIN lock, true background WorkManager sync, and packaged photo backup archives are not safely implementable as a GitHub Pages-only static client without an OAuth/backend/native layer. This build intentionally does not hard-code Google credentials or fake those features.

## Required acceptance tests
Run the 12 tests in the product specification after deployment. In particular test: close/reopen, offline case creation, reconnect, second-device login, edit propagation, five-photo sync, trash restore, export/import, Excel/CSV, PDF print, and OT note generation.


## v11 patch
- Case detail close button fixed.
- Local pending/synced photos are visible from the case detail page.
- Attachment errors are retained as failed/pending sync status.
- Service worker cache bumped to v11.
