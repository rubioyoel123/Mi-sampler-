# Audio asset provenance

The Windows build prepares its required WAV assets with
`tool/prepare_assets.ps1`.

## Casio SK-5 samples

The script obtains the drum archive from the artist's official sample page:

- [SK-5 Samples](https://www.frequency303.com/samples/sk5-samples/)
- [Frequency 303 sample packs](https://www.frequency303.com/samples/)
- [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/)

The artist states that the sample packs on that page are licensed under CC0.
Eight individual one-shots from the archive are used in the SK-5 bank. Selected
copies also supply the kick, snare, hi-hat, and bongo slots in the Champeta
bank, and the snare and bongo slots in Dembow.

## Procedurally generated samples

The remaining kick, 808, clap, clave, timbale, cowbell, and shaker samples are
generated locally by the project script as mono PCM WAV files. They use
elementary oscillators, envelopes, and generated noise; they do not contain
recordings or samples copied from ROMPAD JR or another sample pack.

These are starter sounds created for this project, not recordings of
traditional instruments. The bank names describe their intended arrangement
and do not claim acoustic authenticity.
