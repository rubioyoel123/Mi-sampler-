import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sampler_perreo/models/sampler_kit.dart';
import 'package:sampler_perreo/services/sampler_kit_xml.dart';

void main() {
  group('SamplerKitXml', () {
    test('imports the observed padkit shape without sample assets', () {
      const fixture = '''
<PadKit velocityCurve="2" masterGain="0.5" masterCC="7">
  <Pad index="0" note="48" gain="0.75" pan="-0.25" oneShot="1"
       volumeCC="20" trimSeconds="0.01" normGain="1.2"
       file="C:\\fictional\\kick.wav" name="Fictional kick" />
  <Pad index="1" note="49" gain="1.0" pan="0.0" oneShot="0"
       volumeCC="-1" trimSeconds="0.0" normGain="1.0" file="" name="" />
</PadKit>
''';

      final kit = SamplerKitXml.read(fixture, name: 'Fictional kit');

      expect(kit.name, 'Fictional kit');
      expect(kit.pads, hasLength(2));
      expect(kit.pads.first.samplePath, r'C:\fictional\kick.wav');
      expect(kit.pads.first.midiNote, 48);
      expect(kit.pads.first.volume, 1);
      expect(kit.pads.first.pan, -0.25);
      expect(kit.pads.first.volumeCc, 20);
      expect(kit.pads[1].samplePath, isNull);
      expect(kit.pads[1].volumeCc, isNull);
      expect(kit.pads[1].oneShot, isFalse);
    });

    test('round-trips the native Sampler Perreo format', () {
      const kit = SamplerKit(
        name: 'Synthetic test kit',
        velocityCurve: 'linear',
        masterGain: 0.8,
        masterVolumeCc: 7,
        pads: [
          SamplerKitPad(
            index: 0,
            midiNote: 60,
            name: 'Synthetic tone',
            volume: 0.6,
            gain: 0.7,
            pan: 0.25,
            oneShot: true,
            volumeCc: 21,
            trimSeconds: 0.02,
            normalizationGain: 1.1,
            samplePath: 'samples/synthetic.wav',
          ),
          SamplerKitPad(index: 1, midiNote: 61, name: 'Empty pad'),
        ],
      );

      final xml = SamplerKitXml.write(kit);
      final restored = SamplerKitXml.read(xml);

      expect(restored.name, kit.name);
      expect(restored.masterVolumeCc, 7);
      expect(restored.pads, hasLength(2));
      expect(restored.pads.first.volume, 0.6);
      expect(restored.pads.first.samplePath, 'samples/synthetic.wav');
      expect(restored.pads.first.trimSeconds, 0.02);
      expect(restored.pads.first.normalizationGain, 1.1);
      expect(restored.pads.last.samplePath, isNull);
    });

    test('resolves relative sample paths from the kit directory', () {
      final baseDirectory =
          '${Directory.systemTemp.path}${Platform.pathSeparator}kit';
      const fixture = '''
<SamplerPerreoKit formatVersion="1">
  <Pad index="0" note="60" name="Kick">
    <Sample src="samples/kick.wav" />
  </Pad>
</SamplerPerreoKit>
''';

      final kit = SamplerKitXml.read(fixture, baseDirectory: baseDirectory);
      final expectedPath = File(
        '$baseDirectory${Platform.pathSeparator}samples'
        '${Platform.pathSeparator}kick.wav',
      ).absolute.path;

      expect(kit.pads.single.samplePath, expectedPath);
    });

    test('rejects invalid indices, parameters, and versions', () {
      const duplicateIndices = '''
<PadKit>
  <Pad index="0" note="48" />
  <Pad index="0" note="49" />
</PadKit>
''';
      const invalidPan = '''
<SamplerPerreoKit>
  <Pad index="0" note="48" pan="2" />
</SamplerPerreoKit>
''';
      const invalidVolume = '''
<SamplerPerreoKit>
  <Pad index="0" note="48" volume="1.5" />
</SamplerPerreoKit>
''';
      const unsupportedVersion = '''
<SamplerPerreoKit formatVersion="2">
  <Pad index="0" note="48" />
</SamplerPerreoKit>
''';
      const invalidBoolean = '''
<SamplerPerreoKit>
  <Pad index="0" note="48" oneShot="sometimes" />
</SamplerPerreoKit>
''';

      expect(() => SamplerKitXml.read(duplicateIndices), throwsFormatException);
      expect(() => SamplerKitXml.read(invalidPan), throwsFormatException);
      expect(() => SamplerKitXml.read(invalidVolume), throwsFormatException);
      expect(
        () => SamplerKitXml.read(unsupportedVersion),
        throwsFormatException,
      );
      expect(() => SamplerKitXml.read(invalidBoolean), throwsFormatException);
    });
  });
}
