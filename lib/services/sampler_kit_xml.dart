import 'dart:io';

import 'package:xml/xml.dart';

import '../models/sampler_kit.dart';

class SamplerKitXml {
  static const _formatVersion = 1;

  static SamplerKit read(String xml, {String? baseDirectory, String? name}) {
    final document = XmlDocument.parse(xml);
    final root = document.rootElement;
    final kit = switch (root.name.local) {
      'PadKit' => _readPadKit(root, baseDirectory: baseDirectory, name: name),
      'SamplerPerreoKit' => _readSamplerPerreoKit(
          root,
          baseDirectory: baseDirectory,
          name: name,
        ),
      _ => throw FormatException(
          'Raíz XML no reconocida: ${root.name.local}',
        ),
    };
    _validate(kit);
    return kit;
  }

  static String write(SamplerKit kit) {
    _validate(kit);
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'SamplerPerreoKit',
      attributes: {
        'formatVersion': '$_formatVersion',
        'name': kit.name,
        'velocityCurve': kit.velocityCurve,
        'masterGain': kit.masterGain.toString(),
        if (kit.masterVolumeCc != null)
          'masterVolumeCC': kit.masterVolumeCc.toString(),
      },
      nest: () {
        for (final pad in kit.pads) {
          builder.element(
            'Pad',
            attributes: {
              'index': pad.index.toString(),
              'note': pad.midiNote.toString(),
              'name': pad.name,
              'volume': pad.volume.toString(),
              'gain': pad.gain.toString(),
              'pan': pad.pan.toString(),
              'oneShot': pad.oneShot ? 'true' : 'false',
              if (pad.volumeCc != null) 'volumeCC': pad.volumeCc.toString(),
              'trimSeconds': pad.trimSeconds.toString(),
              'normalizationGain': pad.normalizationGain.toString(),
            },
            nest: pad.samplePath == null
                ? null
                : () {
                    builder.element(
                      'Sample',
                      attributes: {'src': _portablePath(pad.samplePath!)},
                    );
                  },
          );
        }
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  static SamplerKit _readPadKit(
    XmlElement root, {
    required String? baseDirectory,
    required String? name,
  }) {
    final pads = root.findElements('Pad').map((element) {
      final file = element.getAttribute('file') ?? '';
      final volumeCc = _optionalInt(element, 'volumeCC');
      return SamplerKitPad(
        index: _requiredInt(element, 'index'),
        midiNote: _requiredInt(element, 'note'),
        name: element.getAttribute('name') ?? '',
        volume: 1,
        gain: _number(element, 'gain', fallback: 1),
        pan: _number(element, 'pan', fallback: 0),
        oneShot: _boolean(element.getAttribute('oneShot')),
        volumeCc: volumeCc == -1 ? null : volumeCc,
        trimSeconds: _number(element, 'trimSeconds', fallback: 0),
        normalizationGain: _number(element, 'normGain', fallback: 1),
        samplePath: file.isEmpty ? null : _resolvePath(file, baseDirectory),
      );
    }).toList(growable: false);

    return SamplerKit(
      name: name ?? 'Kit importado',
      velocityCurve: root.getAttribute('velocityCurve') ?? '0',
      masterGain: _number(root, 'masterGain', fallback: 1),
      masterVolumeCc: _optionalInt(root, 'masterCC'),
      pads: pads,
    );
  }

  static SamplerKit _readSamplerPerreoKit(
    XmlElement root, {
    required String? baseDirectory,
    required String? name,
  }) {
    final versionText = root.getAttribute('formatVersion');
    final version =
        versionText == null ? _formatVersion : int.parse(versionText);
    if (version != _formatVersion) {
      throw FormatException('Versión .spkit no compatible: $version.');
    }

    final pads = root.findElements('Pad').map((element) {
      XmlElement? sample;
      for (final child in element.findElements('Sample')) {
        sample = child;
        break;
      }
      final source = sample?.getAttribute('src');
      return SamplerKitPad(
        index: _requiredInt(element, 'index'),
        midiNote: _requiredInt(element, 'note'),
        name: element.getAttribute('name') ?? '',
        volume: _number(element, 'volume', fallback: 1),
        gain: _number(element, 'gain', fallback: 1),
        pan: _number(element, 'pan', fallback: 0),
        oneShot: _boolean(element.getAttribute('oneShot')),
        volumeCc: _optionalInt(element, 'volumeCC'),
        trimSeconds: _number(element, 'trimSeconds', fallback: 0),
        normalizationGain: _number(
          element,
          'normalizationGain',
          fallback: 1,
        ),
        samplePath: source == null || source.isEmpty
            ? null
            : _resolvePath(source, baseDirectory),
      );
    }).toList(growable: false);

    return SamplerKit(
      name: root.getAttribute('name') ?? name ?? 'Sampler Perreo kit',
      velocityCurve: root.getAttribute('velocityCurve') ?? 'linear',
      masterGain: _number(root, 'masterGain', fallback: 1),
      masterVolumeCc: _optionalInt(root, 'masterVolumeCC'),
      pads: pads,
    );
  }

  static String? _resolvePath(String path, String? baseDirectory) {
    if (_isAbsolutePath(path) || baseDirectory == null) return path;
    final normalized = path.replaceAll('/', Platform.pathSeparator);
    return File(
      '${Directory(baseDirectory).path}${Platform.pathSeparator}$normalized',
    ).absolute.path;
  }

  static bool _isAbsolutePath(String path) =>
      path.startsWith('/') ||
      path.startsWith(r'\\') ||
      RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path);

  static String _portablePath(String path) =>
      _isAbsolutePath(path) ? path : path.replaceAll('\\', '/');

  static int _requiredInt(XmlElement element, String attribute) {
    final value = element.getAttribute(attribute);
    if (value == null) {
      throw FormatException('Falta el atributo "$attribute" en <Pad>.');
    }
    return int.parse(value);
  }

  static int? _optionalInt(XmlElement element, String attribute) {
    final value = element.getAttribute(attribute);
    return value == null || value.isEmpty ? null : int.parse(value);
  }

  static double _number(
    XmlElement element,
    String attribute, {
    required double fallback,
  }) {
    final value = element.getAttribute(attribute);
    if (value == null || value.isEmpty) return fallback;
    final parsed = double.parse(value);
    if (!parsed.isFinite) {
      throw FormatException('El atributo "$attribute" debe ser finito.');
    }
    return parsed;
  }

  static bool _boolean(String? value) {
    if (value == null || value.isEmpty) return true;
    switch (value.trim().toLowerCase()) {
      case '1':
      case 'true':
        return true;
      case '0':
      case 'false':
        return false;
      default:
        throw const FormatException('oneShot debe ser true, false, 1 o 0.');
    }
  }

  static void _validate(SamplerKit kit) {
    if (kit.pads.isEmpty) {
      throw const FormatException('El kit debe contener al menos un pad.');
    }
    if (kit.pads.length > 128) {
      throw const FormatException(
        'Un kit puede contener como máximo 128 pads.',
      );
    }
    if (!kit.masterGain.isFinite || kit.masterGain < 0) {
      throw const FormatException('masterGain debe ser un número no negativo.');
    }
    if (kit.masterVolumeCc != null &&
        (kit.masterVolumeCc! < 0 || kit.masterVolumeCc! > 127)) {
      throw const FormatException('masterVolumeCC debe estar entre 0 y 127.');
    }

    final indices = <int>{};
    for (final pad in kit.pads) {
      if (pad.index < 0 || pad.index > 127 || !indices.add(pad.index)) {
        throw const FormatException(
          'Los índices de pad deben ser únicos y estar entre 0 y 127.',
        );
      }
      if (pad.midiNote < 0 || pad.midiNote > 127) {
        throw const FormatException(
          'Las notas MIDI deben estar entre 0 y 127.',
        );
      }
      if (!pad.volume.isFinite || pad.volume < 0 || pad.volume > 1) {
        throw const FormatException(
          'El volumen del pad debe estar entre 0 y 1.',
        );
      }
      if (!pad.gain.isFinite ||
          pad.gain < 0 ||
          !pad.normalizationGain.isFinite ||
          pad.normalizationGain < 0 ||
          !pad.trimSeconds.isFinite ||
          pad.trimSeconds < 0) {
        throw const FormatException(
          'Ganancia, normalización y recorte deben ser no negativos.',
        );
      }
      if (!pad.pan.isFinite || pad.pan < -1 || pad.pan > 1) {
        throw const FormatException('El paneo debe estar entre -1 y 1.');
      }
      if (pad.volumeCc != null && (pad.volumeCc! < 0 || pad.volumeCc! > 127)) {
        throw const FormatException('volumeCC debe estar entre 0 y 127.');
      }
    }
  }
}
