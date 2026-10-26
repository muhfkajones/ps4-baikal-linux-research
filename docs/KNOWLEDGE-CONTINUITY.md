# Durable project context with LLM Wiki

This project uses Git-tracked documentation as the source of truth and may use [LLM Wiki](https://github.com/nashsu/llm_wiki) as a local, derived search index. The index exists to let a new Codex session recover verified state without requiring the operator to repeat the history.

## Trust boundary

- Repository files and the current working tree are authoritative.
- LLM Wiki is retrieval-only for Codex. Its generated summaries are not evidence.
- Important retrieved claims must be checked against the current repository file.
- The LLM Wiki API must bind to `127.0.0.1`, require an API token, and keep LAN access and unauthenticated access disabled.
- External web search and Deep Research remain disabled for this project index.
- Use a local Ollama model and local embeddings so indexed material stays on the workstation.

## Sources allowed into the index

The export script copies only already tracked, text-based project evidence:

- root policy and overview Markdown files
- `docs/**/*.md`
- `manifests/**/*.json`
- `payloads/**/README.md` and `payloads/**/AUDIT.md`

It intentionally excludes binaries, build output, Git internals, untracked files, and every sibling directory. In particular, never add `../ps4-flash-acquisition`, dumps, decrypted binaries, keys, identifiers, credentials, or personal filesystem records as a source.

## Local layout

- Application: `../tools/llm-wiki/0.6.13/`
- Wiki data: `../llm-wiki-data/ps4-baikal-linux-research/`
- Export target: `../llm-wiki-data/ps4-baikal-linux-research/raw/sources/repository/`

Keeping wiki data outside this public repository prevents generated pages and local configuration from being committed accidentally.

## Refresh the safe source mirror

From the repository root:

```powershell
.\scripts\Export-LlmWikiSources.ps1
```

The script overwrites current allowlisted files but does not delete destination files. Review `SOURCE-MANIFEST.json` after each run. If a previously exported source is removed from Git, remove its stale mirror manually after verifying the exact destination path.

## Codex MCP policy

Expose only these LLM Wiki tools to Codex:

- `llm_wiki_status`
- `llm_wiki_projects`
- `llm_wiki_set_project`
- `llm_wiki_files`
- `llm_wiki_read_file`
- `llm_wiki_reviews`
- `llm_wiki_search`
- `llm_wiki_graph`

Do not expose `llm_wiki_chat`, `llm_wiki_rescan_sources`, `llm_wiki_embed_page`, or `llm_wiki_write_page`. Source refreshes should be deliberate and reproducible through the repository export script.

## Session startup

A new session should:

1. Read the global and project `AGENTS.md` files.
2. Inspect Git status without changing it.
3. Read `docs/STATUS.md`, `docs/EXPERIMENTS.md`, and the data/reproducibility policies.
4. Query the read-only LLM Wiki project when available.
5. Continue from the verified boundary instead of replaying completed steps.

## Version and license

The reviewed integration targets LLM Wiki `v0.6.13`, portable Windows x64 release SHA-256 `84700195ce6bb0a683a96a55e670349b47cf235cf8e55c571a1eaf8443a00dc2`. LLM Wiki is licensed under GPL-3.0; it is a separate local tool and is not vendored into this repository.
