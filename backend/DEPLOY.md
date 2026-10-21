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

`mobile/lib/core/constants/app_constants.dart` defaults to the local development API
(`http://10.0.2.2:5000/api`, the Android emulator loopback to a locally running backend).
To point the app at this deployment, build with:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://abdullahcarpets-f997ce1dad43.herokuapp.com/api
```

or change the `defaultValue` in that file to
`https://api.saisinghshope.me/api`.

## Manager action notifications

Every change a manager makes inside their own branch / warehouse (add, edit,
delete, restore, stock in / out / transfer) is written to the audit log **and**
pushed to the admin as a `manager_action` notification.

The notification carries a structured `data` payload so the app can show exactly
what happened instead of a one line message:

```json
{
  "title": "Ali Khan deleted a product at Branch 2",
  "body": "Name: Premium Carpet 12x18 · SKU: PC-1218 · Quantity: 50",
  "type": "manager_action",
  "data": {
    "actionType": "DELETE_PRODUCT",
    "recordType": "Product",
    "shopId": "…",
    "shopName": "Branch 2",
    "performedByName": "Ali Khan",
    "auditLogId": "…",
    "identity": "Premium Carpet 12x18 (PC-1218)",
    "facts":   [{ "label": "Quantity", "value": "50" }],
    "changes": [{ "label": "Selling price", "from": "Rs. 900", "to": "Rs. 1,150", "delta": "+Rs. 250" }],
    "itemLines": ["2 x Premium Carpet @ Rs. 1,150 = Rs. 2,300"]
  }
}
```

`facts` describe the record (used for adds and deletes), `changes` list the
fields that differ with the old value, the new value and the delta (used for
edits). The same breakdown is stored on the audit log (`facts` / `changes` /
`itemLines`) and is returned by `/api/audit` and `/api/dashboard`, so the
"Recent Activity" feed of every branch shows the same details.

Sale and expense creation keep their own notification types (`new_sale`,
`expense_alert`) so they are not duplicated - both are enriched with the same
payload.

To verify the whole flow end to end (manager adds / edits / deletes, admin
receives the details, everything is cleaned up afterwards):

```powershell
node scripts/testManagerNotifications.js
```

## Branch activity log (admin dashboard)

The admin dashboard branch cards (both the carousel card and the
"Branches & Warehouse" list) carry a small **logs** button next to
"Open Branch". Tapping it opens the merged activity log of that single
branch (audit entries + stock movements) with the same "what changed"
details as the notifications.

The feed is built from two endpoints that both accept an optional `shopId`:

| Endpoint                            | Notes                                    |
| ----------------------------------- | ---------------------------------------- |
| `GET /api/audit?shopId=<id>`        | Audit entries of one branch              |
| `GET /api/inventory/history?shopId=<id>` | Stock movements of one branch       |

A manager calling `/api/inventory/history` is always forced back to their own
assigned shop, the query parameter cannot widen the scope.

## Notifications

| Method   | Path                       | Description                        |
| -------- | -------------------------- | ---------------------------------- |
| `GET`    | `/api/notifications`       | List (`page`, `limit`)             |
| `GET`    | `/api/notifications/unread-count` | Unread counter               |
| `PUT`    | `/api/notifications/read-all` | Mark every notification as read |
| `PUT`    | `/api/notifications/:id/read`  | Mark one notification as read |
| `DELETE` | `/api/notifications/:id`   | Delete one notification            |
| `DELETE` | `/api/notifications`       | **Delete all notifications** (the "Delete all" button in the app) |

All of them only ever touch the notifications of the signed-in user
(`{ user: req.user._id }`). `DELETE /api/notifications` returns
`{ deleted: <count> }`.

## Pictures

Sale and product pictures are stored as base64 data URLs inside MongoDB documents
(`products.images[]`, `sales.items[].image`). No file upload endpoint or disk storage is
involved, so images survive dyno restarts/redeploys.
