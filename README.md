# PaySplit

Log Apple Pay purchases to Splitwise straight from a notification — no server, no Splitwise Pro.

```
Tap Apple Pay ─► payment completes ─► ~10s later: "Split Chipotle – $23.40?"
   ─► pick group / friend ─► description + amount prefilled, edit if needed
   ─► choose split ─► expense created in Splitwise ─► ✅ confirmation banner
```

Built with an iOS **Wallet automation** (iOS 17+) + the free **Splitwise API**.
Ignore the notification and nothing is logged.

---

## 1. Get a Splitwise API key (free)

1. Log in at <https://www.splitwise.com>.
2. Open <https://secure.splitwise.com/apps> → **Register your application**.
   - Name: `PaySplit` · Description: anything · Homepage URL: any URL · Callback URL: blank.
3. Accept the terms → **Register and get API key**.
4. On the app page, under **API keys**, click **Generate API key** and copy it.

> The key has full access to your account. Never commit it or share it.

## 2. Get your IDs

```bash
./scripts/get-ids.sh
```

Prompts for the key (hidden), then prints your user ID, groups, friends, and a
ready-to-paste **Targets** dictionary for the shortcut. Requires `curl` and `jq`
(both ship with recent macOS).

## 3. Build the "Split Payment" shortcut

In the Shortcuts app, create a new shortcut named **Split Payment**:

| # | Action | Details |
|---|--------|---------|
| 1 | **Wait** | 10 seconds — lets the Wallet "Done" screen clear |
| 2 | **Set Variable** `Merchant` | Shortcut Input → *Merchant* |
| 3 | **Get Numbers from Input** → **Set Variable** `Amount` | Shortcut Input → *Amount* (strips `$`) |
| 4 | **Dictionary** `Targets` | Paste the output of `get-ids.sh`; trim to the groups/friends you use |
| 5 | **Choose from List** | Keys of `Targets` + `Skip`. Prompt: `Split Merchant – $Amount?` |
| 6 | **If** chosen = `Skip` | **Stop This Shortcut** |
| 7 | **Get Dictionary Value** | chosen key from `Targets` → `Target` |
| 8 | **Ask for Input** (Text) | "Description", default `Merchant` → `Desc` |
| 9 | **Ask for Input** (Number) | "Amount", default `Amount` → `Cost` |
| 10 | **Choose from Menu** | "Split how?" → `Split equally` / `They owe full amount` |
| 11 | **Build body** | See [Request bodies](#request-bodies) |
| 12 | **Get Contents of URL** | `POST https://secure.splitwise.com/api/v3.0/create_expense`<br>Header `Authorization: Bearer YOUR_KEY`<br>Request Body: JSON (step 11) |
| 13 | **Get Dictionary Value** `errors` | from response |
| 14 | **If** `errors` has any value | **Show Alert** with errors · **Otherwise** **Show Notification** `✅ Logged $Cost – Desc` |

### Request bodies

**Group, split equally** → [`examples/group-equal.json`](examples/group-equal.json)

```json
{ "cost": Cost, "description": Desc, "group_id": Target.id,
  "split_equally": true, "currency_code": "USD" }
```

**Friend, split equally** → [`examples/friend-equal.json`](examples/friend-equal.json)

Compute shares so they sum exactly to the cost:
- `TheirShare` = **Round** (Cost ÷ 2) to 2 decimals
- `MyShare` = Cost − TheirShare

```json
{ "cost": Cost, "description": Desc, "group_id": 0, "currency_code": "USD",
  "users__0__user_id": YOUR_ID,   "users__0__paid_share": Cost, "users__0__owed_share": MyShare,
  "users__1__user_id": Target.id, "users__1__paid_share": 0,    "users__1__owed_share": TheirShare }
```

**Friend owes the full amount** → [`examples/friend-owes-full.json`](examples/friend-owes-full.json)
Same as above with `MyShare = 0`, `TheirShare = Cost`.

> "They owe full" inside a *group* needs a member picker — not covered yet.

## 4. Create the automation

Shortcuts → **Automation** → **+** → **Wallet** → select your cards →
**Run Immediately** → add **Run Shortcut** → *Split Payment*, input = **Shortcut Input**.

Because it runs in the background, the list prompt arrives as a notification —
tap it to answer.

## Testing without paying

Run the expense call directly from a terminal (creates a real expense — delete it after):

```bash
curl -s -X POST https://secure.splitwise.com/api/v3.0/create_expense \
  -H "Authorization: Bearer $SPLITWISE_API_KEY" \
  -H "Content-Type: application/json" \
  -d @examples/group-equal.json | jq '.errors, .expenses[0].id'
```

(Edit the example IDs first.) To test the shortcut itself, temporarily replace
steps 2–3 with fixed values and run it manually.

## Caveats

- **Free-tier limits:** Splitwise limits daily expenses on free accounts; unclear
  whether API-created expenses count. Fine for a few splits a day.
- **Authorized amount:** Wallet reports the tap amount — restaurant tips added later
  aren't included. Fix it in the Amount prompt.
- **Key in plain text:** the API key lives inside the shortcut. Remove it before
  sharing the shortcut.
- **Android / Google Pay:** no Wallet trigger. Use MacroDroid/Tasker on the Google
  Wallet notification, regex out merchant + amount, and send the same POST.

## API reference

- Docs: <https://dev.splitwise.com>
- `GET /get_current_user`, `GET /get_groups`, `GET /get_friends`, `POST /create_expense`
