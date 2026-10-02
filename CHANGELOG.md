# Changelog

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
