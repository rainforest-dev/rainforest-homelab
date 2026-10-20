# personal-notebook

Runs the personal-notebook app (Bullet Journal notebooks at `/notebooks`) with its DB, page images and search index in one Docker volume at `/data`.

With `import_volume` set to personal-calibre's app-data volume, the volume is mounted read-only and the app copies calibre's notebooks on its first start with an empty `/data`. `ollama_url` serves page search embeddings and OCR; `ocr_model` becomes `NOTEBOOK_OCR_MODEL` only when non-empty.
