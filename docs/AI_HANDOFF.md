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

# v2.4.2 source review — 2026-09-28

User confirms their build runs. Current analyzer clean; four isolated RF/process/
boot/metadata suites pass 14/14. No live hardware commands or packaging run.
Confirmed remaining source findings: matrix 900M is caught by startsWith(9)
first and mapped to 868; service-check contains(found) also accepts not found;
IQ5 diagnostic returns RF pass and invents firmware 53.10/protocol 8 when absent;
packaging again uses /MIR, saves only three config files, and ignores robocopy
exit status before success/cleanup. Existing tests do not exercise these paths.
No production code changed in this review. Prioritize safe packaging and exact
service/matrix parsing, then distinguish MCU readiness from measured RF pass.

# Four review fixes completed — 2026-09-28

Packaging no longer mirrors/deletes dist or kills running apps. Validated output
moves to dist only when absent; otherwise a unique dist.release-<id> is used.
Failed publication throws; staging is retained. No real dist publication run.
PowerG matrix uses complete band tokens (900M -> 8, 800M -> 9), rejecting
ambiguous/unknown strings. Both binder checks require the exact positive service
response and reject not found. IQ5 bootloader success returns mcuOk, never RF
pass, and preserves missing firmware/protocol as N/A instead of inventing values.

Verification: format completed; analyzer clean; 17/17 RF/process/boot/metadata
tests passed; git diff --check passed. Packaging fixture test preserves hashes
of config/log/old ZIP/unknown files with a locked log, validates separate output,
and confirms invalid input fails without another publication. Fixtures retained
under build/package-test-9c1efa7c0bf64111991e5aee160a8530.
No Release rebuild or physical RF verification. Next: build and validate IQ4/IQ5
on hardware; IQ5 RF reception remains unimplemented and explicitly untested.

# PowerG/SRF audit against guide — 2026-09-30

Read POWERG_SRF_TEST_GUIDE.md and reviewed services, transmitter and monitor.
Pre-existing dirty powerg_service.dart COM-discovery change preserved.
Analyzer clean; rf_service/transmitter_process/boot_gate suites 16/16 passed.
No RF commands, device changes, build, package or production code edits.

Confirmed findings:
1. SRF verifyDut returns PASS solely from Golden transmit acknowledgement;
   it never checks DUT receive data after transmission. Transact 50 is used
   by this implementation as MCU ping; the guide does not establish an SRF
   receive transaction/contract, so that must be verified from binder/source.
2. SRF IQ5 detection contains(found) accepts not found and selects ttyHSLX
   for IQ4. All installed slots are then incorrectly routed to that service.
3. PowerG accepts any nonzero registration ID even when transmitter failed;
   no expected-ID comparison or successful-clear acknowledgement required.
   Shared transmitter IDs further prevent proof of local station origin.
4. SRF parseSrfSlots treats N/A firmware as card presence and checks matrix
   positions only for 1 (matrix 1405 without props yields only slot 1).
5. runCmd has no timeout and discards process exit status; ADB stalls can keep
   testing active indefinitely, and a failed clear can leave stale data valid.
COM discovery filter also omits FTDI named ports despite guide support.
IQ5 PowerG remains MCU-only correctly; RF reception is not implemented there.
Next: fix false-PASS and exact SRF service detection first; obtain SRF reception
binder contract before implementing an RF PASS path, then add pipeline tests.

# Original IQ4/IQ5 tool comparison — 2026-09-30

Read original sources (no changes) from:
IQ4 D:\SW-L10\Lucy_L10_MMI_6.2.0_20260716
IQ5 D:\SW-L10\L10_MMI_20260720
IQ4 L10Gen4MMITest.java and IQ5 controller/TestWorker.java both transmit SRF
via Golden services HSL1/HSL4/HSL2 transaction 18, A49CA0, 0,0,2,20.
They start DUT MMI APK and poll/pull result files, not infer RF pass from transmit
acknowledgement. IQ5 Utils names com.qolsys.l10mmi and eachResults.txt.
IQ5 source comments out PowerG device initialization and PowerGThread dispatch;
this does not establish whether APK IQ5 does MCU-only or functional RF testing.
IQ4 source update345SRFCard uses srfservice_ttyHSLX for slot3: HSLX presence is
not an IQ5 identifier. Earlier audit inference about model selection was too broad;
contains(found) is still incorrect, but routing must follow actual slot/service.
IQ4 APK exists under InitUI/L10MMI/L10MMI.apk; no APK found in provided IQ5 tree.
Next: inspect DUT-side APK/binder reception contract before adding SRF RF PASS.

# Connected IQ4 APK investigation — 2026-09-30

