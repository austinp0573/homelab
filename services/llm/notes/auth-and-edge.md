# auth and edge

The normal setup is authenticated Open WebUI on the LAN. llama.cpp, Qdrant, embeddings, and Whisper stay on loopback or the internal container network.

## Open WebUI

- `WEBUI_AUTH=True`
- create the first admin account
- set `ENABLE_SIGNUP=False` after that
- set a real `WEBUI_SECRET_KEY`

The default bind is `127.0.0.1`. If Open WebUI needs LAN access, set the bind address to the host LAN address and only allow the intended subnet through the firewall.

## APIs

Do not publish llama.cpp, Qdrant, the embedding service, or Whisper to the LAN unless there is a client that requires it.

The `local` API key only satisfies client configuration. It is not server authentication.

## remote access

For headscale and HAProxy, keep the service on the LAN or tailnet. HAProxy terminates TLS and forwards to the GPU box.

Do not put llama.cpp, Qdrant, or Whisper directly on the public internet.
