[README-SETUP.md](https://github.com/user-attachments/files/35421409/README-SETUP.md)
# RARE PUBLICATIONS — Fresh rebuild

This is a fresh browser-deployable project. It does not reuse the old website code or old Supabase project.

## What is included
- Responsive public landing page and departments
- Membership application with email OTP verification
- Username + email OTP sign-in via Supabase Edge Functions
- Approved-member workspace shell
- Head application review, member directory, projects, private notes, group chat, library submission
- Row-level security starter schema
- Search metadata, robots.txt and sitemap.xml

## Important honest status
This is a working foundation, not yet the fully completed organisation platform. The leadership appointment/removal/temporary-head governance, direct messages, chat creation and membership automation, notifications, online status, file uploads, task management, library versioning/reviews, trash recovery, and full production security testing still need implementation. Do not announce it as production-ready until these are completed and tested.

## Browser-only setup
1. Create a NEW Supabase project at https://supabase.com/dashboard (save its database password securely).
2. Open SQL Editor and run `supabase/schema.sql`.
3. In Project Settings > API, copy Project URL and publishable/anon key. Paste them into `config.js`.
4. In Supabase Authentication > Providers > Email, enable email OTP. Configure SMTP for reliable production email delivery and set allowed redirect/site URLs to your Vercel URL.
5. Deploy Edge Functions `request-code` and `verify-code` from the Supabase dashboard (Edge Functions > Deploy a new function). Paste the corresponding `index.ts` source. Add environment secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` in function secrets. The service-role key must remain server-side and must never be placed in config.js.
6. Create a new public GitHub repository at https://github.com/new. Upload all files and folders from this package using GitHub's web interface.
7. Import that repository at https://vercel.com/new and deploy. No installation is required.
8. Replace `YOUR-NEW-VERCEL-URL` in `config.js`, `robots.txt`, `sitemap.xml`, and the canonical URL in `index.html` with the actual deployment URL.
9. In Supabase Auth URL Configuration, set Site URL to the deployed URL.
10. Configure Google Search Console at https://search.google.com/search-console, verify the site, and submit `/sitemap.xml`. Indexing can take days or weeks and ranking is not guaranteed.

## First Head bootstrap
For safety, do not let anyone register as Head. The first Head must be set by a one-time trusted database administrator action after the first account has been verified and its identity confirmed. Then use a secure, audited governance workflow to appoint the second Permanent Head. Never expose service-role keys in browser code.

## Security notes
- The Edge Functions use service role only server-side. Configure rate limits / CAPTCHA / SMTP protections before public launch.
- The starter schema deliberately does not permit self-assignment of Head.
- The profile table and review workflow should receive a security review before real membership data is collected.
- Existing accounts from the old site are not migrated. This is a new system and needs fresh applications/accounts.
