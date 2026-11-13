---
name: deep-research
description: Multi-source research method with citations, source quality ranking and explicit confidence levels. Use when a question needs evidence from several sources, when comparing options or technologies, or when claims must be verified rather than recalled.
tags: [research, web]
---

# Deep research

Goal: an answer a reader can trust and check. Separate what is established from what is inferred.

## 1. Frame the question
- Restate it in one or two sentences, with scope, time frame and the decision it supports.
- List sub-questions. Note what would change the answer.
- Define success: for example "recommend one of three options with trade-offs" or "confirm whether feature X exists in version Y".

## 2. Plan sources
Rank by reliability for the question:
1. Primary: official documentation, specifications, source code, release notes, changelogs, standards, the vendor's issue tracker.
2. Reproducible evidence: your own run of code, benchmark or query in the project (record exact commands).
3. Reputable secondary: maintained books, peer-reviewed papers, established engineering blogs by the authors or maintainers.
4. Weak: forum answers, social posts, undated tutorials, AI-generated summaries. Use as leads only, then confirm with a primary source.
Prefer sources that are recent for fast-moving topics; check the version a source describes against the version in use.

## 3. Gather
- Read the primary sources directly; do not rely on search snippets.
- Use at least two independent sources for any claim that matters. Sources that copy each other count as one.
- Record for each: title, author or organisation, URL, publication or access date, version covered, and the relevant quote or paraphrase.
- Search for disconfirming evidence on purpose: known issues, criticisms, "X vs Y" counter-arguments.
- Stay within the guardrails: send no confidential code, data or secrets into search queries or external services.

## 4. Evaluate
- Check dates, versions, conflicts of interest and whether the source tested what it claims.
- Where sources disagree, say so, explain the likely reason (version, context, definition) and state which you trust more and why.
- Distinguish: fact (stated by a primary source), inference (your reasoning from facts), opinion (someone's judgement), unknown.
- Test claims that can be tested locally instead of trusting them.

## 5. Confidence levels
| Level | Meaning |
|---|---|
| High | Multiple independent reliable sources agree, or verified by running it; no credible contradiction |
| Medium | One strong source, or several weaker ones agreeing; some gaps |
| Low | Weak, dated or conflicting sources; extrapolation |
| Unknown | Not found after stated searches |

Never present a Low or Unknown finding as settled. Never invent a citation, URL, version or quote; if you cannot find a source, say so.

## 6. Report format
```
Question: <restated>
Answer (short): <2-4 sentences, with overall confidence>
Findings:
1. <claim> - confidence: High|Medium|Low - sources: [1], [2]
Trade-offs / options: <table when comparing>
Disagreements and caveats: <what conflicts, what is dated>
Not found / not checked: <gaps>
Recommendation: <what to do, and what to verify next>
Sources:
[1] Title - author/org - URL - date accessed - version
```

## Tips
- Keep notes while searching so the citations are exact.
- Prefer a short, well-supported answer over a long survey.
- Time-box the work; report what is known when the budget ends, plus what you would check next.
- Mark dates relative to now with absolute dates in the report.
