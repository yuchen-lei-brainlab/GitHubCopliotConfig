# Copilot Custom Instructions

## Project Context
- Medical imaging application (Brainlab ImageFusion) written in C++ compiled with **C++20** (MSVC, `bm2022` toolset).
- Mixed stack: C++ plugins/logic, React/TypeScript UI (`.tsx`), XML resource files, MSBuild `.vcxproj` projects.
- Third-party code lives under `third_party/` (CEF, gtest) — do not modify it.

## General Rules
- Make the minimal change required; do not refactor unrelated code.
- Follow the conventions already present in the file being edited over generic style guides.
- Do not invent file paths — verify with workspace tools first.
- Never duplicate third-party or generated code into project sources.

## C++ Style
- Header guards: `#if _MSC_VER > 1000` / `#pragma once` followed by an include guard named `<MODULE>_<FILENAME>_H`.
- Keep the Brainlab file header banner (`@file`, copyright line) intact and add it to new files.
- Namespaces are lower-case and short (e.g. `scvolume`, `scene`, `imagefusion`, `fusionlogic`); closing brace commented `} // namespace x`.
- Indentation: 2 spaces, opening braces on their own line (Allman).
- Class members are prefixed with an underscore (`_instructions`, `_mainWindow`).
- Doc comments use `//!` for single-line and `/** ... */` blocks with `@author` / `@param` where the file already does.
- Prefer `= default` / `= delete` for special member functions; mark overrides with `override`.
- Prefer `std::unique_ptr` for ownership; return raw pointers only for non-owning access.
- Use C++20 features (concepts, ranges, `std::span`, designated initializers) only when they fit existing patterns and compile with MSVC.
- Include paths are project-relative, e.g. `#include "SceneVolumes/include/ProcessInstruction.h"`.
- Use `assert` for programming errors and the existing `blog::LogStream` logging for runtime errors.

## Resources / Localization
- User-facing strings must be added as `reslib:RESOURCE` entries in `Res/en/Resources_en.xml`, never hardcoded in code.
- Resource ids follow `imagefusion_text_<CamelCaseName>`; keep entries grouped under the existing section comment banners.
- Use `${placeholder}` tokens for runtime substitution.

## TypeScript / React UI
- Functional components with hooks, typed props/interfaces, no `any`.
- Keep UI text sourced from resources rather than literals.

## Testing
- Use gtest; place tests next to existing test projects and follow their naming.
- Add or update tests when changing logic behavior.

## Validation
- Build affected projects and resolve all compiler warnings/errors introduced by the change.
