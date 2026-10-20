# library-hall

Runs the library hall, the 3D hall at `/` of `library.rainforest.tools`. It keeps no data: the page is static, and `/api/items` gathers every collection's hall items server-side.

`collection_urls` gives each collection as the container reaches it, base path included (`books = "http://host.docker.internal:8082/books"`); each becomes `LIBRARY_<NAME>_URL`, and the hall reads `<url>/api/hall-items` with a 5 s timeout. A collection with no URL is left off the shelves, and one that is down is named on the page while the others still load.
