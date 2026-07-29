# pi-agent env

interactive `compose run` agent. parked per README. keep `models.json` and any smoke URLs in sync.

## `.env` / compose

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `llm-pi-agent` | Compose project for the interactive agent image/run wrappers. Mostly matters so `run.sh` / `build.sh` hit the right project and do not collide with llama's project name. This is not a long-running daemon stack — still keep the name stable for local image tags and volume leftovers. I treat it as parked tooling, not production. |
| `CONTAINER_NAME` | `llm-pi` | Name used when the agent container is created via compose run. Helps find the ephemeral container in `ps -a` when a session hangs. Not a stable DNS service on `llm-backend` like llama-cpp. Do not assume other stacks can reach `llm-pi` as a peer API. |
| `PI_IMAGE` | `local/llm-pi-agent:latest` | Locally built image from `scripts/build.sh`. If you skip the build, compose run fails with a missing image, not a helpful "build first". Retagging without rebuilding leaves you on stale agent code. I pin by rebuilding when llama API quirks change. |
| `PROJECT_DIR` | `.` | Host path mounted as the working project for the agent. `run.sh` overrides this to the real project path you pass in — the `.env` default is only a placeholder. Pointing at the wrong tree means the agent edits or reads files you did not intend. Runs as root in the container, so host file ownership can flip to root. |
| `OPENAI_API_KEY` | `local` | Dummy key for OpenAI-client libraries that require an env value. llama.cpp ignores it. Putting a cloud key here by habit is how secrets leak into an interactive container env. Real auth lives nowhere useful until you put a gateway in front. |
| `LLAMA_BASE_URL` | `http://host.docker.internal:8080/v1` | Convenience URL for docs and smoke helpers only. The agent runtime reads `config/models.json`, not this variable, for the live provider. If smoke works but pi fails, you drifted `models.json`. `host.docker.internal` needs the compose `extra_hosts` / host-gateway setup on Linux. |

## `config/models.json`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `providers.llamacpp.baseUrl` | `http://host.docker.internal:8080/v1` | Actual base URL the pi agent uses to reach llama.cpp. Must be reachable from inside the agent container, not from your laptop browser mental model. If llama is only on `llm-backend` and not published, this host-gateway path is required. Wrong URL looks like "provider down" while Open WebUI still works via DNS. |
| `providers.llamacpp.api` | `openai-completions` | Selects the OpenAI chat/completions-compatible API mode in pi. llama.cpp's server speaks this dialect when started as in the llama-cpp stack. Other api modes expect different request shapes and will 404 or 400 confusingly. Leave unless pi docs say your build needs another mode. |
| `providers.llamacpp.apiKey` | `local` | Dummy API key field in the provider block. Same story as `OPENAI_API_KEY` — required by client shape, ignored by llama. Do not paste cloud credentials into `models.json` checked into a repo. If the file is mounted writable, treat it as sensitive anyway because of future gateway keys. |
| `compat.supportsUsageInStreaming` | `false` | Compatibility flag: llama.cpp streaming often lacks usage payloads the way OpenAI sends them. Leaving `true` makes pi mis-parse streams or error on chunk handling. Flip only after verifying your llama build emits usage in stream. This is a footgun when copying configs from cloud providers. |
| `compat.maxTokensField` | `max_tokens` | Wire name for the max-tokens parameter in requests. OpenAI-compat llama expects `max_tokens`; other stacks use `max_completion_tokens` etc. Wrong field means your `maxTokens` model setting is silently ignored and outputs run long. Keep aligned with llama.cpp server expectations. |
| `models[0].id` | `local-coder` | Model id exposed inside pi (`/model` → `llamacpp/local-coder`). Cosmetic to llama if the server only has one loaded GGUF, but pi uses it for selection UX. Drift between this id and smoke docs confuses future you. Add more entries only if you actually multi-model through a router. |
| `models[0].contextWindow` | `8192` | Context window pi believes the model has. Match llama `CTX_SIZE` or the agent will overfill prompts. Undersizing wastes model capacity; oversizing causes server-side context errors mid-tool-loop. Revisit when you change `MODEL_FILE` / ctx on llama. |
| `models[0].maxTokens` | `2048` | Max generation tokens per response pi will request. Caps runaway completions and keeps tool loops from eating the whole context. Too low truncates code edits mid-file; too high plus large context risks OOM or slow turns. Separate from `contextWindow` — do not treat them as the same knob. |

runs as root inside → host-mounted files may end up root-owned.
