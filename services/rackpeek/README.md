# RackPeek

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### rackpeek

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-2% | ~40-80 MB | small db/data dir | idle |
| expected | 2-8% | ~80-150 MB | inventory data usually modest | UI / API use |
| high | 0.2-0.5 core | ~200-400 MB | grows with documented assets / images | imports or many clients |

A webui & CLI tool for documenting and managing home lab and small-scale IT infrastructure.

https://github.com/timmoth/rackpeek

&nbsp;

**466f724a616e6574**
