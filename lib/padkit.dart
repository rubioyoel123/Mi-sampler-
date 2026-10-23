import 'package:xml/xml.dart';

class PadKit {
  const PadKit({
    required this.masterGain,
    required this.masterCC,
    required this.velocityCurve,
    required this.pads,
  });

  final double masterGain;
  final int masterCC;
  final int velocityCurve;
  final List<PadKitPad> pads;

  static PadKit parse(String source) {
    final document = XmlDocument.parse(source);
    final root = document.rootElement;
    if (root.name.local != 'PadKit') {
      throw const FormatException('El archivo no tiene una raíz PadKit');
    }

    final pads = <PadKitPad>[];
    final seenIndexes = <int>{};
    for (final element in root.childElements) {
      final indexText = element.getAttribute('index');
      final file = element.getAttribute('file');
      if (indexText == null || file == null) continue;

      final index = int.tryParse(indexText);
      if (index == null || index < 0) continue;
      if (!seenIndexes.add(index)) {
        throw FormatException('Índice de pad duplicado: $index');
      }

      final note = _intAttribute(element, 'note', 60).clamp(0, 127);
      final gain = _doubleAttribute(element, 'gain', 1.0).clamp(0.0, 4.0).toDouble();
      final pan = _doubleAttribute(element, 'pan', 0.0).clamp(-1.0, 1.0).toDouble();
      final volumeCC = _intAttribute(element, 'volumeCC', -1);
      final trimSeconds = _doubleAttribute(element, 'trimSeconds', 0.0).clamp(0.0, 3600.0).toDouble();
      final normGain = _doubleAttribute(element, 'normGain', 1.0).clamp(0.0, 4.0).toDouble();
      final oneShotValue = (element.getAttribute('oneShot') ?? '1').toLowerCase();

      pads.add(PadKitPad(
        index: index,
        name: element.getAttribute('name') ?? element.name.local,
        note: note,
        gain: gain,
        pan: pan,
        oneShot: oneShotValue == '1' || oneShotValue == 'true' || oneShotValue == 'yes',
        volumeCC: volumeCC >= 0 && volumeCC <= 127 ? volumeCC : -1,
        trimSeconds: trimSeconds,
        normGain: normGain,
        file: file,
      ));
    }

    if (pads.isEmpty) {
      throw const FormatException('El kit no contiene pads con índice y archivo');
    }
    return PadKit(
      masterGain: _doubleAttribute(root, 'masterGain', 1.0).clamp(0.0, 1.0).toDouble(),
      masterCC: _intAttribute(root, 'masterCC', -1).clamp(-1, 127),
      velocityCurve: _intAttribute(root, 'velocityCurve', 0),
      pads: List.unmodifiable(pads),
    );
  }

  static int _intAttribute(XmlElement element, String name, int fallback) {
    return int.tryParse(element.getAttribute(name) ?? '') ?? fallback;
  }

  static double _doubleAttribute(XmlElement element, String name, double fallback) {
    final value = double.tryParse(element.getAttribute(name) ?? '');
    return value == null || !value.isFinite ? fallback : value;
  }
}

class PadKitPad {
  const PadKitPad({
    required this.index,
    required this.name,
    required this.note,
    required this.gain,
    required this.pan,
    required this.oneShot,
    required this.volumeCC,
    required this.trimSeconds,
    required this.normGain,
    required this.file,
  });

  final int index;
  final String name;
  final int note;
  final double gain;
  final double pan;
  final bool oneShot;
  final int volumeCC;
  final double trimSeconds;
  final double normGain;
  final String file;
}
