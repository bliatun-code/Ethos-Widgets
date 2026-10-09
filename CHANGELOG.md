# Changelog

## 2026.10-v6 - release, 2026-10-09

- Add a Custom source alongside lower-deck presets, with position 1–3 and an Only Custom option; Custom replaces the cell row when all three rows are occupied.
- Give average cell voltage a battery-specific scale and low/high voltage colours, retaining the existing voltage-to-percentage calculation.
- Rename HV Lipo to LiHV and use its 4.35 V upper cell boundary throughout the cell display.
- Keep configuration fields inactive when the selected method or display does not use them, while preserving their saved values.
- Move setup explanations from the radio form to complete, illustrated guides in menu order, in English and Norwegian.
- Cancel a flight-counter reset if the widget, selected controls or model change during confirmation.
- Check consumed-mAh remaining against a stable low-load voltage reference before showing charge: automatically accept up to 10 percentage points difference, require confirmation above 10 through 20, and block larger differences. LiFe uses manual charge/counter confirmation.
- Require a new check after startup, long pack-telemetry loss, counter resets or battery setup changes; retain qualification during ordinary flight and voltage sag.
- Require valid live readings and the same battery setup when accepting a consumption counter.
- Renew ETHOS focus while the selected widget is visible, retaining the radio's standard menus.

## 2026.10-v5 - release, 2026-10-07

- Fix an intermittent source-name error while editing widget settings.
- Avoid a false unknown-capacity reading after switching consumption sensors.
- Cancel source and audio updates safely when the widget is closed or its settings change.

## 2026.10-v4 - release, 2026-10-06

- Add ETHOS 1.6.6 compatibility.
- Remove internal settings-file information from the radio configuration menu.
- Remove the Memory snapshot menu action.
- Simplify the installation and configuration documentation.
- Regression and render checks passed; physical-radio testing passed on ETHOS 26.1.2.

## 2026.10-v3 - release, 2026-10-05

- Physical X20RS testing of the final RC1 build passed on 2026-10-05.
- Major pre-publication hardening of the battery, flight-log and telemetry dashboard.
- Unexpected consumed-mAh decreases become unknown instead of showing a falsely full battery; safe manual acknowledgement and sustained-power-loss boundaries.
- Persistent alarm cooldowns, non-overlapping WAV playback and fair GasDeck RX/fuel scheduling.
- Strict percent units, preview/live isolation, guarded disposed/nil callbacks and bounded native text/source caches.
- Versioned checksummed per-model settings; no old scalar-settings migration. Reconfigure capacities, chemistry, limits, alarms and flight options. Source layouts and counter files retained.
- Shared final check: 252 named automated checks across both widgets; preceding native simulator run: 84 functional cases and 120 production frames, zero failures.
- GasDeck cold rendering optimized with unchanged graphics; PC simulator timings are not radio CPU guarantees.
- Release code differs from the radio-tested RC1 only in displayed version/test-status strings.
- ZIP includes scripts/VoltDeck/main.lua, INSTALL.txt, LICENSE and NOTICE.md; no bytecode, private helpers, settings, logs or model records.

## 2026.10-v2 - release, 2026-10-05

- Fix `destroy()` when called without a created widget instance, which previously raised a nil `widget` error (line 1891 in 2026.9-v2).
- Keep ordinary cleanup and flight ownership release intact; empty cleanup cannot reset the flight, counter, retained log or pending automatic view.
- Add focused lifecycle coverage and native simulator lifecycle probes alongside the existing transition tests.
- The complete 2026.10-v2 update passed testing on the physical X20RS on 2026-10-05.
- Include optional Auto-open log and Extra log delay introduced in 2026.9-v2; defaults remain Off and 5 s.
- All 53 focused Lua regression cases and 25 native ETHOS simulator cases passed; the native suite also passed after restart.
- Publish VoltDeck-2026.10-v2.zip with Lua source, installation instructions, license and notices. No compiled bytecode or private fixtures are bundled.

## 2026.9-v2 - development, included in 2026.10-v2, 2026-10-04

