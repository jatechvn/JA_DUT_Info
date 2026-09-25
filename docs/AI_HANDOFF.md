# Boot/reboot fix — 2026-09-24

Boot acquisition now requires a successful BootGate result. Timeout leaves the
monitor in BOOTING and the next device poll retries, even if boot subsequently
completed. Both Android completion properties are accepted. Empty flags are not
treated as ready. Boot property reads have a wall-clock deadline; grace completion
checks the active load generation and running state. RF results from an older
load are ignored and manual RF retest is blocked until boot completes.

UI handles BOOTING and READING without changing its layout. Existing uncommitted
InfoCard changes, guide, test and packaging staging directory were preserved.

Verification: six isolated BootGate tests cover delayed boot, empty reboot flags,
fallback flag, timeout/retry, hung read, stale response and stop during grace.
Final verification: isolated regression suite 35/35 passed, dart analyze clean,
changed Dart files formatted and git diff --check passed.
Physical DUT reboot, RF transmission and desktop visuals remain unverified.

Next: verify on hardware before repackaging. Existing installer/uninstaller and
packaging data-preservation issues from the review are outside this boot patch.
No release/tag/push or dist replacement is part of this change.

# PowerG verification — 2026-09-24

Reviewed the supplied transmitter/release walkthrough against current source,
JAR bytecode and existing Release logs. JAR SHA256 matches source assets,
Release assets and dist assets; Release and dist app.so hashes match.
Existing Release log records radio index 1, FREQ=0, ID=1011231 followed by
Parcel(000f6e1f) at 17:20:32. This is historical evidence, not a new live RF run.

Remaining findings:
- package_dist.ps1 uses robocopy /MIR into dist (can delete runtime-only files)
  and kills all ja_dut_info processes by name; packaging was not executed.
- Process.run(...).timeout does not terminate the Java child, which can retain
  COM ownership after a timeout.
- Java falls back to all radios when the requested frequency is absent and
  emits TRANSMIT_OK without validating return codes. Dart ignores RET/exitCode.
- The live test does not assert PowerGStatus.pass; RF unit tests only cover
  mapping/formatting, not transmitter process behavior.
- Existing Java crash logs and Dart logs also show memory/pagefile exhaustion.
- Polling starts AFTER the awaited Java invocation, so JVM startup consuming
  the polling window is not supported by the control flow.

Checks this turn: dart analyze clean; rf_service_test + boot_gate_test 10/10
passed using direct Flutter snapshot with SDK-cache permission. No hardware
commands, rebuild, package replacement or production-source edits performed.
Next: fix transmitter failure/timeout handling and safe packaging, then add
failure-path coverage before another physical DUT verification.

# Follow-up verification — 2026-09-25

Current checkout includes the transmitter process cancellation/parser fixes,
Java frequency/return-code checks, rebuilt source JAR and preservation-first
packaging from the interrupted fix turn. Later edits resolved the three Dart
brace lint findings. Existing unrelated changes were retained.

Re-ran analyzer: no issues. Nine isolated test files (autostart, DUT header,
transmitter process, info card, hover, boot gate, RF service, widget, OTA):
43/43 passed. The transmitter test exercises an actual owned Windows process
and confirms timeout termination; this does not exercise COM/RF hardware.

Review of the new autostart/DUT-header walkthrough:
- dist/data/app.so is older (2026-09-24), SHA256 472ADC4C4000190B123231FEEF3087FD7FFFFCCFFC3C2A5D401B059855DE0F22.
- Release and dist.release-dbdc39302e49481d97b0199c7e2bf71b app.so match
  SHA256 68CB79889B2C87FB264D273D2DB402F95BDB2E4269A05576B98F516A341338F5.
- Autostart tests query only; no enable/disable/login lifecycle coverage.
- Installer does not check the startup reg-add result before reporting enabled.
- Header paints with an animated horizontal translation while native hit rect
  uses final coordinates. During transition visual and native input regions
  can differ; existing isolated header tests do not exercise this integration.
- Live test still does not assert PowerGStatus.pass. No new hardware/live tests,
  registry writes, installer execution, build or packaging were run this turn.

Next: cover registry failure/enable/disable behavior and native header geometry
through animation; validate Windows login and click-through on the packaged app.

# Header hit-test and autostart fix — 2026-09-25

Header native hit rectangle now uses post-layout RenderBox coordinates each
rendered frame, including AnimatedPositioned and Transform translations.
Missing/fully hidden headers contribute no hit rectangle. Geometry is deduplicated
before sending to native; frame callbacks stop after disposal and do not request
new frames. Existing layout and animation remain intact.
Installer checks startup reg-add failure before reporting success. App menu now
shows a failure toast; failed disable no longer logs success. Registry mutation
runner can be injected for tests without changing actual Windows startup settings.

Validation: changed Dart files formatted; analyzer clean. Added geometry test
covering midpoint/final translation and hidden header, plus registry enable,
disable, access-denied and process-launch-failure cases. No Windows login,
interactive native click-through, installer execution or Release rebuild performed.
Next: validate these two behaviors on Windows with a newly built executable.
