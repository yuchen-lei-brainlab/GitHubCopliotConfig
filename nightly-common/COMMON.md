# Shared Nightly Guidance

- Confirm `p4 login -s` before running checks. Run long checks in a new Developer PowerShell window with the user profile loaded.
- Clang-tidy needs Windows Python (`C:\Program Files\Python313\python.exe`); IWYU needs the profile's default Cygwin Python.
- Preserve justified existing analyzer suppressions and the code they protect; do not remove them or change an API solely to appease another analyzer. For example, retain a reference-returning thread-local generator and its `//lint !e1929` annotation rather than returning a pointer, and keep a macro's `//lint !e750` annotation when it is used by third-party headers.
- Preserve explicit lambda captures when they are intentional; replacing `[this, &event, count]` with `[&]` can introduce lint findings. Keep established `CHKSTD_OK` test-header comments unchanged unless a finding actually requires changing them.
- If modified tests belong to a separate test package, run its lint independently in a new Developer PowerShell window; linting the parent package may not include test sources. Review numbered findings and exit status, and report any failed tool or build as a blocker.
- Doxygen can print progress through stderr as `NativeCommandError`; distinguish this from actual warnings or errors. IWYU include changes must be followed by a lint or normal build to confirm they compile.
- Doxygen warnings usually mean missing or incorrect `@param`, `@return` or `@brief` comments.
