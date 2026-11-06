# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Instead, report them privately through GitHub's
[security advisory form](https://github.com/himanshu240601/Pickel/security/advisories/new).

You can expect a reply within a few days.

## Built-in protections

- Only `http`, `https` and `file` URLs are loaded.
- Downloads larger than 50 MB are rejected (configurable via `ImageDownloader(maximumDataSize:)`).
- Images are never decoded larger than 24 megapixels, which protects against decompression bombs.
- Data that fails to decode is never written to the disk cache.
