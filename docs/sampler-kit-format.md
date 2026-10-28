# Sampler Perreo kit format

Sampler Perreo saves kits as UTF-8 XML files with the `.spkit` extension.
The format is owned by this application and does not depend on RomPAD JR.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<SamplerPerreoKit formatVersion="1"
                  name="Fictional demo"
                  velocityCurve="linear"
                  masterGain="0.8"
                  masterVolumeCC="7">
  <Pad index="0" note="60" name="Fictional kick"
       volume="0.8" gain="0.8" pan="-0.2" oneShot="true"
       volumeCC="20" trimSeconds="0.01"
       normalizationGain="1.0">
    <Sample src="Fictional_demo_samples_123/pad_0_kick.wav" />
  </Pad>
  <Pad index="1" note="61" name="Empty pad"
       volume="1.0" gain="1.0" pan="0.0" oneShot="true"
       trimSeconds="0.0" normalizationGain="1.0" />
</SamplerPerreoKit>
```

The names and sample path above are fictitious examples. A pad with no `Sample`
child is empty. The `src` path is resolved relative to the kit XML file unless
it is an absolute Windows or POSIX path. Saving a kit copies assigned samples
to a sibling package directory and writes relative paths.

## Fields

| Location | Field | Type and behavior |
|---|---|---|
| Root | `formatVersion` | Integer; currently `1`. The reader rejects unknown versions; when omitted, it treats the file as version `1` for compatibility with early drafts. |
| Root | `name` | Display name for the kit. |
| Root | `velocityCurve` | Descriptive string reserved for the kit's velocity response. `linear` is the current default. |
| Root | `masterGain` | Non-negative multiplier loaded into the app's master-volume control. Output is clamped to 0–1 during playback. |
| Root | `masterVolumeCC` | Optional MIDI CC number, 0–127, controlling master volume. |
| `Pad` | `index` | Unique integer from 0 to 127. |
| `Pad` | `note` | MIDI note number, 0–127. |
| `Pad` | `name` | User-facing pad name. |
| `Pad` | `volume` | Per-pad multiplier from 0 to 1, applied before `gain`. |
| `Pad` | `gain` | Non-negative per-pad multiplier. |
| `Pad` | `pan` | Number from -1 (left) through 0 (center) to 1 (right). |
| `Pad` | `oneShot` | Boolean (`true`/`false` or `1`/`0`); defaults to `true` when omitted. In one-shot mode the sample plays to completion; otherwise a MIDI Note Off stops it. |
| `Pad` | `volumeCC` | Optional MIDI CC number, 0–127, controlling pad volume. |
| `Pad` | `trimSeconds` | Non-negative start offset in seconds. Playback seeks to this position after starting. |
| `Pad` | `normalizationGain` | Non-negative multiplier applied with gain and volume. This is a stored multiplier, not an audio normalization analysis operation. |
| `Sample` | `src` | Sample path. The current UI supports sample files accepted by its audio engine. |

Unknown XML attributes/elements are not guaranteed to survive editing and
resaving. Paths and file existence are checked at load/save time; missing
samples are reported rather than silently replaced.

## `.padkit` import boundary

The importer recognizes the observed `PadKit` root and `Pad` attributes:
`velocityCurve`, `masterGain`, `masterCC`, `index`, `note`, `gain`, `pan`,
`oneShot`, `volumeCC`, `trimSeconds`, `normGain`, `file`, and `name`.
`volumeCC="-1"` is mapped to no CC assignment. `normGain` maps to the native
`normalizationGain` field, and `masterCC` maps to `masterVolumeCC` for this
application.

These are explicit Sampler Perreo import choices, not verified descriptions of
RomPAD JR runtime behavior. The `.padkit` importer has only been checked against
the observed XML shape; this does not establish full compatibility with
RomPAD JR, including sample resolution, playback semantics, or save behavior.
Because the observed `.padkit` shape has no separate `volume` attribute, its
imported pads start with volume `1`. Saving always writes `.spkit`, never
overwrites or edits an imported `.padkit`.
