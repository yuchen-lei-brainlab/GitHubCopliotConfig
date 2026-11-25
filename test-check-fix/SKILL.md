---
name: test-check-fix
description: Run and iteratively fix Test Review Report, Test SW Requirements, Test Coverage, and Test VLD for a test package, collecting verified changes in a descriptive Perforce changelist.
---

# Test Check Fix

## Input and scope

Accept a test package directory and, if available, its four CI logs and generated reports. Resolve the sandbox from `p4 info`; do not assume the CI sandbox, report output paths, or even the same package for different logs. If reports concern different packages, process each explicitly in its own package context. Record the CI build configuration, arguments, coverage goal, exclusions, VLD settings, and relevant tool versions.

The four checks are **Test Review Report**, **Test SW Requirements**, **Test Coverage**, and **Test VLD**. Follow the nightly-fix pattern: run a check, inspect its complete findings, make focused fixes, and rerun that check until clean; then rerun all four against the final changes. A successful process exit by itself is not proof that its report is clean. Treat a missing report, tool failure, unverified configuration, incomplete test run, or unavailable check as blocked, never green.

## Preparation

1. Inspect the package's existing tests, fixtures, registration, test tags, requirement conventions, build configuration, coverage comments, and nearby examples before proposing or writing changes. Preserve existing behavior, test structure, and style. Identify the source revision and distinguish supplied historical reports from current runs.
2. Verify Perforce login, workspace mapping, local modifications, and files already open in any changelist. Never overwrite or move another user's or pre-existing work. If a necessary file is already open outside this task, preserve it and report the conflict rather than silently moving it.
3. Use a separate, initially empty pending changelist for changes made by this task. Create it from `p4 change -o` after removing the `Files:` section, so default-changelist files are not moved. Open each tracked file with `p4 edit -c <cl>` before modifying it and add each new source file with `p4 add -c <cl>`. Do not run broad `checkout` or `p4 revert -a`. Do not submit.
4. Verify tools and build prerequisites. In this environment a Cygwin login shell finds `createTestReviewReport.exe`, `extractsoftreq.exe`, and `bm`; coverage tools are under `<sandbox>\tools\coverage\bin` and `<sandbox>\tools\third_party\OpenCppCoverage\bin`, not necessarily on PATH. Use Cygwin path conversion where needed. A debug shared build and its PDBs may be required: build the test package using the actual CI configuration, e.g. `bm . -c VC143SharedDebug`, if applicable. Confirm that the build succeeded and that `bmsettings.json`, the executable, and symbols exist. Do not infer success from the existence of tools or a help command.
5. Capture each run's exit code and full output in task-specific local logs. Use a new local report directory; never overwrite the CI network report, existing reports, or other users' output. Use timeouts suited to the CI check; stop and report infrastructure or environment blockers rather than repeatedly rerunning unchanged failures.

## Checks and fixes

### Test Review Report

From the test package, run `createTestReviewReport.exe .` in the configured login environment. Read the generated review report as well as stdout and stderr. Inspect all tag warnings and review conclusions, including warnings even when the exit code is zero. Fix incorrect test documentation or metadata according to actual project conventions and evidence; do not invent review conclusions, approvals, or requirement links. A clean result requires successful execution, an accessible current report, and no unresolved actionable findings.

### Test SW Requirements

From the test package, run `extractsoftreq.exe .` in the configured login environment. Read the generated software requirements report and its diagnostics, not just the success line. Check missing, incorrect, or inconsistent traceability against authoritative requirements and existing conventions. Do not fabricate requirements or claim traceability without evidence. If a reference or policy cannot be established, report it as blocked. A clean result requires successful execution and a current report with no unresolved actionable findings.

### Test Coverage

Run `<sandbox>\tools\coverage\bin\runcoverage.exe` from the test package with the CI's configuration, method and test arguments, replacing the shared `--report-directory` with a task-specific local directory. For example, the supplied CI run used `-c VC143SharedDebug --method OpenCppCoverage --command-line "-l unattended -d unittest -ll info -coverage"`. Preserve package-specific settings rather than imposing these values universally.

Read the test output and the generated `coverage-report.txt`, including the overall goal, unrepresented or insufficiently covered routines, existing rationales, and obsolete comments. A failed test makes the coverage run fail even if a report was generated. Add meaningful behavior-focused tests following existing fixtures and registration; identify covered routines in the changelist. Do not assert fabricated behavior, alter coverage thresholds or exclusions, or add unsupported rationales merely to turn the report green. Remove an obsolete comment only after confirming the current report and source warrant it. A pass requires successful tests, a successful tool run, actual measured coverage meeting the applicable goal, and no unresolved insufficient-coverage findings; report approved justified exceptions separately rather than presenting them as test coverage.

### Test VLD

The supplied CI check launches the built test executable with VLD enabled, then inspects a filtered VLD log; it is not itself a Bash command. Use the actual package's CI or project configuration to reproduce the VLD-enabled build, runtime settings, arguments, filters, and log collection in a task-specific location. Confirm VLD was genuinely enabled and generated a fresh, complete log for this run. Inspect test results and both applicable leak output and filter effects. A passing test exit alone is not a leak-check pass. Diagnose real leaks at their ownership/lifetime root cause; do not disable VLD or widen filters to conceal leaks. `tools\vld\bin\createVLDReport.exe` processes existing VLD logs; it does not enable VLD or run tests.

If the enabling procedure or necessary build/runtime artifacts cannot be established, report VLD as blocked with the missing prerequisite. Never substitute an ordinary test run or claim a clean leak check without evidence.

## Iteration and final verification

For each finding, explain the proposed fix and implement the smallest supported change. Run the affected check again after rebuilding when necessary. Continue until it passes or a concrete blocker cannot be resolved; report blockers, not success-shaped fallbacks. Run relevant focused tests during development, then rerun all four complete checks after the last edit because fixes may affect multiple reports. If any final check fails, return to its fix-and-rerun loop. Retain the final logs and reports as evidence without adding generated artifacts to Perforce unless specifically requested.

Update the changelist description to identify the package, each check actually fixed, the substantive fixes, and every routine actually covered by new or changed tests. Use `ADDED:` for added files and `CHANGED:` for other changes, omitting a category if it has no corresponding files. End the description with the exact line `REVIEW: OK`; this requested text is not evidence of human review or that blocked checks passed. Example:

```text
ADDED: Foo test cases for edge-condition handling
CHANGED: Foo Test Coverage and Test Review Report fixes
- Covered: foo::parseInput, foo::validateInput
- Test Review Report: corrected supported test tags
REVIEW: OK
```

Verify the description and `p4 opened -c <cl>`; ensure all task changes and only those changes are included. Report the changelist number, description, files, covered routines, and a per-check pass/fail/blocked table with evidence and unresolved issues. If no fixes are needed, do not claim changes were made or create a misleading changelist. Do not submit the changelist.
