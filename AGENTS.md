# Shared Agent Instructions

This repository is maintained with both Codex and Claude.

## Instruction synchronization

- `AGENTS.md` and `CLAUDE.md` are mirrors and must remain byte-for-byte identical.
- Any change to shared agent instructions must update both files in the same commit.
- Before finishing an instruction change, run `cmp -s AGENTS.md CLAUDE.md` and resolve any difference.
- Do not add tool-specific project rules to only one file. Write rules that both agents can follow.

## Collaboration

- Treat existing files and uncommitted changes as shared work.
- Inspect `git status` before and after making changes.
- Never discard, overwrite, or reformat unrelated changes made by the user or another agent.
- Keep each change focused and commit only files that belong to the active task.
- If the working tree changes unexpectedly, inspect the new state before continuing.
- Update `README.md` when project structure, requirements, commands, or platform status changes.

## Project structure

- `ios/` contains the native SwiftUI application and Xcode project.
- `android/` contains the native Kotlin and Jetpack Compose application.
- Keep platform source code isolated. Share behavior through documented requirements, data formats, and tests rather than cross-platform source coupling unless the user explicitly chooses a shared-code architecture.
- Do not commit generated build output, IDE state, local SDK paths, signing material, or secrets.

## Verification

- For iOS changes, build the `Swifty` scheme from `ios/Swifty.xcodeproj` when the environment supports Xcode.
- For Android changes, run `cd android && ./gradlew :app:assembleDebug`.
- For documentation-only changes, verify links, paths, commands, and the synchronization of these two instruction files.
- Report any verification that could not be performed.

## Commit messages

Use exactly this format:

```text
Type: Korean summary
```

Allowed types:

- `Fix`: Correct a defect or regression.
- `Feat`: Add or extend user-facing functionality.
- `Chore`: Handle maintenance, tooling, dependencies, or repository setup.
- `Refactor`: Restructure code without changing intended behavior.
- `Docs`: Change documentation only.

Rules:

- Use the exact capitalization shown above. Do not use lowercase types or unlisted types.
- Write the summary in concise Korean and keep the message on one line.
- Describe the concrete result of the commit and omit a trailing period.
- Keep unrelated changes in separate commits.

Examples:

```text
Fix: 도보 페이스 수치 튐 수정
Feat: 안드로이드 계기판 화면 추가
Chore: Android 빌드 환경 구성
Refactor: 위치 추적 상태 관리 분리
Docs: 프로젝트 실행 방법 추가
```
