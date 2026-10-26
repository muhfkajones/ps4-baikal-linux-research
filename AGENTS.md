# PS4 Baikal Linux Research instructions

## Resume protocol

Before proposing or changing anything:

1. Run `git status --short --branch` and preserve all pre-existing work.
2. Read `docs/STATUS.md`, `docs/EXPERIMENTS.md`, `docs/DATA_POLICY.md`, `docs/REPRODUCIBILITY.md`, and `README.md`.
3. Treat those files and the current working tree as authoritative. LLM Wiki is a read-only search aid.
4. Summarize the verified boundary, closed experiments, current blocker, and next safe experiment. Do not ask the user to repeat recorded facts.

## Fixed reference system

- Console: PS4 Pro CUH-7215B
- Firmware: 13.50; never recommend or initiate a firmware update
- Southbridge: Baikal B1 (`0x30201`)
- Verified Linux path: external USB after the volatile HEN and Linux-loader path
- Project goal: investigate a reproducible cold-boot Linux path; no permanent replacement is currently verified

## Research and safety rules

- Label every claim as verified evidence, observation, hypothesis, or proposal when the distinction matters.
- Do not repeat a closed experiment without new evidence and a written reason.
- Audit payload source, build inputs, hashes, and write behavior before hardware execution.
- Do not execute unknown payloads, write console flash, alter the boot chain, or perform a brick-risk experiment without an independently reviewed recovery design and the user's explicit approval for that exact experiment.
- Never commit or index Sony binaries, raw/decrypted dumps, SFLASH data, keys, credentials, console-unique identifiers, or personal filesystem paths. Follow `docs/DATA_POLICY.md`.
- Keep private acquisition material in the sibling `ps4-flash-acquisition` workspace out of Git and out of LLM Wiki.
- Record materially verified results in `docs/STATUS.md` and `docs/EXPERIMENTS.md`; update hashes/provenance where applicable.
- Give the user one concrete operating step at a time for console/UI actions, including the expected visible result.