bc4cd33a and 2b69e02 connected. Read-only properties/services checked:
DUT SRF matrix 0000, no SRF binder service, hwd.end=1, PowerG protocol=8.
Golden persist.auto.run=1; HSL1/HSL4/HSL2 SRF services present.
DUT package is com.qolsys.lucyl10mmi at /system/priv-app/L10MMI/L10MMI.apk.
Pulled APK to build/IQ4-connected-L10MMI.apk; its whole-file hash differs from
IQ4 reference APK, so both DEX files were examined independently.

DEX method/constant extraction finds same SRF path in both APKs:
SRFAsyncTask calls binder transaction 50 on srfservice_ttyHSLX and reads int.
startSrfEvents writes int 80 and invokes transaction 11; next writes int 81
and invokes transaction 11. cardPresent binds DatagramSocket to UDP 9950.
Receiver calls DatagramSocket.receive, checks packet length 19 and has a
PASSED/next branch; Air-ID extraction and RSSI logging also exist. This is
preliminary bytecode extraction, not a full decompiler/control-flow proof of
all packet validation. PC transmit transaction 18 alone is not RF evidence.

Evidence retained: build/rf_audit_dex.py, build/rf_audit_dex.txt,
build/rf_audit_connected.txt and pulled APK. No MMI APK started, RF events
activated, properties changed, services restarted or Golden transmit triggered.
No SRF card/service on current DUT: live SRF receive cannot be exercised.
Next: fully decode receive condition and service event contract, then implement
bounded DUT-side receive observation with guaranteed event/socket cleanup;
verify on an IQ4 with SRF card before claiming live functional RF validation.

# IQ4 SRF receive implementation — 2026-09-30

Full resolved DEX inspection confirms the receiver requires exactly 19-byte UDP
frames on port 9950, Air ID in bytes 3..5, RSSI from unsigned byte 6 / 2 - 134,
threshold >= -99 dBm, and 5 matching frames. A49CA0 maps to 25390A for GE and
49CA0A for Honeywell/DSC. HSLX transaction 11 enables/disables events with 80/81;
transaction 50 is only MCU ping. Main SRF and inner-class instructions match
between reference and installed APK; SRFCardDetect firmware matching differs.
See docs/SRF_RECEIVE_CONTRACT.md and tools/srf/decode_contract.py for evidence.

Changed srf_service.dart to remove TX-ACK-only PASS, reject not-found service
responses, resolve actual native/HSLX service, and gate unsupported services or
unknown firmware to MCU OK. New srf_receiver.dart runs a bundled DEX helper,
waits for bind/armed handshake before Golden TX, and requires TX acknowledgement,
matching RX result, zero exit and successful teardown before PASS. Host/remote
deadlines fail closed; exclusive socket ownership lasts through teardown.
Normal timeout closes socket and requests event81. Watchdog attempts cleanup
then exits if binder hangs; successful teardown cannot be guaranteed when binder
or device is unavailable, so no PASS is emitted in that situation.

Helper source/tests/build script under tools/srf; JAR in assets/tools/srf added
to pubspec assets. Updated guide to distinguish MCU ping from actual receive.
Preserved pre-existing powerg_service.dart changes and all dist/runtime data.
Helper temp files created by this audit were retained; no broad cleanup occurred.

Verification: Java packet/UDP regression checks passed, helper DEX rebuilt with
JDK17 and official R8 8.3.37, changed Dart files formatted, focused dart analyze
clean, 16 Flutter tests across srf_receiver/rf_service/transmitter_process passed
(including actual Flutter asset loading of the DEX JAR),
git diff --check passed. Flutter wrapper was interrupted after hanging; direct
SDK snapshot needed escalated cache/lockfile write permission and passed.

Latest helper pushed to bc4cd33a as /data/local/tmp/ja_srf_audit_20260930_final_v2.jar.
Android API28 launches it and binds (READY), then fails closed because HSLX
service is missing. DUT matrix remains 0000. No Golden RF transmission, MMI
launch, persistent install or fresh Windows Release packaging was performed.
Next: connect an IQ4 with an installed SRF card/HSLX and validate real receive,
silence timeout and event81 teardown. Fixed transmitter Air ID cannot identify
station origin if nearby stations use the same ID; isolate that acceptance run.
Other SRF service packet contracts and IQ5 APK remain unverified. Existing SRF
discovery/property commands still use shared unbounded runCmd; outside this
receiver patch, a stalled ADB property read can delay the overall RF workflow.

# IQ5 live verification and RSSI correction — 2026-10-01

IMPORTANT: prior SRF byte-6 RSSI conclusion above was incorrect. In both IQ4 and
IQ5 disassembly, v10 is reused while printing packet bytes and holds 14 at the
RSSI aget-byte instruction. Actual RSSI is unsigned byte14 / 2 - 134. Fixed
tools/srf/SrfReceiver.java, rebuilt bundled DEX JAR, and added Java regression
coverage that a strong byte6 cannot rescue a weak byte14. Extended receive
deadline to 30 seconds per IQ5 APK, watchdog cleanup/exit to 38/43 seconds, host
completion wait to 47 seconds. Added TX_ACK evidence to receiver raw details.

