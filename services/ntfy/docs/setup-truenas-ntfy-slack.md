Current TrueNAS's Slack alert implementation does exactly this:

```python
requests.post(
    self.attributes["url"],
    headers={"Content-type": "application/json"},
    data=json.dumps({
        "text": "...TrueNAS alert text..."
    }),
)
```

So TrueNAS sends:

```json
{
  "text": "TrueNAS alert text"
}
```

to whatever URL you put into **Webhook URL**. 

ntfy explicitly supports receiving arbitrary JSON webhooks and extracting fields using inline Go templates. Its documented syntax includes:

```text
?tpl=1&m={{.field}}
```

or the URL-encoded equivalent. 

Therefore this part is sound:

```text
https://<NTFY_URL>/<TOPIC>?tpl=1&m={{.text}}
```

The problem is authentication.

---

# 1. wrong `auth=` syntax

This:

```text
&auth=Bearer+YOUR_TOKEN
```

is **not** how ntfy's `auth` query parameter works.

Normally an ntfy access token is sent as:

```http
Authorization: Bearer tk_xxxxxxxxx
```

But TrueNAS's Slack implementation does not let us add arbitrary HTTP headers.

Fortunately, ntfy has an `auth=` query parameter specifically for situations like this. But ntfy requires the **entire Authorization header to be Base64-encoded**, with trailing `=` removed. 

Conceptually:

```text
Bearer tk_xxxxxxxxx
        |
        | Base64 encode entire string
        v
QmVhcmVyIHRrX3h4eHh4eHh4eA
```

Then:

```text
?auth=QmVhcmVyIHRrX3h4eHh4eHh4eA
```

That is the missing piece.

---

# 2. Generate the ntfy webhook URL

Do this from a Linux shell. It can be the TrueNAS shell.

Set the token:

```bash
NTFY_TOKEN='tk_YOUR_ACTUAL_TOKEN'
```

Now generate a correctly encoded `auth` parameter:

```bash
AUTH="$(
    python3 -c '
import base64
import sys
import urllib.parse

header = ("Bearer " + sys.argv[1]).encode()
encoded = base64.b64encode(header).decode().rstrip("=")
print(urllib.parse.quote(encoded, safe=""))
' "$NTFY_TOKEN"
)"
```

Now create the final webhook:

```bash
WEBHOOK="https://ntfy.tusko.org/infra?tpl=1&m=%7B%7B.text%7D%7D&md=1&auth=${AUTH}"
```

Display it:

```bash
printf '%s\n' "$WEBHOOK"
```

It will look something like:

```text
https://ntfy.tusko.org/infra?tpl=1&m=%7B%7B.text%7D%7D&md=1&auth=QmVhcmVyIHRrX2FiY2RlZmdoaWo
```

**Use `/topic`, not `/topic/`.** Avoiding the trailing slash eliminates any possibility that the reverse proxy or ntfy redirects the POST.

ntfy supports `md=1` as the query-parameter alias for enabling Markdown. 

---

# 3. Test the exact TrueNAS → ntfy protocol first

Before involving TrueNAS's alert subsystem, imitate exactly what its Slack backend sends:

```bash
curl -i \
    -H 'Content-Type: application/json' \
    --data '{"text":"TrueNAS ntfy integration test"}' \
    "$WEBHOOK"
```

This is an important diagnostic step.

Should immediately be receive:

> TrueNAS ntfy integration test

on the `topic` topic.

And the HTTP response should be successful.

This test is almost identical to what TrueNAS will subsequently do: JSON POST containing a `text` property. TrueNAS's source confirms that behavior. 

### If this test fails

The HTTP response indicates where the problem is:

| Result | Likely cause |
|---|---|
| `200` | ntfy side is working |
| `400` | ntfy template/URL syntax |
| `401` | token/auth encoding problem |
| `403` | token lacks write permission to `infra` |
| `404` | reverse proxy or ntfy routing |
| TLS error | certificate/trust problem |
| connection failure | DNS/firewall/routing |

Do **not** continue troubleshooting TrueNAS until this command works.

---

# 4. Put it into TrueNAS

Go to:

**Alerts → Alert Settings → Alert Services → Add**

Configure:

```text
Name:
ntfy

Type:
Slack

Level:
WARNING
```

For **Webhook URL**, paste the complete generated value:

```text
https://ntfy.tusko.org/infra?tpl=1&m=%7B%7B.text%7D%7D&md=1&auth=...
```

Then save it.

TrueNAS currently officially supports Slack as an alert-service type and only asks for its webhook URL. 

The resulting path is simply:

