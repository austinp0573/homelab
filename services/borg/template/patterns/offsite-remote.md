# offsite remote

add another repository entry in `config.yml` when an offsite target is ready.

use a separate ssh key for the offsite target.

use a separate known hosts entry.

use a stable repository path.

do not reuse the truenas append only key for a different provider.

if the offsite target is less trusted, keep the same encryption mode and passphrase handling.

consider a different passphrase per offsite repository if the repo has a different risk profile.

keep prune and compact rules clear for each remote.
