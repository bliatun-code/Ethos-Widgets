# Changelog

## 2026.10-v2 - release, 2026-10-05

- Fix `destroy()` when called without a created widget instance, which previously raised a nil `widget` error (line 1891 in 2026.9-v2).
- Keep ordinary cleanup and flight ownership release intact; empty cleanup cannot reset the flight, counter, retained log or pending automatic view.
- Add focused lifecycle coverage and native simulator lifecycle probes alongside the existing transition tests.
- The owner confirmed that the complete 2026.10-v2 update passed testing on the physical X20RS on 2026-10-05.
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
- The owner confirmed automatic opening on the physical radio on 2026-10-04; the separately observed cleanup error is addressed in 2026.10-v2.

## 2026.8-v2 - first public release, 2026-10-02
The owner confirmed that physical X20RS/model testing passed on 2026-10-02.
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
The current-version physical-test confirmation is recorded above.

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