IQ5 f74b6e05, PCASN QB95 prefix, Android API34, package com.qolsys.l10mmi.
Pulled APK to build/IQ5-connected-L10MMI.apk. Source program under
D:\SW-L10\L10_MMI_20260720 triggers qolsys.factory.hwd=1 then waits25 seconds.
Initial qolsys card properties/services were absent despite persisted hardware
matrix. Exercised that reference discovery trigger; live properties/service
appeared: SRF matrix0010, slot3 FW11.2.0-G26, HSLX, PowerG FW53.10/protocol8.
IQ5 APK independently confirms transaction11 event80/81, UDP9950/19-byte frames,
same Air ID conversion, RSSI byte14, threshold -99 and count5, with 30s timeout.

First real application service run: PowerG mcuOk, SRF fail/count0. Independent
30s UDP probe saw343 packets, including25390A, all rejected under wrong byte6.
After correction, actual Flutter service test returned PowerG mcuOk (FW53.10,
915MHz), SRF pass with TX_ACK=true and RX_OK ID25390A COUNT5 CLEAN1. Test now
asserts both expected statuses. No helper process remains; teardown transaction
accepted, independent event-state readback unavailable. No PowerG RF claim.

Evidence retained in build/iq5-live-rf-result.json, iq5-live-test-fixed.log,
iq5-srf-probe.log, iq5-rf-disassembly.txt; test/iq5_rf_live_test.dart is opt-in
via --dart-define=IQ5_RF_SERIAL=f74b6e05. Decoder now supports --package for IQ5.
Java packet/UDP tests and focused Dart analyzer passed; live acceptance passed.
Updated docs/SRF_RECEIVE_CONTRACT.md with corrected evidence. No Windows visual
test, flash, reboot, dist replacement or deletion. Pre-existing PowerG changes,
.package-stage-* and dist.release-* directories preserved. The current dist
helper may still contain the old RSSI offset: source/asset fix needs safe rebuild
and packaging before distributing. Cold boot/discovery timing and IQ4 physical
RF acceptance remain separate, unverified paths. Fixed Air ID station collision
limitation remains; physical source cannot be cryptographically attributed.

Final regressions:16 passed, opt-in IQ5 live test skipped in the offline suite;
separate actual IQ5 acceptance passed1/1. Analyzer and diff check clean.
PowerShell's Console.ReadLine fixture stalled at READY during offline testing;
replaced the successful-session mock with a deterministic Dart child process.
It still exercises actual stdin/stdout GO/ARMED handshake and TX/RX gating;
explicit PowerShell bind-error/owned-process timeout tests remain. No production
stdin framing change retained. Reviewable source/DEX fixes are not committed or
packaged into existing dist.

# Unplug during acquisition — 2026-10-01

Root cause: _checkDevices awaited the full _loadDut/boot/acquisition before the
next device scan; shared runCmd used unbounded Process.run through a shell.
USB removal could leave the monitor stuck reading while it could not detect
the missing device. Serial-only result guards also allowed old read/HTTP
results after reconnecting the same serial.

Changed logic.dart to launch acquisition independently of the poll loop, skip
boot/reload probes while a load is active, and clear UI immediately when the
current serial disappears from adb devices. Exact device/offline/unauthorized
parsing replaces substring matching. Session generations guard acquisition,
station HTTP and RF results; stop/dispose invalidate sessions and late scans.
RF futures are observed concurrently to avoid unhandled cancellation errors.

New command_scope.dart owns only session-started processes and HTTP cancellation
callbacks. runCmd now uses the bounded direct process runner; monitor commands
use5-second timeouts, other shared commands default20 seconds. Disconnect,
selection change, stop/dispose cancel owned ADB/Java transports without killing
the global ADB server. srf_receiver.dart and transmitter_process.dart honor
session ownership. Remote SRF helper still enforces its own30-second receive /
43-second watchdog; physical disconnect cannot prove remote event teardown.
Source remains conservative about RF PASS.

Added disconnect_read_test.dart covering removal during a hung acquisition,
same-serial reconnect rejecting old metadata/RF PASS, unauthorized/offline,
dispose during pending device scan, owned-process cancellation and command
timeout/cancellation. Constructor seams allow controlled tests without hardware
or network writes. Final suite29 tests passed; targeted analyzer and diff check
clean. Evidence: build/disconnect-regression-final.log. No physical USB removal
or Windows UI validation, release build, dist replacement or deletion performed.
Existing artifacts preserved. Next: verify actual unplug/replug while READING
on a freshly built Windows app, then package safely if requested.

