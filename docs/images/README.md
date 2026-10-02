# VoltDeck example images

Documentation for release 2026.8-v2. The owner separately confirmed physical
X20RS/model testing passed on 2026-10-02; these images remain synthetic.

These PNGs are native ETHOS 26.1.2 simulator renders with synthetic values.
They illustrate the widget's presentation, not recorded flights or audio tests.
The updated RF screenshots feed 180 synthetic history points through the
bounded 48-bin renderer. Dashboard screenshots are refreshed for source-named RF fields and correct
inactive units. RSSI graphs illustrate ACCST 45/42 dB; VFR graphs illustrate
the widget visual 95% early / 50% low profile, not modified native alarms.
Diagnostic screens use actual ETHOS none/always-on selections with synthetic
arm, throttle and pack data, not recorded flights.
The example counter of 42 is fabricated and is not saved as a real counter.

The four pack-transition images were captured from production flight callbacks
with synthetic controls/telemetry in the native ETHOS runtime. They show a
paused first session, its retained last log, a new qualifying candidate and
a second qualified session. Their private counter (1 then 2) stays in RAM
and does not exercise real counter-file persistence or represent real flights.

The refreshed full-widget captures are 749 x 449 pixels: the displayed
simulator canvas was cropped without resizing or changing its contents.
rf-inactive-units.png is a 749 x 110 crop of that canvas header; its missing
readings are synthetic. The other existing examples retain their original size.

See [the illustrated guide](../Configuration.md) and
[the Norwegian guide](../Konfigurasjon-norsk.md) for settings and limitations.
The Ultimate AMR model picture is owner-supplied documentation artwork.
It is optional and is not part of the installed widget. See [NOTICE](../../NOTICE.md).
