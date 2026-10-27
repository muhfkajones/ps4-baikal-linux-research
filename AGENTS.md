# PS4 Baikal Linux Research instructions

## Resume protocol

Before proposing or changing anything:

1. Run `git status --short --branch` and preserve all pre-existing work.
2. Read `docs/STATUS.md`, `docs/EXPERIMENTS.md`, `docs/DATA_POLICY.md`, `docs/REPRODUCIBILITY.md`, and `README.md`.
3. Treat those files and the current working tree as authoritative. LLM Wiki is a read-only search aid.
4. Summarize the verified boundary, closed experiments, current blocker, and next safe experiment. Do not ask the user to repeat recorded facts.

## Local continuity tool

- When the user says **Tauri app** or a window is titled **Tauri App**, they mean the local **LLM Wiki v0.6.13** application used by this project.
- Launch it from `../tools/llm-wiki/0.6.13/LLM Wiki.exe`; its loopback API is `http://127.0.0.1:19828`.
- Select only the Baikal research wiki at `../llm-wiki-data/ps4-baikal-linux-research/` (project ID `a59a1712-131a-497a-a342-ef13879f96fe`).
- Do not ask the user for the app name or location again. If the app or API is unavailable, continue from the Git-tracked state documents and report that specific problem.
- Claude has a separate wiki database outside this project. Never select, search, modify, or merge that database during Baikal/Codex work.

## Fixed reference system

- Console: PS4 Pro CUH-7215B
- Firmware: 13.50; never recommend or initiate a firmware update
- Southbridge: Baikal B1 (`0x30201`)
- Verified Linux path: external USB after the volatile HEN and Linux-loader path
- Project goal: investigate a reproducible cold-boot Linux path; no permanent replacement is currently verified

## Operator handoff rule

- Continue all safe digital research, coding, auditing, documentation, GitHub, and read-only Wiki work without handing a pause back to the user.
- Stop only when the user must physically operate hardware, provide missing authority for a gated action, or make a material experiment choice that cannot safely be inferred.
- Before stopping, exhaust independent digital work and state the single physical action or exact authorization needed.

## Research and safety rules

- Label every claim as verified evidence, observation, hypothesis, or proposal when the distinction matters.
- Do not repeat a closed experiment without new evidence and a written reason.
- Audit payload source, build inputs, hashes, and write behavior before hardware execution.
- Do not execute unknown payloads, write console flash, alter the boot chain, or perform a brick-risk experiment without an independently reviewed recovery design and the user's explicit approval for that exact experiment.
- Never commit or index Sony binaries, raw/decrypted dumps, SFLASH data, keys, credentials, console-unique identifiers, or personal filesystem paths. Follow `docs/DATA_POLICY.md`.
- Keep private acquisition material in the sibling `ps4-flash-acquisition` workspace out of Git and out of LLM Wiki.
- Record materially verified results in `docs/STATUS.md` and `docs/EXPERIMENTS.md`; update hashes/provenance where applicable.
- Give the user one concrete operating step at a time for console/UI actions, including the expected visible result.