# Power optimizer independent verification — 2026-10-03

Reviewed the attached walkthrough against the dirty source changes in main.dart,
main_window.dart, new power_coordinator.dart and power_coordinator_test.dart.
No production source changes made during this verification; dist preserved.
Global TickerMode integration is present. Full dart analyze reports no issues;
format lib/test checks39 files with0 changes;74 offline tests pass. Both live
test files were excluded deliberately; hardware acceptance was not rerun.

Three additional reproduction tests against actual PowerCoordinator/MarqueeText
fail: constructing the coordinator after lifecycle is already hidden still
enables animations; hover retained across hide/show enables animations without
focus or renewed hover; changing marquee text during active scrolling does not
stop the old driven scroll during the new initial hold (offset75.41 ->131.96
after300ms). Evidence: build/power_optimizer_audit_test.dart and
build/power-optimizer-audit.log. These are audit reproductions, intentionally
failing until corresponding production fixes; kept outside the normal suite.

Walkthrough overstates coverage: phase test only exercises the forward leg in a
copied sample widget, not MainWindow or reverse/rapid transitions; marquee test
pauses before initial scrolling; background test uses a generic periodic timer,
not AdbMonitor/RF/OTA consumers. Native hit-test WM_TIMER remains at20ms even
with UI tickers muted. No measured Windows Release CPU/GPU/FPS, native visual
validation, physical DUT acceptance, build/package or executable replacement.
Do not claim zero CPU/GPU/FPS or live RF acceptance from these test results.
Next: fix the three confirmed lifecycle/marquee findings with regressions, then
exercise real MainWindow reverse/rapid transitions and measure native behavior.

# Power optimizer fixes and lightweight states — 2026-10-03

Fixed all three confirmed findings: PowerCoordinator synchronizes the binding's
current lifecycle immediately after listener registration; hide clears stale
hover/focus and ignores hover-enter events while hidden; MarqueeText explicitly
stops the previous driven scroll when text changes before starting its new hold.
Lifecycle updates use the same setters so direct hide and Flutter hide agree.

User additionally requested effects off without ADB, after closing information,
or when tucked at the screen edge. MainWindow now derives a local gate from
deviceConnected, expanded state and actual edge/hover state. It explicitly stops
pulse/station controllers, mutes descendant tickers/marquees, disables backdrop
blur and glow/shadows, and applies collapsed/docked layout without transition.
Connected/expanded UI resumes when revealed from the edge, subject to the power
coordinator's lifecycle/idle gate. Hover/focus alone cannot bypass disconnected
or collapsed states. Animation epochs reject stale completion callbacks.
Business ADB/RF/OTA code and native click-through logic were not changed.

Added power_optimizer_regression_test.dart (initial lifecycle states, stale hover,
real lifecycle transitions and actual marquee text changes) and
main_window_power_test.dart (real MainWindow with controlled ADB/native channel,
isolated OTA config; tests gate/controllers/blur/shadows and recovery).
83 offline tests passed in build/power-optimizer-fix-final.log; analyzer clean.
Focused suite17 tests passed. SDK tools called directly; no flutter clean.
Existing dirty changes retained. No hardware live tests, Windows executable
launch, native visual/GPU measurement, package/build or dist changes performed.
Next: build to a separate output and verify real Windows hide/reveal and GPU load
without replacing the existing portable dist.

# Reading marquee and device presentation transitions — 2026-10-03

User clarified that scrolling text must remain enabled while information is open,
and ADB connect/disconnect must trigger one-shot opening/closing effects.
MaterialApp now gates tickers by visibility; MainWindow separates its decoration
policy via _DecorationMode from the reading ticker gate. Text continues scrolling
while connected information is expanded and the window visible, including idle,
blur or a tucked bubble when cards remain visible. Hidden/collapsed/disconnected
steady states still stop marquee. Blur/shadows, pulse/station and RF spinner stay
disabled according to the previous lightweight policy; spinner is static there.

Connection state changes start the existing360ms sprout/retract animation once
when visible and expanded. A temporary gate permits closing after ADB removal,
then returns to the lightweight disconnected state. Rebuilds alone do not trigger
another device animation. No business service logic changes or artifact writes.

Extended real MainWindow regression to verify actual marquee offset progresses
without focus, freezes on window hide, and device animation has intermediate
forward/reverse values before settling at1/0. Focused tests24 passed; final full
offline suite83 passed, analyzer/format/diff check clean. Evidence:
build/marquee-device-transition-final.log. Existing packaging-stage/release
folders appearing in the dirty worktree were left untouched. No Windows visual,
physical USB or GPU measurement, executable rebuild or packaging performed.
