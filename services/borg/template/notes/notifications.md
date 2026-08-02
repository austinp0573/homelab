# notifications

`config.yml` includes disabled examples for healthchecks, ntfy, and apprise.

enable only one or two per deployment.

keep tokens out of `config.yml`.

use `.env` for temporary local deployments.

use mounted files or openbao hydration for long lived secrets.

healthchecks is good for missed runs.

ntfy is simple for direct alerts.

apprise is useful when a deployment may change notification providers later.

send logs only if the notification target is trusted.