- Add optional per-model Auto-open log, default Off.
- Add Extra log delay: 5 s by default, adjustable 0-120 s after Pack loss delay completes a qualified session.
- Cancel pending navigation when pack voltage returns or the user changes view/settings, disables logging or switches model.
- Keep each auto-open one-shot and preserve the existing count, retained log and RF history.
- Read both 2026.8 and earlier checked settings with new options defaulted safely.
- Add focused regression and private native-simulator transition coverage; no synthetic fixture is distributed.
- Leave released VoltDeck-2026.8-v2.zip and its physical-test confirmation unchanged.
- Automatic opening passed physical-radio testing on 2026-10-04; the separately observed cleanup error is addressed in 2026.10-v2.

## 2026.8-v2 - first public release, 2026-10-02
Physical X20RS/model testing passed on 2026-10-02.
All 11 native ETHOS simulator transition stages and 14 focused Lua regression
cases also passed with synthetic inputs. This is not universal compatibility
or safety certification. The released Lua is unchanged from the tested build.

- Publish the named VoltDeck-2026.8-v2.zip installation package.
- Refresh the illustrated guides, RF examples and pack-session transition images.
- Replace pending physical-test statements for the current version.

- Motor ARM and optional airborne gates pause, rather than terminate, a pack session.
- Resume the same qualification progress, count latch, peaks and RF history after rearming.
- End a session only after continuously missing valid pack voltage for Pack loss delay.
- Rename End delay to Pack loss delay; retain checked settings, saved delay and counter format.
- Retain/display the last qualified log through aircraft power-off and the next qualification.
- Replace the previous log only when the next flight qualifies; logs remain RAM-only.
- Distinguish paused, pack-loss waiting and completed states in status/diagnostics.
- Keep 180 history points per record and existing bounded RF drawing work; at most one
  previous qualified record and one current candidate are retained.

The entries below describe historical development status at the time.
Later release validation is recorded in the dated release entries above.

## 2026.7-v2 - development, 2026-10-02
No release or tag. Physical-radio confirmation of these fixes is pending.

- Normalize CATEGORY_NONE sources: an optional airborne gate selected as --- passes.
- Handle CATEGORY_ALWAYS_ON without interpreting its numeric value as an OFF switch.
- Retain arm, voltage, duration and high-throttle qualification requirements.
- Name RF readings and graph traces from sources; retain % for inactive VFR.
- Add independent ACCESS/TD/TW, ACCST and Custom visual profiles for each RF slot.
- Label the 95% early / 50% low VFR visual profile separately from native alarms.
- Preserve existing checked model settings and thresholds as Custom during migration.
- Pin RF graph sources and labels per flight; retain bounded drawing/history budgets.
- Refresh synthetic simulator screenshots and illustrated guides.

## 2026.6-v2 - development, 2026-10-02
No release or tag. Physical-radio validation is still pending.

- Add read-only Flight diagnostics with raw/normalized throttle values.
- Show arm, airborne and pack-voltage gates and qualification progress.
- Identify blocking flight-count conditions and counter storage errors.
- Clarify raw endpoints versus channel-monitor percentages.
- Keep saved settings, source assignments and flight qualification rules unchanged.

## 2026.5-v2 - development, 2026-10-02
No release or tag. Physical-radio confirmation of RF optimization is pending.

- Move RF geometry preparation out of paint into bounded wakeup slices.
- Draw at most 48 minimum-preserving time bins per RF channel.
- Retain the 180-point history, missing-data gaps, flight statistics and counter format.
- Cache integer drawing primitives; release graph buffers when the log closes.
- Refresh synthetic RSSI/VFR examples using 180 input points per channel.
- Battery calculations, source assignments and native radio alarms are unchanged.

## 2026.4-v2 - development, 2026-10-02
Not a tagged or published release. Physical X20RS/model testing is in progress.

- Publish readable Lua under the VoltDeck folder and widget key.
- Modern full-screen dashboard; theme, black and custom backgrounds.
- Consumed-mAh battery calculation and optional alternative methods.
- Selectable low-battery WAV and repeat interval.
- Numeric/retro LCD lower deck with RPM, Watts, cell voltage or custom source.
- Measured and explicitly labelled KV-estimated RPM.
- Checked per-model settings, optional flight counter and bounded RF history.
- Illustrated configuration examples with synthetic simulator values.

The internal v1 snapshot is an archive, not a separately supported release.
