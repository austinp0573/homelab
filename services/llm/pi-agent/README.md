# pi-agent

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### pi

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 0 when not started (`compose run`) | n/a | image / workspace files | none |
| expected | 1-2 cores while the agent is working | ~200-600 MB for the agent process (model cost is on llama.cpp) | workspace / repos you mount | calls to llama.cpp + tool traffic |
| high | multi-core during big tool loops | ~1-2 GB agent-side | checkouts and artifacts grow | large repo walks / many tool calls |

Inference cost shows up on llama.cpp, not in this container.

deploy path on host: `/opt/llm-pi-agent/`

[Pi coding agent](https://github.com/earendil-works/pi) in a container, pointed at local llama.cpp. interactive TUI via `nerdctl compose run`.

Pi has no built-in permission system. isolation here is:

1. whole process in a container
2. only the project dir mounted at `/workspace`
3. a few extensions from Pi's examples (permission gate, protected paths, dirty repo guard, git checkpoint)

## deploy

1. llama.cpp up with a coder model (see `../notes/models-32gb.md`)
2. copy this directory to `/opt/llm-pi-agent/`
3. `cp .env.example .env` and set `LLAMA_BASE_URL` if needed
4. edit `config/models.json` so the baseUrl matches (host IP from inside the container)
5. `./scripts/build.sh`
6. `./scripts/run.sh /path/to/your/project`

## models.json

`config/models.json` is mounted into the container agent home. default provider id is `llamacpp`. after start:

```text
/model
```

and pick `llamacpp/<id>`. the model id should match what llama.cpp advertises in `/v1/models`, or set it explicitly in models.json.

from inside docker/nerdctl, `host.docker.internal` is set via extra_hosts. if that fails, put the LAN IP of the GPU box in both `.env` and `models.json`.

## extensions

shipped under `extensions/`:

| file | why |
|------|-----|
| `permission-gate.ts` | confirm/block `rm -rf`, `sudo`, `chmod/chown 777` |
| `protected-paths.ts` | block writes to `.env`, `.git/`, `node_modules/` |
| `dirty-repo-guard.ts` | warn before session switch/fork with dirty git |
| `git-checkpoint.ts` | stash create per turn for fork restore |

these are adapted from Pi's upstream examples. review them before trusting them with anything important.

## ops

```sh
./scripts/build.sh
./scripts/run.sh ~/code/some-repo
# inside pi: talk normally, /model to switch, Ctrl+C / exit to leave
```

no long-running compose service. `run.sh` is `compose run --rm` so the container dies when you quit.

## note

container user is root inside the image (simple). files written into `/workspace` show up as root-owned on the host unless you adjust. for a personal box that is usually fine; fix with `chown` if it annoys you, or rebuild the image with your uid later.


&nbsp;

**466f724a616e6574**
