class SamplerKit {
  const SamplerKit({
    required this.name,
    required this.pads,
    this.velocityCurve = 'linear',
    this.masterGain = 1,
    this.masterVolumeCc,
  });

  final String name;
  final String velocityCurve;
  final double masterGain;
  final int? masterVolumeCc;
  final List<SamplerKitPad> pads;
}

class SamplerKitPad {
  const SamplerKitPad({
    required this.index,
    required this.midiNote,
    required this.name,
    this.volume = 1,
    this.gain = 1,
    this.pan = 0,
    this.oneShot = true,
    this.volumeCc,
    this.trimSeconds = 0,
    this.normalizationGain = 1,
    this.samplePath,
  });

  final int index;
  final int midiNote;
  final String name;
  final double volume;
  final double gain;
  final double pan;
  final bool oneShot;
  final int? volumeCc;
  final double trimSeconds;
  final double normalizationGain;
  final String? samplePath;
}
