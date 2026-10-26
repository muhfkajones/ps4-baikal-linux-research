# Claude project instructions

Read and follow `AGENTS.md` before doing any project work. Its resume protocol,
fixed hardware facts, safety rules, and data policy are mandatory.

At the beginning of every session:

1. Inspect `git status --short --branch` and preserve every pre-existing change.
2. Read `README.md`, `docs/STATUS.md`, `docs/EXPERIMENTS.md`,
   `docs/DATA_POLICY.md`, `docs/REPRODUCIBILITY.md`, and
   `docs/KNOWLEDGE-CONTINUITY.md`.
3. If the local LLM Wiki MCP server is available, use it only for read-only
   retrieval. Verify important claims against current repository files.
4. State the verified boundary, closed experiments, current blocker, and next
   safe experiment. Do not ask the operator to repeat facts already recorded.

Operational rules:

- The reference console is a PS4 Pro CUH-7215B on firmware 13.50 with Baikal
  B1 southbridge (`0x30201`). Never recommend or initiate a firmware update.
- The verified Linux path is external USB boot after the volatile HEN and
  Linux-loader path. A permanent cold-boot replacement is the research goal,
  not an established capability.
- Distinguish verified evidence, direct observation, hypothesis, and proposal.
- Do not repeat a closed experiment without new evidence and a written reason.
- Audit payload source, build inputs, hashes, and write behavior before any
  console execution.
- Do not execute unknown payloads, write console flash, alter the boot chain,
  or run a brick-risk experiment without a reviewed recovery design and the
  operator's explicit approval for that exact experiment.
- Never commit, publish, or index Sony binaries, raw or decrypted dumps,
  SFLASH data, keys, credentials, console identifiers, personal paths, or the
  sibling `ps4-flash-acquisition` workspace.
- For physical console or UI actions, give one exact action and its expected
  visible result. For repository work, continue autonomously through safe
  inspection, implementation, verification, documentation, and a narrowly
  scoped commit.
- Be direct. Do not restate the operator's last sentence as an answer, invent
  URLs or commands, or send the operator through a completed step again.

LLM Wiki is a derived local index, not the source of truth. Keep its API bound
to `127.0.0.1`, token-protected, with LAN access, unauthenticated access, and
external information sources disabled. Do not reveal or store its token in Git.

