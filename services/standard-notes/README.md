# standard-notes

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### server

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 2-5% | ~100-200 MB | app image hundreds of MB | idle API |
| expected | 10-30% | ~250-500 MB | notes primarily in db | client sync |
| high | 1-2 cores | ~1 GB+ | attachments / revisions grow elsewhere as configured | many clients syncing |

### db

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-3% | ~64-128 MB | empty postgres small | local |
| expected | 5-20% | ~150-400 MB | grows with revisions | sync queries |
| high | 1+ core | ~1 GB+ | multi-GB possible | bulk ops |

### cache

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~10-30 MB | optional persistence small | local |
| expected | 1-5% | ~30-100 MB | dataset-sized | session/cache traffic |
| high | 0.2-0.5 core | ~256 MB+ | if persistence enabled, similar on disk | cache stampedes |

### localstack

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 5-10% | ~200-400 MB | localstack image is large | local AWS mocks |
| expected | 10-30% | ~400-800 MB | can cache mock data | S3-style calls from the stack |
| high | 1+ core | ~1-2 GB | grows with mocked objects | heavy S3 emulation |

localstack is the heaviest piece in many self-hosted Standard Notes samples.

repo:

* https://standardnotes.com/help/self-hosting/docker

configuration options:

* https://github.com/standardnotes/server/blob/main/docker/docker-entrypoint.sh



&nbsp;

**466f724a616e6574**
