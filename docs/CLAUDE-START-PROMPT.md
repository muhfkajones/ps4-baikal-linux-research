# Claude start prompt

Copy the prompt below into a new Claude or Claude Code session opened at this
repository. The repository's `CLAUDE.md` and `AGENTS.md` remain the persistent
instructions; this prompt tells a fresh session exactly how to resume.

```text
Continue the PS4 Baikal Linux research project from the repository on Beast at:
C:\Users\dwall\Documents\ChatGPT\server\ps4-baikal-linux-research

Do not start from conversation history or ask me to repeat completed work.
First read CLAUDE.md and AGENTS.md completely, then inspect the current Git
working tree without changing it. Read README.md, docs/STATUS.md,
docs/EXPERIMENTS.md, docs/DATA_POLICY.md, docs/REPRODUCIBILITY.md, and
docs/KNOWLEDGE-CONTINUITY.md. Treat the repository and current working tree as
authoritative.

If the local LLM Wiki MCP server is available, use it only as a read-only
retrieval aid. Select the ps4-baikal-linux-research project, search it for the
current blocker and prior experiments, and verify every important retrieved
claim against current repository files. Do not use wiki write, chat, rescan, or
embedding tools. Do not reveal or store the LLM_WIKI_API_TOKEN.

Preserve all pre-existing modified and untracked files. Never index, commit, or
publish Sony binaries, raw or decrypted dumps, SFLASH data, keys, credentials,
console-unique identifiers, personal filesystem records, or anything under the
sibling ps4-flash-acquisition workspace.

Fixed reference facts:
- PS4 Pro CUH-7215B
- firmware 13.50; never update it
- Baikal B1 southbridge (0x30201)
- verified Linux path: external USB after volatile HEN plus the Linux loader
- goal: a reproducible permanent/cold-boot Linux path, which is not yet proven

Before proposing work, report the verified boundary, experiments already
closed, the current blocker, and the next safe experiment. Separate verified
evidence, direct observation, hypothesis, and proposal. Do not repeat a closed
experiment without new evidence and a written reason. Audit payload source,
build inputs, hashes, and write behavior before console execution. Do not write
flash, alter the boot chain, run unknown payloads, or attempt a brick-risk step
without a reviewed recovery design and my explicit approval for that exact
experiment.

For safe repository work, proceed autonomously through inspection,
implementation, verification, documentation, and a narrowly scoped commit.
For a physical PS4 or UI action, give me one exact action and the expected
visible result. Be direct; do not merely repeat what I said, invent URLs or
commands, or send me through steps already recorded as completed.
```

