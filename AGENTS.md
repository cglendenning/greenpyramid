# Implement from the private specification

The authoritative build contract lives in `~/greenpyramid-spec`. Keep its product requirements and contract resources in that private repository.

1. Read its `SPEC_INDEX.md`, then run `python3 ~/greenpyramid-spec/spec_tools.py brief D-###` for the relevant directive. Read only the sections and named contracts needed for the task.
2. Assess prerequisite directives and owner hints. Requirements define the target; unverified status does not establish what the code implements. Resolve specification conflicts before inventing behavior.
3. Implement and verify the stable acceptance IDs. Record actual passing tests or manual review in the private `implementation_evidence.json`; ID mentions and structural checks alone do not establish compliance.
4. When requirements change, update their authored sources in the same task. From the private repository run `python3 spec_tools.py generate`, `python3 spec_tools.py validate --app-root ../greenpyramid`, and `python3 -m unittest discover -s tests`.

The private `README.md` explains contract authority, runtime guards and evidence. Never reuse or renumber directive/acceptance IDs. Never commit secrets or print `lib/services/secrets.dart`.
