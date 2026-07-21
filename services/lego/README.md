# lego

**documentation:** [https://go-acme.github.io/lego/index.html](https://go-acme.github.io/lego/index.html)

## dns-01 method

using lego with cloudflare documentation can be found at:
* [https://go-acme.github.io/lego/dns/cloudflare/](https://go-acme.github.io/lego/dns/cloudflare/)

create cloudflare api token with: 
* `zone / zone / read`
* `zone / dns / edit`

This will be the:
* `CF_DNS_API_TOKEN`

**Credentials**
| Environment Variable Name | Description |
| --- | --- |
| CF_API_EMAIL | Account email |
| CF_API_KEY | API key |
| CF_DNS_API_TOKEN | API token with DNS:Edit permission (since v3.1.0) |
| CF_ZONE_API_TOKEN | API token with Zone:Read permission (since v3.1.0) |
| CLOUDFLARE_API_KEY | Alias to CF_API_KEY |
| CLOUDFLARE_DNS_API_TOKEN | Alias to CF_DNS_API_TOKEN |
| CLOUDFLARE_EMAIL | Alias to CF_API_EMAIL |
| CLOUDFLARE_ZONE_API_TOKEN | Alias to CF_ZONE_API_TOKEN |
The environment variable names can be suffixed by _FILE to reference a file instead of a value. More information here.

**Additional Configuration**
| Environment Variable Name | Description |
| --- | --- |
| CLOUDFLARE_BASE_URL | API base URL (Default: https://api.cloudflare.com/client/v4) |
| CLOUDFLARE_HTTP_TIMEOUT | API request timeout in seconds (Default: ) |
| CLOUDFLARE_POLLING_INTERVAL | Time between DNS propagation check in seconds (Default: 2) |
| CLOUDFLARE_PROPAGATION_TIMEOUT | Maximum waiting time for DNS propagation in seconds (Default: 120) |
| CLOUDFLARE_TTL | The TTL of the TXT record used for the DNS challenge in seconds (Default: 120) |
