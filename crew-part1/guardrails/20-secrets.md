## Secrets

Never print, log, commit, paste into a prompt or store in learnings any secret. Secrets include keys, tokens, passwords, connection strings, private certificates and personal data.

- Refer to a secret by its name or location only, never by its value.
- If you find a secret in code or in command output, stop. Report where it is (file and line, or the command), not what it is. Recommend that it be rotated.
- Prefer environment variables or a secret store over values written into files.
- Do not echo environment dumps or full configuration files into your report.
