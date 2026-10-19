# Heroku Deployment (backend)

| Item | Value |
| --- | --- |
| Heroku app | `abdullahcarpets` (region: eu, stack: heroku-24) |
| API base URL | `https://abdullahcarpets-f997ce1dad43.herokuapp.com/api` |
| Health check | `https://abdullahcarpets-f997ce1dad43.herokuapp.com/api/health` |
| Database | MongoDB Atlas `cluster0.cpzhv5x.mongodb.net` / `mcq` |
| Dyno | `web: node src/server.js` (Procfile), Node 22.x |

## Layout note

This repo is a monorepo (`backend/` + `mobile/`). Heroku git deploys use the repository root,
so the deploy branch is produced with `git subtree split --prefix backend`, which makes
`backend/` the app root (Procfile + package.json at the top).

## First-time / repeat deploy

```powershell
$env:HEROKU_API_KEY = '<api-key>'          # Dashboard -> Account -> API Key

git branch -D heroku-deploy 2>$null
git subtree split --prefix backend -b heroku-deploy
heroku git:remote -a abdullahcarpets
git push heroku heroku-deploy:main --force
```

Or use `scripts/deploy-heroku.ps1` (it also sets the config vars).

## Config vars (values are secret, set once)

| Key | Purpose |
| --- | --- |
| `MONGO_URI` | Atlas `mongodb+srv://...` connection string |
| `NODE_ENV` | `production` |
| `JWT_SECRET` | production signing secret (generated, not the dev placeholder) |
| `JWT_EXPIRES_IN` | `7d` |
| `SMTP_*` / `REPORT_RECIPIENT_EMAIL` | optional: enables the daily report cron |
| `WHATSAPP_*` | optional: enables WhatsApp receipt delivery |

Get/set with:

```powershell
heroku config -a abdullahcarpets
heroku config:set -a abdullahcarpets KEY=value
```

> On Windows, `heroku config:set` is a `.cmd` wrapper and an `&` inside a URI can be split by
> `cmd.exe`. If that happens, set the var through the Platform API (`PATCH
> https://api.heroku.com/apps/<app>/config-vars`) instead.

## Verification

```powershell
# 200 + {"success":true,...}
curl https://abdullahcarpets-f997ce1dad43.herokuapp.com/api/health

# read/write probe against Atlas (uses MONGO_URI from backend/.env)
node scripts/testAtlasConnection.js

# write test against the deployed API (creates + deletes a product with a picture)
node scripts/testProduction.js

# pictures stored inside MongoDB documents (base64), size report
node scripts/atlasImageReport.js

# remove test rows created in a time window (dry run; add --apply to delete)
node scripts/cleanupAtlasTest.js 2026-10-19T17:05:00Z 2026-10-19T17:07:00Z
```

## Mobile app

`mobile/lib/core/constants/app_constants.dart` defaults to `https://api.saisinghshope.me/api`.
To point the app at this deployment, build with:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://abdullahcarpets-f997ce1dad43.herokuapp.com/api
```

or change the `defaultValue` in that file.

## Pictures

Sale and product pictures are stored as base64 data URLs inside MongoDB documents
(`products.images[]`, `sales.items[].image`). No file upload endpoint or disk storage is
involved, so images survive dyno restarts/redeploys.
