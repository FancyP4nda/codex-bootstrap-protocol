# Technical Writer Templates

## Wiki Page

```markdown
# Page Title

## Overview
[Brief summary grounded in source files.]

## Details
[Evidence-backed explanation with file references.]

## Related Material
- [Link to adjacent docs]
```

## Onboarding Guide

```markdown
# Getting Started

## Prerequisites
- [Tool or dependency]

## First Run
1. [Exact command]
2. [Validation step]

## Key Concepts
- [High-signal architecture note]
```

## Changelog Entry

For `CHANGELOG.md` and release notes. Never write `docs/changelog.yaml`: `$session-wrapup` owns it (SKILL.md Mode C). Order sections as below and omit empty ones.

```markdown
## [version] - YYYY-MM-DD

### Breaking Changes
- [Change]

### Features
- [Change]

### Fixes
- [Change]

### Other Changes
- [Change]
```
