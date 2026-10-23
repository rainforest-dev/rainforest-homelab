# library-hall

Runs the library hall, the 3D hall at `/` of `library.rainforest.tools`. It keeps no data: the page is static, and `/api/items` gathers every collection's hall items server-side.

`collection_urls` gives each collection as the container reaches it, base path included (`books = "http://host.docker.internal:8082/books"`); each becomes `LIBRARY_<NAME>_URL`, and the hall reads `<url>/api/hall-items` with a 5 s timeout. A collection with no URL is left off the shelves, and one that is down is named on the page while the others still load.

`vault_system_path` is the vault's `_system` folder, mounted read-only at `/vault-system`. The hall reads `Topic-Map.md` there (`LIBRARY_TOPIC_MAP`) and renames each item's topics through it, so a book, an article, a wiki page and a notebook on one subject share a bookcase. It reads the file again whenever it changes, so an edit in Obsidian shows on the next load without a restart. The folder is mounted rather than the file because Obsidian and iCloud save by replacing the file, which a single-file bind mount would not follow. Empty, nothing is mounted and every collection's topics stay as they are.
