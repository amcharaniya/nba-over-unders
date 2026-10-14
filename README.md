# Over/Under League

An NBA win-total over/under pool for five friends. Everyone picks Over or Under on all 30 teams and locks 5 of them. A correct pick is worth 1 point and a correct lock is worth 3. The site projects points from each team's current win % and tracks which totals are still live.

- **Site:** a single static page (`index.html`) hosted on GitHub Pages.
- **Standings:** a GitHub Action scrapes [Basketball-Reference](https://www.basketball-reference.com/leagues/NBA_2027_standings.html) every morning and commits `data/standings.json`.
- **Picks and sign-in:** stored in a free [Supabase](https://supabase.com) project. Its database rules keep each person's picks private until the deadline, and block changes after it.

## Files

| Path | What it is |
|---|---|
| `index.html` | The whole site |
| `supabase-config.js` | Your Supabase URL and anon key |
| `data/config.json` | Lines, player names, lock count and pick deadline |
| `data/standings.json` | Current W–L records (updated by the Action) |
| `scripts/fetch_standings.py` | The Basketball-Reference scraper |
| `.github/workflows/standings.yml` | The daily standings job |
| `supabase/schema.sql` | Database tables and access rules |

## One-time setup

### 1. Supabase (about 10 minutes)
1. Create a free account at supabase.com and a new project. Any name and region work; save the database password somewhere.
2. Open **SQL Editor → New query**. Paste `supabase/schema.sql` and click **Run**. Then run a second query adding each friend's email (see step 5 at the bottom of the file). Keep emails out of this public repo.
3. Open **Authentication → URL Configuration**:
   - **Site URL:** `https://<your-github-username>.github.io/<repo-name>/`
   - **Redirect URLs:** add that same URL.
4. Open **Project Settings → API**. Copy the **Project URL** and the **anon public** key into `supabase-config.js`, then commit.

### 2. GitHub Pages
1. Push this folder to a GitHub repository. The repo must be public to use Pages on a free account.
2. Open **Settings → Pages**. Under **Build and deployment**, choose **Deploy from a branch**, then pick `main` and `/ (root)`.
3. Open **Settings → Actions → General → Workflow permissions** and choose **Read and write permissions**, so the standings job can commit.
4. Open the **Actions** tab, select **Update standings**, and click **Run workflow** once to confirm it works.

Share `https://<your-github-username>.github.io/<repo-name>/` with the league. Each person signs in on the **My picks** tab with the email you listed, using a link sent to their inbox.

## During the season

- **Changing the deadline:** update both `picksCloseAt` in `data/config.json` and the timestamp in `picks_open()` in `supabase/schema.sql`. Re-run just the `create or replace function public.picks_open()` statement in the SQL Editor.
- **Adding or changing an email:** run `insert into public.members (email, player) values ('new@example.com', 'Name') on conflict (email) do update set player = excluded.player;` in the SQL Editor.
- **If standings stop updating:** check the Actions tab. Basketball-Reference sometimes rate-limits cloud servers. A failed day leaves the previous standings in place, and the next run usually works.
- **Scheduled Actions pause** after 60 days without repository activity. The daily standings commits count as activity, so this shouldn't happen during the season.
- **Sign-in emails:** Supabase's built-in email sender only allows a few emails per hour. That's fine for five people. If someone hits the limit, wait an hour and try again.

## Running locally

```bash
python3 -m http.server 8000
```

Then open http://localhost:8000. To sign in locally, add `http://localhost:8000/` to Supabase's Redirect URLs.
