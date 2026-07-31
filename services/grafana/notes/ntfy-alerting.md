# grafana alerts -> ntfy

grafana-native alerting first. when you want phone/desktop push, add an ntfy contact point.

## ntfy side

create a publisher (or reuse one) on the ntfy stack:

```sh
# on the ntfy host
./scripts/create-publisher.sh grafana
```

note the token and topic. public base url is whatever you already use (`https://ntfy.example.com`).

## grafana side

in the ui: Alerting -> Contact points -> add contact point.

- type: webhook (ntfy accepts a simple POST)
- url: `https://ntfy.example.com/<topic>`
- http headers: `Authorization: Bearer <token>`

or use the ntfy "email"/"publish" style you already documented for other apps - same token model as gatus.

notification policy: route the default policy (or a team label) to that contact point.

## test

fire a test notification from the contact point page. if it fails, check ntfy publisher ACL and that grafana can reach the public ntfy url (or an internal url if you prefer).

do not put the ntfy token in git. if you later provision contact points as yaml, keep secrets out of the repo the same way gatus keeps `20-alerting.yaml` local.
