# WhatsApp PDF Invoice Delivery (Meta Cloud API)

Every sale that includes a customer phone number automatically receives a PDF
invoice on WhatsApp. This document covers configuration, testing, the webhook,
and switching from the Meta test number to the client's real number.

## How it works

1. A sale is created in `saleController.createSale` → `whatsappService.sendWhatsAppReceipt`.
2. The invoice PDF is generated in memory (`generateSaleReceiptPDF`) — nothing is
   written to a public/static directory.
3. The PDF is uploaded to Meta (`POST /{phoneId}/media`) and sent as a document
   message (`POST /{phoneId}/messages`).
4. The delivery result is stored on the sale in `whatsappReceipt` and updated
   when Meta calls the webhook (`sent` → `delivered` → `read`, or `failed`).
5. WhatsApp problems NEVER break a sale — `sendWhatsAppReceipt` never throws.

## Environment variables

| Variable | Purpose |
| --- | --- |
| `WHATSAPP_API_TOKEN` | Permanent Meta access token (secret — never commit/log). |
| `WHATSAPP_PHONE_ID` | WhatsApp Business phone number ID. |
| `WHATSAPP_API_VERSION` | Graph API version, default `v21.0`. |
| `WHATSAPP_COUNTRY_CODE` | Country code for local numbers, default `92`. |
| `WHATSAPP_RECEIPTS_ENABLED` | `false` disables auto-sending entirely. |
| `WHATSAPP_TEST_MODE` | `true` = send only to `WHATSAPP_TEST_RECIPIENT`. |
| `WHATSAPP_TEST_RECIPIENT` | A number verified on the WABA (e.g. `923001234567`). |
| `WHATSAPP_WEBHOOK_VERIFY_TOKEN` | Private string entered in Meta's webhook setup. |
| `WHATSAPP_APP_SECRET` | Meta App Secret, used to verify `X-Hub-Signature-256`. |
| `WHATSAPP_UTILITY_TEMPLATE` | Optional approved template used as a fallback. |

`WHATSAPP_API_TOKEN` and `WHATSAPP_PHONE_ID` must both be set before anything is
sent. A missing token simply yields `reason: "not_configured"`.

## Test mode

While `WHATSAPP_TEST_MODE=true`, invoices are delivered **only** to
`WHATSAPP_TEST_RECIPIENT` — a number verified in your WhatsApp Business Account.
Real customer numbers are never messaged, and the sale records
`reason: "test_mode_blocked"` for them.

The recipient can be in local (`03001234567`), international (`+92...`), or
prefixed (`0092...`) form; it is normalised to `92...` internally.

## Webhook (delivery status)

1. Expose the backend publicly (e.g. `cloudflared tunnel --url http://localhost:5000`).
2. In the Meta app → WhatsApp → Configuration, set the callback URL to
   `https://<your-host>/api/whatsapp/webhook`.
3. Set the **Verify token** to the same value as `WHATSAPP_WEBHOOK_VERIFY_TOKEN`.
4. Subscribe to the `messages` field.
5. Set `WHATSAPP_APP_SECRET` so every event is signature-checked.

Endpoints (public, authenticated by Meta signature — not by a user JWT):

- `GET /api/whatsapp/webhook` — verification handshake.
- `POST /api/whatsapp/webhook` — delivery status events, applied idempotently to
  the matching sale by `whatsappReceipt.messageId`.

## Switching to the client's real WhatsApp number

1. In Meta Business Manager, add the client's phone number as a WhatsApp sender
   and complete business verification.
2. Set `WHATSAPP_PHONE_ID` to the new (production) phone number ID.
3. Set `WHATSAPP_API_TOKEN` to a permanent token for the production app.
4. Set `WHATSAPP_TEST_MODE=false` and remove/blank `WHATSAPP_TEST_RECIPIENT`.
5. Ensure the webhook URL still points at the production backend.

## Testing

```bash
cd backend
npm test                          # unit tests (no network, no DB)
node -c src/services/whatsappService.js   # syntax check
```

Manual webhook verification handshake:

```bash
curl "http://localhost:5000/api/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=<VERIFY_TOKEN>&hub.challenge=hello123"
# → hello123   (403 if the token is wrong)
```

## Notes

- Only JPEG item thumbnails are embedded. PDFKit `^0.20.2` can block the event
  loop on some PNGs, so PNGs are safely skipped.
- Duplicate sends are prevented: a sale whose receipt was already attempted is
  never resent.
- If document delivery is rejected and `WHATSAPP_UTILITY_TEMPLATE` is set, an
  approved utility template is attempted as a fallback.
