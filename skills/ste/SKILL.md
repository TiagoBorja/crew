---
name: ste
description: House rules for Simplified Technical English (STE). Use when writing or reviewing docs, comments, commits, PR text or reports the project wants in STE.
tags: [writing, docs]
---

# Simplified Technical English (STE)

These are crew's house rules. These rules follow the ideas of ASD-STE100. They are not the official dictionary.

## Rules
1. Keep sentences short. Aim for 20 words or less. Use 25 words at most for a description.
2. Write one instruction in each sentence.
3. Use the active voice. Write "The tool writes the file", not "The file is written".
4. Use the imperative for steps. Write "Run the test".
5. Use the present tense.
6. Use simple, common words: use, start, check. Do not use utilise, commence, verify.
7. Use one term for one thing. Do not use synonyms for the same thing.
8. Do not use idioms or phrasal verbs. Write "start", not "kick off".
9. Do not stack more than 3 nouns. Break a longer stack into a phrase.
10. Keep the articles (a, the).
11. Write numbers and units the same way every time. Write "5 MB", not "5 megabytes" in one place.
12. Write steps as a numbered list.
13. Put a warning before the step it applies to.
14. Keep code and identifiers unchanged. Do not translate or reword them.

## Before and after
| Before | After |
|---|---|
| Utilise the flag to commence the build. | Use the flag to start the build. |
| The config file is parsed by the loader. | The loader reads the config file. |
| We need to kick off the job and then wait for it to wrap up. | Start the job. Wait for the job to finish. |
| Check the user session token expiry timeout value. | Check when the session token expires. |
| Verify the file exists, copy it, and restart the service. | 1. Check that the file exists.<br>2. Copy the file.<br>3. Restart the service. |
| Backup the data, then delete the old files (this cannot be undone). | WARNING: You cannot undo a delete.<br>1. Back up the data.<br>2. Delete the old files. |
| The timeout should be set to 30 seconds if the connection is slow. | If the connection is slow, set the timeout to 30 s. |

## Review checklist
- Is each sentence 20 words or less (25 for a description)?
- Does each sentence hold one instruction?
- Are all verbs active and in the present tense?
- Does each term mean one thing, and does each thing have one term?
- Are there idioms, phrasal verbs or long noun stacks?
- Are steps numbered, and do warnings come first?
- Are code, paths and identifiers unchanged?

## When not to use
- Quoted text: keep the original words.
- Code, commands and log output.
- Legal text.
- Strings supplied by a user.
- Text in other human languages.
