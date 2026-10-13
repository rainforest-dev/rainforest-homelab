# personal-calibre

Runs the personal-calibre app against the read-only Calibre library, with its own app DB in a Docker volume.

Semantic search embeds through Ollama. `ollama_url` (default `http://host.docker.internal:11434`, the host's Ollama as seen from the container) becomes `CALIBRE_OLLAMA_URL`. `embed_model` becomes `CALIBRE_EMBED_MODEL` only when it is non-empty, so the default `""` leaves the app on its own default model.