```text
                     TrueNAS
                        │
                        │ POST
                        │ Content-Type: application/json
                        │
                        │ {"text":"..."}
                        ▼
https://ntfy.tusko.org/infra
                        │
                        │ ?tpl=1
                        │ m={{.text}}
                        │ auth=<encoded bearer header>
                        ▼
                      ntfy
                        │
                        ▼
                   infra topic
```

No Apprise, SMTP server, custom middleware, or extra container is necessary.

---

# 5. About that `'type'` error

This:

```text
Error Name: EINVAL
Error Code: 22
Reason: 'type'
Error Class: KeyError
```

is **not ntfy rejecting the request**.

And putting:

```text
{{.text}}
```

inside the URL cannot somehow cause Python to lose a dictionary key,

The error is inside TrueNAS before—or while—constructing the alert-service object.

There is a particularly relevant reason this can occur on recent TrueNAS versions.

### TrueNAS changed the alert-service API in 25.10

In TrueNAS 25.04 the object looked like:

```json
{
  "name": "ntfy",
  "type": "Slack",
  "attributes": {
    "url": "..."
  },
  "level": "WARNING"
}
```

The 25.04 API documentation confirms that `type` was a required top-level field. 

Starting with the 25.10 API, TrueNAS **removed the top-level `type`** and moved it into `attributes`. The official changelog explicitly documents this change. 

The current object is:

```json
{
  "name": "ntfy",
  "attributes": {
    "type": "Slack",
    "url": "..."
  },
  "level": "WARNING"
}
```

TrueNAS 26.0's API explicitly defines the Slack attributes as:

```text
type = "Slack"
url  = <webhook URL>
``` 


So some of the `midclt` examples are actually **wrong for TrueNAS 25.10+**.

---

# 6. If the GUI still gives `'type'`, bypass it correctly

First determine exactly what version is running:

```bash
midclt call system.version
```

## TrueNAS 25.10 / 26.x

Test without creating anything:

```bash
midclt call alertservice.test '{
  "name": "ntfy",
  "attributes": {
    "type": "Slack",
    "url": "PASTE_THE_COMPLETE_NTFY_WEBHOOK_URL_HERE"
  },
  "level": "WARNING",
  "enabled": true
}'
```

The current API uses exactly this nested `attributes.type` arrangement. 

If that succeeds, create it:

```bash
midclt call alertservice.create '{
  "name": "ntfy",
  "attributes": {
    "type": "Slack",
    "url": "PASTE_THE_COMPLETE_NTFY_WEBHOOK_URL_HERE"
  },
  "level": "WARNING",
  "enabled": true
}'
```

The official 26.0 schema requires `name`, `attributes`, `level`, and optionally `enabled`; the Slack attributes require `type: "Slack"` and `url`. 

## TrueNAS 25.04 or older API style

Use:

```bash
midclt call alertservice.create '{
  "name": "ntfy",
  "type": "Slack",
  "attributes": {
    "url": "PASTE_THE_COMPLETE_NTFY_WEBHOOK_URL_HERE"
  },
  "level": "WARNING",
  "enabled": true
}'
```

That corresponds to the older API schema. 

---

# 7. Check what TrueNAS actually stored

After creating it:

```bash
midclt call alertservice.query | jq
```

On 25.10+, you want to see something broadly like:

```json
{
  "name": "ntfy",
  "attributes": {
    "type": "Slack",
    "url": "https://ntfy.tusko.org/infra?..."
  },
  "level": "WARNING",
  "enabled": true
}
```

If that is present, TrueNAS has a normal Slack alert service. It just happens that the "Slack webhook" is ntfy.

---

## Security recommendation

Create a dedicated ntfy token specifically for this:

```text
truenas → write → infra
```

It should not be your ntfy administrator token.

The authentication secret necessarily appears in the webhook URL because TrueNAS's Slack backend has no facility for arbitrary Authorization headers. ntfy provides the encoded `auth=` mechanism precisely to support clients where headers cannot be configured. 

## Bottom line

Intended architecture is valid:

```text
TrueNAS Slack Alert Service
        ↓
POST {"text":"..."}
        ↓
ntfy inline template
        ↓
{{.text}}
        ↓
infra
```

The webhook to use is:

```text
https://ntfy.tusko.org/infra?tpl=1&m=%7B%7B.text%7D%7D&md=1&auth=<BASE64-ENCODED-AND-URL-ENCODED-"Bearer tk_...">
```

**not**

```text
...?auth=Bearer+tk_...
```

I would start with the `curl` test above. If that succeeds but TrueNAS still throws `'type'`, conclusively separated the problem into a **TrueNAS alert-service/UI schema problem**, and the version-appropriate `midclt` command above bypasses it.
