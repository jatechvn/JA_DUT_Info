# SRF receive contract — IQ4/IQ5 L10MMI, corrected 2026-10-01

## Evidence

Resolved DEX instructions were inspected from the connected IQ4 `bc4cd33a`:
`/system/priv-app/L10MMI/L10MMI.apk`, package `com.qolsys.lucyl10mmi`.
APK SHA-256: `1894C53EF89A11E1DD00D24D6713574FF7DA60F5FC14BB6C68ADB731575C4C96`.
Reference IQ4 APK SHA-256: `3544F85859C5FBDB2A606B5771808A0242AFED3B4B285FA7736C89ABD1A4364C`.
APK file hashes differ; do not assume all other tests are identical.
Resolved instructions for `SRF` and its inner classes are identical in both
APKs. `SRFCardDetect` differs: the connected APK additionally accepts firmware
contained in the configured firmware list when exact equality fails.

Use `tools/srf/decode_contract.py APK --tool-path build/rf-audit-tools`
with an isolated Androguard install to reproduce the resolved SRF disassembly.
The APK copies and full output remain in ignored `build/`; APKs are not bundled.

## Verified receive branch

`SRF.cardPresent` binds UDP **9950** and sets a **15-second** timeout.
`startSrfEvents` uses `srfservice_ttyHSLX`, interface token of the same name,
transaction **11**, integer **80**; `next` uses transaction **11**, integer **81**
and closes the socket. Transaction **50** is MCU ping, not RF reception.

In `SRF$3.run`, instruction offsets are bytes relative to the method:

| Condition | Instructions / result |
| --- | --- |
| Datagram length | `00f8` / `00fc`: exactly 19 bytes |
| Air ID | bytes 3, 4, 5 formatted as hexadecimal; comparison at `05a8` |
| RSSI | byte **14**; `generateDBM`: integer division `unsignedByte / 2 - 64 - 70` |
| RSSI threshold | `064c` double constant = −99; `0656` / `065a` reject lower RSSI |
| Count | `065e`: increment only after ID and RSSI checks; require 5 |

`getCorrespondingAirID` converts the PC transmitter ID `A49CA0` according to
the firmware brand: GE (`G`) yields `25390A`; Honeywell (`H`) and DSC (`D`)
yield `49CA0A`. GE reverses each first pair's eight bits, then reverses nibble
5 and appends nibble 4. H/D rotate the first hexadecimal digit to the end.

Original APK checks count == 5 at `04a2` **before validating the current packet**,
so it waits for another 19-byte packet after the fifth match to report PASS.
The new helper completes immediately after the fifth valid packet.
It uses a full-size UDP buffer so an oversized packet cannot be truncated into
a seemingly valid 19-byte frame, and a monotonic deadline survives invalid traffic.

Correction: the first analysis incorrectly identified byte 6 as RSSI. Register
`v10` initially holds 6 while printing bytes, but is overwritten through 14
before the RSSI `aget-byte`. This register reuse occurs in both IQ4 and IQ5 APKs.
Reading byte 6 rejected actual IQ5 traffic with a computed −134 dBm.

## Application behavior

- HSLX is a service capability on IQ4 too, not an IQ5 model identifier.
- Require an exact positive `service check` response. Prefer a slot's native
  service; use HSLX only for slot 3 or a single installed slot when native is absent.
- Enable receiver after exclusive socket bind; wait for ARMED before Golden TX.
- PASS requires valid TX ACK, five matching receive frames, exit 0 and confirmed
  accepted event-teardown transaction without a negative Binder exception reply.
  This confirms IPC acceptance, not independent hardware event-state readback.
  Silence, mismatches, busy port, failed
  TX, failed teardown or helper error cannot become PASS.
- Unknown firmware brand or a non-HSLX receive service stays MCU OK / untested RF.
  The connected IQ5 APK now independently confirms the HSLX contract.
- Receive deadline is 30 seconds, matching the IQ5 APK (IQ4 APK uses 15 seconds).
  A remote watchdog attempts teardown at 38 seconds and forces process exit at
  43 seconds if binder/input hangs. The host
  bounds receiver and Golden-transmit ADB processes. Existing discovery/property
  commands still use the shared `runCmd` implementation. An unresponsive binder or disconnected device can
  prevent proving teardown; this always fails and may require device recovery.
- No MMI process is stopped, no properties are changed by the receiver, and no
  persistent device install occurs. Newly created helper JARs stay in host/device
  temporary directories; existing runtime data and `dist` are preserved.

## Verification boundary

Java regression checks exercise packet length, both Air IDs, unsigned RSSI,
threshold boundary, five/four packets, oversized UDP and silent timeout.
Flutter tests exercise result parsing, TX + RX gating, bind failure, cleanup
failure and process readiness timeout.

During the IQ4 audit on 2026-09-30, `bc4cd33a` reported matrix `0000` and no HSLX binder service.
Launching the DEX helper on Android API 28 binds and fails closed on missing
service; no Golden transmit is requested. This does **not** validate real RF
reception, event delivery or teardown on an installed card.

### IQ5 live acceptance — 2026-10-01

IQ5 `f74b6e05`, PCASN prefix `QB95`, Android API 34. Installed package is
`com.qolsys.l10mmi`, APK SHA-256
`3B6CC6B74CA695EB70CC3073A82F498BFFE385F6ACB0E923DEFDF3E3BF877158`.
Run the decoder with `--package com.qolsys.l10mmi` to reproduce IQ5 SRF methods.
The reference PC program under `D:\SW-L10\L10_MMI_20260720` sets
`qolsys.factory.hwd=1` then waits 25 seconds for discovery. This step was exercised;
it populated SRF slot 3 firmware `11.2.0-G26`, matrix `0010`, and HSLX service.

Before the RSSI correction, the real application service returned SRF FAIL.
A separate 30-second diagnostic receiver observed 343 UDP packets, including
the expected Air ID, but zero matches using the erroneous byte-6 RSSI field.
After rebuilding the helper with byte 14, the real Flutter service test returned
`TX_ACK=true` and `RESULT:RX_OK:ID=25390A:COUNT=5:CLEAN=1` with exit 0.
PowerG returned MCU OK, firmware `53.10`, 915 MHz, after its non-flash `-c 1`
communication/version/calibration diagnostic. PowerG RF was not exercised.
No helper process remained after completion. IPC teardown was accepted; there is
no independent hardware event-state readback in this contract.

Evidence: ignored `build/iq5-live-rf-result.json`, `build/iq5-srf-probe.log`,
`build/iq5-rf-disassembly.txt`, `build/iq5-live-test-fixed.log`.
`test/iq5_rf_live_test.dart` is opt-in using `--dart-define=IQ5_RF_SERIAL=...`.
Source/service behavior was validated; no Windows UI test or `dist` replacement
was performed. Keep RF origin/isolation limitations below in mind.

`A49CA0` is a fixed test ID shared with the original tool. The packet contract
contains no station nonce or authenticated sender. Matching packets cannot
prove local-station origin if nearby stations transmit the same ID; run the
hardware acceptance test with other stations quiet or RF isolation.

Rebuild the bundled helper with `tools/srf/build_receiver.ps1 -R8Jar PATH` using
the standalone official R8/D8 JAR (audit used version 8.3.37) and JDK 17.
The script runs Java regressions, emits a DEX JAR asset and does not package `dist`.
