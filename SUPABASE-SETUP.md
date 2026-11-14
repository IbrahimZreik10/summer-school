# Online database (Supabase)

The website saves every student's progress in a Supabase database, so the data is real and is the same on every device. Professors see every student's results live.

## Where the keys live

The Supabase address and public key are **not** in the code on GitHub. `index.html` only holds the placeholders `%%SUPABASE_URL%%` and `%%SUPABASE_ANON_KEY%%`. When something is pushed to `main`, the **Publish site** workflow (`.github/workflows/deploy.yml`) reads the two repository secrets and puts the real values into the published copy of the page.

To change them: **Settings → Secrets and variables → Actions** on the repository, edit `SUPABASE_URL` or `SUPABASE_ANON_KEY`, then **Actions → Publish site → Run workflow**.

The public ("anon" or "publishable") key is designed to be used in the browser, so it is visible to visitors in the published page. That is safe because row level security (in `supabase-setup.sql`) decides what each signed-in person can read or change. **Never** use the `service_role` or secret key anywhere in this project.

## One-time set-up in Supabase

1. **SQL Editor → New query**: paste all of `supabase-setup.sql`, then **Run**.
2. **Authentication → Sign In / Providers → Email**: switch off **Confirm email**, so students can start straight away.
3. **Project Settings → API**: copy the Project URL and the anon public key into the two GitHub secrets.

## Adding a professor

1. The professor signs in once on the website with their email and a password they choose.
2. In **SQL Editor**, run (change the email and the id, which must match an id in `PROFESSORS` in `index.html`):

```sql
insert into public.staff (user_id, email, professor_id)
select id, email, 'prof-a' from auth.users where email = 'name@hw.ac.uk'
on conflict (user_id) do update set professor_id = excluded.professor_id;

delete from public.students
where user_id = (select id from auth.users where email = 'name@hw.ac.uk');
```

The next time they sign in, they get the professor pages and every student's real results.

## Seeing the data

In Supabase, **Table Editor → students** shows one row per student: username, progress (`state`) and recent activity (`events`).
