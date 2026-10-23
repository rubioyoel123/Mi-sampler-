import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import 'padkit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SamplerPerreoApp());
}

class SamplerPerreoApp extends StatelessWidget {
  const SamplerPerreoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sampler Perreo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101016),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.cyanAccent,
        ),
      ),
      home: const SamplerHome(),
    );
  }
}

class SamplePad {
  SamplePad({
    required this.name,
    required this.keyLabel,
    required this.color,
    required this.midiNote,
  });

  String name;
  final String keyLabel;
  final Color color;
  int midiNote;

  String? audioPath;
  String? audioName;
  double volume = 1.0;
  double pitch = 1.0;
  double pan = 0.0;
  double normGain = 1.0;
  double trimSeconds = 0.0;
  int volumeCC = -1;
  bool oneShot = true;
  bool active = false;
  SoundHandle? handle;
}

class SamplerHome extends StatefulWidget {
  const SamplerHome({super.key});

  @override
  State<SamplerHome> createState() => _SamplerHomeState();
}

class _SamplerHomeState extends State<SamplerHome> {
  final MidiCommand midi = MidiCommand();
  final FocusNode keyboardFocus = FocusNode();
  final SoLoud audio = SoLoud.instance;
  final Map<String, AudioSource> _audioCache = {};
  final Map<int, AudioSource> _pianoCache = {};
  final Map<String, AudioSource> _sk5Cache = {};
  static const List<String> _champetaPadSamples = ['conga-low.wav','conga-high.wav','timbale-low-twin.wav','timbale-high-twin.wav','cowbell.wav','shaker.wav','clave.wav','clave-low.wav','kick.wav','snare.wav','hihat.wav','laser.wav','timbale-low-twin.wav','lion.wav','clap.wav','kick-beater.wav'];
  static const List<String> _dembowPadSamples = ['kick-beater.wav','snare.wav','kick-tight-beater.wav','clap.wav','808-c.wav','808-f.wav','808-g.wav','808-long.wav','clave.wav','clave-low.wav','timbale-low-twin.wav','timbale-high-twin.wav','conga-low.wav','conga-high.wav','cowbell.wav','shaker.wav'];
  static const List<String> _sk5PadSamples = ['kick.wav','snare.wav','hihat.wav','conga_low.wav','conga_high.wav','laser.wav','dog.wav','lion.wav','kick.wav','snare.wav','hihat.wav','conga_low.wav','conga_high.wav','laser.wav','dog.wav','lion.wav'];
  static const List<String> _champetaPadLabels = ['CONGA LOW','CONGA HIGH','TIMBAL LOW','TIMBAL HIGH','COWBELL','SHAKER','CLAVE','CLAVE LOW','KICK SK-5','SNARE SK-5','HI-HAT','FX LASER','TIMBAL FX','FX LION','CLAP','KICK TIGHT'];
  static const List<String> _dembowPadLabels = ['KICK','SNARE','KICK TIGHT','CLAP','808 C','808 F','808 G','808 LONG','CLAVE','CLAVE LOW','TIMBAL LOW','TIMBAL HIGH','CONGA LOW','CONGA HIGH','COWBELL','SHAKER'];
  static const List<String> _sk5PadLabels = ['KICK','SNARE','HI-HAT','BONGO LOW','BONGO HIGH','LASER','DOG','LION','KICK 2','SNARE 2','HI-HAT 2','BONGO LOW 2','BONGO HIGH 2','LASER 2','DOG 2','LION 2'];
  final Map<int, String> pianoAudioPaths = {};
  String pianoTone = 'Piano';
  bool _audioReady = false;
  bool echoEnabled = false;
  bool reverbEnabled = false;
  bool flangerEnabled = false;
  bool showPiano = true;
  Color uiAccent = Colors.cyanAccent;
  Color uiBackground = const Color(0xFF101016);
  String uiThemeName = 'Neón';
  bool compactPads = true;
  bool showEditor = true;

  Future<void> _openSettings() async {
    const themes = <String, Color>{
      'Neón': Colors.cyanAccent,
      'Morado': Colors.purpleAccent,
      'Azul': Colors.lightBlueAccent,
      'Verde': Colors.greenAccent,
      'Rojo': Colors.redAccent,
      'Naranja': Colors.orangeAccent,
      'Rosa': Colors.pinkAccent,
      'Dorado': Colors.amberAccent,
    };
    String draftTheme = uiThemeName;
    bool draftCompact = compactPads;
    bool draftEditor = showEditor;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          backgroundColor: const Color(0xFF151C28),
          title: const Row(children: [
            Icon(Icons.tune, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('AJUSTES DE SAMPLER'),
          ]),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TEMA Y COLOR PRINCIPAL', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 9, runSpacing: 9, children: themes.entries.map((entry) =>
                    Tooltip(message: entry.key, child: InkWell(
                      onTap: () => refreshDialog(() => draftTheme = entry.key),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: entry.value, shape: BoxShape.circle,
                          border: Border.all(color: draftTheme == entry.key ? Colors.white : Colors.white24, width: draftTheme == entry.key ? 3 : 1),
                        ),
                        child: draftTheme == entry.key ? const Icon(Icons.check, color: Colors.black, size: 19) : null,
                      ),
                    ))).toList()),
                  const SizedBox(height: 8),
                  Text('Tema seleccionado: $draftTheme', style: const TextStyle(color: Colors.white70)),
                  const Divider(height: 26),
                  const Text('DISTRIBUCIÓN', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero, dense: true,
                    title: const Text('Pads compactos'),
                    subtitle: const Text('Evita que los pads se vean demasiado grandes'),
                    value: draftCompact,
                    onChanged: (v) => refreshDialog(() => draftCompact = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero, dense: true,
                    title: const Text('Mostrar editor de audio'),
                    value: draftEditor,
                    onChanged: (v) => refreshDialog(() => draftEditor = v),
                  ),
                  const Text('También puedes mostrar u ocultar el piano desde el menú principal.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
            FilledButton.icon(
              onPressed: () async {
                setState(() {
                  uiThemeName = draftTheme;
                  uiAccent = themes[draftTheme] ?? Colors.cyanAccent;
                  compactPads = draftCompact;
                  showEditor = draftEditor;
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('uiThemeName', draftTheme);
                await prefs.setBool('compactPads', draftCompact);
                await prefs.setBool('showEditor', draftEditor);
                if (mounted) _showStatus('Apariencia actualizada: $draftTheme');
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.check), label: const Text('APLICAR'),
            ),
          ],
        ),
      ),
    );
  }

  int editorPadIndex = 0;
  double echoDelay = 0.28;
  double echoDecay = 0.35;
  double reverbRoom = 0.65;
  double reverbDamp = 0.35;
  double flangerAmount = 0.5;
  double editorIn = 0.0;
  double editorOut = 1.0;

  final List<List<SamplePad>> banks = List.generate(
    4,
    (bank) => List.generate(
      16,
      (i) => SamplePad(
      name: 'PAD ${i + 1}',
      keyLabel: const [
        '1', '2', '3', '4',
        'Q', 'W', 'E', 'R',
        'A', 'S', 'D', 'F',
        'Z', 'X', 'C', 'V',
      ][i],
      color: Colors.primaries[i % Colors.primaries.length],
      midiNote: 36 + i,
      ),
    ),
  );

  List<SamplePad> get pads => banks[selectedBank];

  StreamSubscription<MidiDataReceivedEvent>? midiSubscription;

  double masterVolume = 0.8;
  int masterVolumeCC = -1;
  double masterPitch = 1.0;
  int selectedBank = 0;
  String status = 'Listo para mezclar';
  List<MidiDevice> midiDevices = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initAudio();
    _initMidi();
  }

  @override
  void dispose() {
    midiSubscription?.cancel();
    keyboardFocus.dispose();

    for (final bank in banks) {
      for (final pad in bank) {
        // Las fuentes se liberan al cerrar el motor.
      }
    }

    if (_audioReady) { audio.deinit(); }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        masterVolume = prefs.getDouble('masterVolume') ?? 0.8;
        masterVolumeCC = prefs.getInt('masterVolumeCC') ?? -1;
        uiThemeName = prefs.getString('uiThemeName') ?? 'Neón';
        const savedThemes = {'Neón': Colors.cyanAccent, 'Morado': Colors.purpleAccent, 'Azul': Colors.lightBlueAccent, 'Verde': Colors.greenAccent, 'Rojo': Colors.redAccent, 'Naranja': Colors.orangeAccent, 'Rosa': Colors.pinkAccent, 'Dorado': Colors.amberAccent};
        uiAccent = savedThemes[uiThemeName] ?? Colors.cyanAccent;
        compactPads = prefs.getBool('compactPads') ?? true;
        showEditor = prefs.getBool('showEditor') ?? true;
        masterPitch = prefs.getDouble('masterPitch') ?? 1.0;
        pianoTone = prefs.getString('pianoTone') ?? 'Piano';
        for (int note = 48; note <= 84; note++) {
          final path = prefs.getString('piano_note_$note');
          if (path != null) pianoAudioPaths[note] = path;
        }

        selectedBank = (prefs.getInt('selectedBank') ?? 0).clamp(0, 3);
        echoEnabled = prefs.getBool('fx_echo') ?? false;
        reverbEnabled = prefs.getBool('fx_reverb') ?? false;
        flangerEnabled = prefs.getBool('fx_flanger') ?? false;
        for (int b = 0; b < banks.length; b++) {
          for (int i = 0; i < banks[b].length; i++) {
            final pad = banks[b][i];
            final key = 'bank_${b}_pad_$i';
            pad.audioPath = prefs.getString(key);
            pad.audioName = prefs.getString('${key}_name');
            pad.volume = prefs.getDouble('${key}_volume') ?? 1.0;
            pad.pitch = prefs.getDouble('${key}_pitch') ?? 1.0;
            pad.name = prefs.getString('${key}_label') ?? pad.name;
            pad.midiNote = prefs.getInt('${key}_note') ?? pad.midiNote;
            pad.pan = prefs.getDouble('${key}_pan') ?? 0.0;
            pad.normGain = prefs.getDouble('${key}_norm_gain') ?? 1.0;
            pad.trimSeconds = prefs.getDouble('${key}_trim_seconds') ?? 0.0;
            pad.volumeCC = prefs.getInt('${key}_volume_cc') ?? -1;
            pad.oneShot = prefs.getBool('${key}_one_shot') ?? true;
          }
        }
      });
    } catch (e) {
      _showStatus('Error al cargar ajustes: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble('masterVolume', masterVolume);
      await prefs.setInt('masterVolumeCC', masterVolumeCC);
      await prefs.setDouble('masterPitch', masterPitch);
      await prefs.setString('pianoTone', pianoTone);
      for (int note = 48; note <= 84; note++) {
        final path = pianoAudioPaths[note];
        if (path == null) {
          await prefs.remove('piano_note_$note');
        } else {
          await prefs.setString('piano_note_$note', path);
        }
      }
      await prefs.setInt('selectedBank', selectedBank);
      await prefs.setBool('fx_echo', echoEnabled);
      await prefs.setBool('fx_reverb', reverbEnabled);
      await prefs.setBool('fx_flanger', flangerEnabled);

      for (int b = 0; b < banks.length; b++) {
        for (int i = 0; i < banks[b].length; i++) {
          final pad = banks[b][i];
          final key = 'bank_${b}_pad_$i';
          if (pad.audioPath != null) {
            await prefs.setString(key, pad.audioPath!);
          } else {
            await prefs.remove(key);
          }
          if (pad.audioName != null) {
            await prefs.setString('${key}_name', pad.audioName!);
          } else {
            await prefs.remove('${key}_name');
          }
          await prefs.setDouble('${key}_volume', pad.volume);
          await prefs.setDouble('${key}_pitch', pad.pitch);
          await prefs.setString('${key}_label', pad.name);
          await prefs.setInt('${key}_note', pad.midiNote);
          await prefs.setDouble('${key}_pan', pad.pan);
          await prefs.setDouble('${key}_norm_gain', pad.normGain);
          await prefs.setDouble('${key}_trim_seconds', pad.trimSeconds);
          await prefs.setInt('${key}_volume_cc', pad.volumeCC);
          await prefs.setBool('${key}_one_shot', pad.oneShot);
        }
      }
    } catch (e) {
      _showStatus('Error al guardar: $e');
    }
  }

  Future<void> _initAudio() async {
    try {
      await audio.init();
      audio.setMaxActiveVoiceCount(64);
      if (!mounted) return;
      setState(() {
        _audioReady = true;
        status = 'Motor de audio listo · SoLoud';
      });
      _applyEffects();
    } catch (e) {
      _showStatus('No se pudo iniciar el motor de audio: $e');
    }
  }

  void _applyEffects() {
    if (!_audioReady) return;
    final filters = audio.filters;
    filters.echoFilter.delay.value = echoDelay;
    filters.echoFilter.decay.value = echoDecay;
    if (echoEnabled) { filters.echoFilter.activate(); } else { filters.echoFilter.deactivate(); }
    filters.freeverbFilter.roomSize.value = reverbRoom;
    filters.freeverbFilter.damp.value = reverbDamp;
    if (reverbEnabled) { filters.freeverbFilter.activate(); } else { filters.freeverbFilter.deactivate(); }
    if (flangerEnabled && flangerAmount > 0.01) { filters.flangerFilter.activate(); } else { filters.flangerFilter.deactivate(); }
  }

  Future<void> _initMidi() async {
    try {
      midiDevices = await midi.devices ?? [];

      midiSubscription = midi.onMidiDataReceived?.listen((event) {
        final message = event.message;

        if (message is CCMessage) {
          final value = (message.value / 127.0).clamp(0.0, 1.0).toDouble();
          var changed = false;
          if (masterVolumeCC == message.controller) {
            masterVolume = value;
            changed = true;
          }
          for (final pad in banks.expand((bank) => bank)) {
            if (pad.volumeCC == message.controller) {
              pad.volume = value;
              changed = true;
            }
          }
          if (changed) {
            if (mounted) setState(() {});
            _saveSettings();
          }
          return;
        }

        if (message is! NoteOnMessage || message.velocity <= 0) {
          return;
        }

        final index = pads.indexWhere((pad) => pad.midiNote == message.note);
        if (index != -1) {
          _playPad(index, velocity: message.velocity / 127.0);
        } else if (message.note >= 48 && message.note <= 84) {
          _playPianoNote(message.note);
        }
      });

      if (mounted) {
        setState(() {
          status = midiDevices.isEmpty
              ? 'Listo · Conecta tu controlador MIDI'
              : '${midiDevices.length} dispositivo(s) MIDI detectado(s)';
        });
      }
    } catch (e) {
      _showStatus('MIDI no disponible: $e');
    }
  }

  void _showStatus(String message) {
    if (!mounted) return;
    setState(() => status = message);
  }

  Future<String> _copyAudioToLibrary(String sourcePath) async {
    final directory = await getApplicationSupportDirectory();
    final library = Directory('${directory.path}/sampler_audio');

    if (!await library.exists()) {
      await library.create(recursive: true);
    }

    final source = File(sourcePath);
    final fileName = source.uri.pathSegments.last;
    final destination = File(
      '${library.path}/${DateTime.now().microsecondsSinceEpoch}_$fileName',
    );

    await source.copy(destination.path);
    return destination.path;
  }

  Future<void> _loadAudio(int index) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.audio,
      );

      if (files.isEmpty || files.first.path == null) {
  _showStatus('No seleccionaste ningún audio');
  return;
}

final selectedFile = files.first;
      final copiedPath = await _copyAudioToLibrary(selectedFile.path!);

      setState(() {
        pads[index].audioPath = copiedPath;
        pads[index].audioName = selectedFile.name;
      });

      await _saveSettings();
      _showStatus('Audio cargado en ${pads[index].name}');
    } catch (e) {
      _showStatus('No se pudo cargar el audio: $e');
    }
  }

  Future<void> _importPadKit() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['padkit'],
      );
      if (files.isEmpty || files.first.path == null) {
        _showStatus('No seleccionaste ningún kit');
        return;
      }

      final kitFile = File(files.first.path!);
      final kit = PadKit.parse(await kitFile.readAsString());
      final importable = kit.pads.where((pad) => pad.index >= 0 && pad.index < 64).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      if (importable.isEmpty) {
        _showStatus('El kit no contiene pads compatibles');
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF171D29),
          title: const Text('Importar kit .padkit'),
          content: Text(
            'Se reemplazarán los pads de los cuatro bancos. '
            'Se importarán ${importable.length} de ${kit.pads.length} pads del kit.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('IMPORTAR'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      for (var bankIndex = 0; bankIndex < banks.length; bankIndex++) {
        for (var padIndex = 0; padIndex < banks[bankIndex].length; padIndex++) {
          final pad = banks[bankIndex][padIndex];
          if (pad.handle != null && _audioReady) {
            audio.stop(pad.handle!);
            pad.handle = null;
          }
          pad.name = 'PAD ${padIndex + 1}';
          pad.midiNote = 36 + padIndex;
          pad.audioPath = null;
          pad.audioName = null;
          pad.volume = 1.0;
          pad.pan = 0.0;
          pad.normGain = 1.0;
          pad.trimSeconds = 0.0;
          pad.volumeCC = -1;
          pad.oneShot = true;
          pad.active = false;
        }
      }

      var loadedAudio = 0;
      var missingAudio = 0;
      for (final kitPad in importable) {
        final bankIndex = kitPad.index ~/ 16;
        final padIndex = kitPad.index % 16;
        final pad = banks[bankIndex][padIndex];
        pad.name = kitPad.name.isEmpty ? 'PAD ${padIndex + 1}' : kitPad.name;
        pad.midiNote = kitPad.note;
        pad.volume = kitPad.gain.clamp(0.0, 1.0).toDouble();
        pad.pan = kitPad.pan.clamp(-1.0, 1.0).toDouble();
        pad.normGain = kitPad.normGain.clamp(0.0, 4.0).toDouble();
        pad.trimSeconds = kitPad.trimSeconds;
        pad.volumeCC = kitPad.volumeCC;
        pad.oneShot = kitPad.oneShot;

        final sourcePath = await _resolveKitAudioPath(kitFile, kitPad.file);
        if (sourcePath == null) {
          if (kitPad.file.isNotEmpty) missingAudio++;
          continue;
        }
        pad.audioPath = await _copyAudioToLibrary(sourcePath);
        pad.audioName = kitPad.name;
        loadedAudio++;
      }

      masterVolume = kit.masterGain.clamp(0.0, 1.0).toDouble();
      masterVolumeCC = kit.masterCC;
      selectedBank = 0;
      await _saveSettings();
      if (mounted) setState(() {});
      _showStatus(
        'Kit importado: ${importable.length} pads, $loadedAudio audios cargados'
        '${missingAudio > 0 ? ', $missingAudio audios no encontrados' : ''}'
        '${kit.pads.length > 64 ? ' · se omitieron pads fuera del rango 1–64' : ''}',
      );
    } catch (e) {
      _showStatus('No se pudo importar el kit .padkit: $e');
    }
  }

  Future<String?> _resolveKitAudioPath(File kitFile, String reference) async {
    if (reference.trim().isEmpty) return null;
    final isWindowsAbsolute = reference.length >= 3 &&
        reference[1] == ':' &&
        (reference[2] == r'\' || reference[2] == '/');
    final isAbsolute = isWindowsAbsolute || reference.startsWith(r'\\') || reference.startsWith('/');
    final normalized = reference
        .replaceAll(r'\', Platform.pathSeparator)
        .replaceAll('/', Platform.pathSeparator);
    final candidates = <String>[];
    if (isAbsolute) candidates.add(reference);
    if (!isAbsolute) {
      candidates.add('${kitFile.parent.path}${Platform.pathSeparator}$normalized');
    }
    final fileName = reference.replaceAll(r'\', '/').split('/').last;
    if (fileName.isNotEmpty) {
      candidates.add('${kitFile.parent.path}${Platform.pathSeparator}$fileName');
    }

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) return file.path;
    }
    return null;
  }

  Future<void> _playPad(int index, {double velocity = 1.0}) async {
    final pad = pads[index];

    if (pad.audioPath == null) {
      await _playBundledSample(index);
      return;
    }

    try {
      if (!_audioReady) {
        _showStatus('El motor de audio todavía está iniciando');
        return;
      }
      var source = _audioCache[pad.audioPath!];
      if (source == null) {
        source = await audio.loadFile(pad.audioPath!);
        _audioCache[pad.audioPath!] = source;
      }
      final handle = audio.play(
        source,
        volume: (masterVolume * pad.volume * pad.normGain * velocity).clamp(0.0, 1.0),
        pan: pad.pan.clamp(-1.0, 1.0),
        looping: !pad.oneShot,
      );
      pad.handle = handle;
      if (pad.trimSeconds > 0) {
        audio.seek(handle, Duration(milliseconds: (pad.trimSeconds * 1000).round()));
      }
      audio.setRelativePlaySpeed(
        handle,
        (masterPitch * pad.pitch).clamp(0.5, 2.0),
      );
      if (mounted) setState(() => pad.active = true);
      _showStatus('Reproduciendo ${pad.name}');
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => pad.active = false);
      });
    } catch (e) {
      _showStatus('Error al reproducir: $e');
    }
  }

  String _padLabel(int index) {
    final importedName = pads[index].name;
    if (importedName != 'PAD ${index + 1}') return importedName;
    switch (selectedBank) {
      case 0: return _champetaPadLabels[index % _champetaPadLabels.length];
      case 1: return _dembowPadLabels[index % _dembowPadLabels.length];
      case 2: return _sk5PadLabels[index % _sk5PadLabels.length];
      default: return 'PAD ${index + 1}';
    }
  }

  Future<void> _playBundledSample(int index) async {
    if (!_audioReady) {
      _showStatus('El motor de audio todavía está iniciando');
      return;
    }
    late final String bankName;
    late final String folder;
    late final String sample;
    switch (selectedBank) {
      case 0:
        bankName = 'CHAMPETA';
        folder = 'champeta';
        sample = _champetaPadSamples[index % _champetaPadSamples.length];
        break;
      case 1:
        bankName = 'DEMBOW';
        folder = 'dembow';
        sample = _dembowPadSamples[index % _dembowPadSamples.length];
        break;
      case 2:
        bankName = 'CASIO SK-5';
        folder = 'sk5';
        sample = _sk5PadSamples[index % _sk5PadSamples.length];
        break;
      default:
        _showStatus('Banco personal: carga un audio en el PAD ${index + 1}');
        return;
    }
    final assetPath = 'assets/$folder/$sample';
    try {
      var source = _sk5Cache[assetPath];
      if (source == null) {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        source = await audio.loadMem('${folder}_$sample', bytes, mode: LoadMode.memory);
        _sk5Cache[assetPath] = source;
      }
      final pad = pads[index];
      final handle = audio.play(source, volume: (masterVolume * pad.volume).clamp(0.0, 1.0));
      pad.handle = handle;
      audio.setRelativePlaySpeed(handle, (masterPitch * pad.pitch).clamp(0.5, 2.0));
      if (mounted) setState(() => pad.active = true);
      _showStatus('$bankName · ${sample.replaceAll('.wav', '').replaceAll('-', ' ').toUpperCase()} · PAD ${index + 1}');
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => pad.active = false);
      });
    } catch (e) {
      _showStatus('No se pudo cargar $bankName ($sample): $e');
    }
  }

  // Genera sonidos WAV dentro de la propia aplicación: no requiere descargar muestras.
  Uint8List _makeToneWav(int midiNote, {required bool electronic}) {
    const sampleRate = 22050;
    const seconds = 1.2;
    const bitsPerSample = 16;
    final sampleCount = (sampleRate * seconds).round();
    final dataSize = sampleCount * 2;
    final bytes = ByteData(44 + dataSize);
    final frequency = 440.0 * math.pow(2.0, (midiNote - 69) / 12.0);
    void writeAscii(int offset, String value) {
      for (int i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }
    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);
    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final phase = 2 * math.pi * frequency * t;
      double wave;
      if (electronic) {
        wave = (2 / math.pi) * math.asin(math.sin(phase));
      } else {
        wave = math.sin(phase) * 0.68 + math.sin(phase * 2) * 0.22 + math.sin(phase * 3) * 0.10;
      }
      final attack = (t / 0.015).clamp(0.0, 1.0);
      final envelope = electronic
          ? attack * (0.82 + 0.18 * math.exp(-t * 1.4))
          : attack * math.exp(-t * 2.4);
      final sample = (wave * envelope * 0.72 * 32767).round().clamp(-32768, 32767).toInt();
      bytes.setInt16(44 + i * 2, sample, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  Future<void> _playPianoNote(int note) async {
    if (!_audioReady) {
      _showStatus('El motor de audio todavía está iniciando');
      return;
    }
    try {
      AudioSource? source = _pianoCache[note];
      final customPath = pianoAudioPaths[note];
      if (source == null) {
        if (customPath != null && await File(customPath).exists()) {
          source = await audio.loadFile(customPath);
        } else {
          source = await audio.loadMem(
            'sampler_perreo_${pianoTone.toLowerCase()}_$note.wav',
            _makeToneWav(note, electronic: pianoTone == 'Electrónico'),
            mode: LoadMode.memory,
          );
        }
        _pianoCache[note] = source;
      }
      audio.play(source, volume: masterVolume);
      _showStatus('${pianoTone.toUpperCase()} · nota MIDI $note');
    } catch (e) {
      _showStatus('No se pudo reproducir la nota: $e');
    }
  }

  Future<void> _loadPianoAudio(int note) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.audio);
      if (result.isEmpty || result.first.path == null) {
        _showStatus('No seleccionaste ningún audio');
        return;
      }
      final copiedPath = await _copyAudioToLibrary(result.first.path!);
      pianoAudioPaths[note] = copiedPath;
      final oldSource = _pianoCache.remove(note);
      if (oldSource != null && _audioReady) {
        await audio.disposeSource(oldSource);
      }
      await _saveSettings();
      if (mounted) setState(() {});
      _showStatus('Audio personalizado asignado a la nota MIDI $note');
    } catch (e) {
      _showStatus('No se pudo asignar el audio: $e');
    }
  }

  Future<void> _stopAll() async {
    for (final bank in banks) {
      for (final pad in bank) {
        if (pad.handle != null && _audioReady) { audio.stop(pad.handle!); pad.handle = null; }
      }
    }

    if (mounted) {
      setState(() {
        for (final bank in banks) {
          for (final pad in bank) {
            pad.active = false;
          }
        }
        status = 'Todos los audios detenidos';
      });
    }
  }

  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent || event.repeat) return;

    final key = event.logicalKey.keyLabel.toUpperCase();
    final index = pads.indexWhere((pad) => pad.keyLabel == key);

    if (index != -1) _playPad(index);
  }

  Future<void> _clearPad(int index) async {
    if (pads[index].handle != null && _audioReady) { audio.stop(pads[index].handle!); pads[index].handle = null; }

    setState(() {
      pads[index].audioPath = null;
      pads[index].audioName = null;
      pads[index].active = false;
    });

    await _saveSettings();
    _showStatus('Audio eliminado del pad ${index + 1}');
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: keyboardFocus,
      autofocus: true,
      onKey: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'SAMPLER PERREO',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          backgroundColor: const Color(0xFF191923),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Center(
                child: Text(
                  'DJ DANNYS YOEL',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.28),
                    fontSize: 7,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Detener todos los audios',
              onPressed: _stopAll,
              icon: const Icon(
                Icons.stop_circle,
                color: Colors.redAccent,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Menú de Sampler Perreo',
              color: const Color(0xFF171D29),
              icon: const Icon(Icons.menu, color: Colors.cyanAccent),
              onSelected: (choice) {
                if (choice == 'settings') _openSettings();
                if (choice == 'save') _saveSettings();
                if (choice == 'stop') _stopAll();
                if (choice == 'piano') setState(() => showPiano = !showPiano);
                if (choice == 'load') _loadAudio(editorPadIndex);
                if (choice == 'kit') _importPadKit();
                if (choice == 'midi') _showMidiDevices();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'settings', child: ListTile(
                  dense: true, leading: Icon(Icons.tune, color: Colors.cyanAccent),
                  title: Text('Apariencia y opciones'))),
                PopupMenuItem(value: 'save', child: ListTile(
                  dense: true, leading: Icon(Icons.save, color: Colors.cyanAccent),
                  title: Text('Guardar ajustes'))),
                PopupMenuItem(value: 'load', child: ListTile(
                  dense: true, leading: Icon(Icons.audio_file, color: Colors.cyanAccent),
                  title: Text('Cargar audio al pad seleccionado'))),
                PopupMenuItem(value: 'kit', child: ListTile(
                  dense: true, leading: Icon(Icons.library_add, color: Colors.cyanAccent),
                  title: Text('Importar kit .padkit a los cuatro bancos'))),
                PopupMenuItem(value: 'piano', child: ListTile(
                  dense: true, leading: Icon(Icons.piano, color: Colors.cyanAccent),
                  title: Text('Mostrar / ocultar piano'))),
                PopupMenuItem(value: 'midi', child: ListTile(
                  dense: true, leading: Icon(Icons.piano, color: Colors.cyanAccent),
                  title: Text('Dispositivos MIDI'))),
                PopupMenuItem(value: 'stop', child: ListTile(
                  dense: true, leading: Icon(Icons.stop_circle, color: Colors.redAccent),
                  title: Text('Detener todos los audios'))),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 720 || constraints.maxWidth < 1000;
              return Column(
                children: [
                  SizedBox(
                    height: compact ? 62 : 74,
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: _buildMasterControls(compact: compact)),
                        Expanded(flex: 4, child: _buildBankSelector()),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: _buildPads(compact: compact)),
                        if (showEditor)
                          Expanded(flex: compact ? 3 : 4, child: _buildAudioEditorPanel()),
                      ],
                    ),
                  ),
                  _buildEffectsPanel(compact: compact),
                  if (showPiano) _buildVirtualPiano(compact: compact),
                  SizedBox(
                    height: compact ? 28 : 34,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => setState(() => showPiano = !showPiano),
                        icon: Icon(showPiano ? Icons.keyboard_hide : Icons.piano, color: uiAccent, size: 16),
                        label: Text(
                          showPiano ? 'OCULTAR PIANO' : 'MOSTRAR PIANO',
                          style: TextStyle(color: uiAccent, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  _buildStatusBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showMidiDevices() async {
    try {
      midiDevices = await midi.devices ?? [];
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF171D29),
          title: const Text('Dispositivos MIDI'),
          content: SizedBox(
            width: 340,
            child: midiDevices.isEmpty
                ? const Text('No se detectan dispositivos MIDI. Conecta tu controlador y vuelve a abrir este menú.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: midiDevices.map((device) => ListTile(
                      leading: const Icon(Icons.piano, color: Colors.cyanAccent),
                      title: Text(device.name ?? 'Controlador MIDI'),
                      subtitle: Text(device.id ?? ''),
                    )).toList(),
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR'))],
        ),
      );
    } catch (e) {
      _showStatus('No se pudieron consultar dispositivos MIDI: $e');
    }
  }

  Widget _buildMasterControls({bool compact = false}) {
    return Container(
      margin: EdgeInsets.fromLTRB(compact ? 5 : 10, 4, 5, 4),
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 12, vertical: compact ? 4 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF191923),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'CONTROLES MAESTROS',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
          RotaryKnob(
            compact: compact,
            label: 'VOLUMEN',
            value: masterVolume,
            min: 0,
            max: 1,
            display: '${(masterVolume * 100).round()}%',
            onChanged: (value) {
              setState(() => masterVolume = value);
              _saveSettings();
            },
          ),
          SizedBox(width: compact ? 3 : 14),
          RotaryKnob(
            compact: compact,
            label: 'PITCH',
            value: masterPitch,
            min: 0.5,
            max: 2,
            display: '${masterPitch.toStringAsFixed(2)}x',
            onChanged: (value) {
              setState(() => masterPitch = value);
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEffectsPanel({bool compact = false}) {
    Widget knob(String label, double value, double min, double max,
        ValueChanged<double> change, String display, Color color) => Expanded(
      child: RotaryKnob(
        compact: true,
        label: label,
        value: value,
        min: min,
        max: max,
        display: display,
        accent: color,
        onChanged: (v) {
          setState(() => change(v));
          _applyEffects();
        },
      ),
    );
    return Container(
      margin: EdgeInsets.fromLTRB(compact ? 5 : 10, 2, compact ? 5 : 10, 3),
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 4 : 7),
      decoration: BoxDecoration(color: const Color(0xFF14141C),
        borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EFECTOS MAESTROS',
          style: TextStyle(color: uiAccent, fontSize: compact ? 9 : 10, fontWeight: FontWeight.bold)),
        Row(children: [
          knob('ECO DELAY', echoDelay, 0.05, 1.0, (v) { echoDelay = v; echoEnabled = true; },
            '${echoDelay.toStringAsFixed(2)} s', Colors.purpleAccent),
          knob('ECO DECAY', echoDecay, 0.0, 1.0, (v) { echoDecay = v; echoEnabled = true; },
            '${(echoDecay * 100).round()}%', Colors.purpleAccent),
          knob('REVERB ROOM', reverbRoom, 0.0, 1.0, (v) { reverbRoom = v; reverbEnabled = true; },
            '${(reverbRoom * 100).round()}%', Colors.cyanAccent),
          knob('REVERB DAMP', reverbDamp, 0.0, 1.0, (v) { reverbDamp = v; reverbEnabled = true; },
            '${(reverbDamp * 100).round()}%', Colors.cyanAccent),
          knob('FLANGER', flangerAmount, 0.0, 1.0, (v) { flangerAmount = v; flangerEnabled = v > 0.01; },
            '${(flangerAmount * 100).round()}%', Colors.orangeAccent),
        ]),
        Row(
          children: [
            _effectToggle('ECO', echoEnabled, (v) {
              setState(() => echoEnabled = v);
              _applyEffects();
              _saveSettings();
            }),
            _effectToggle('REVERB', reverbEnabled, (v) {
              setState(() => reverbEnabled = v);
              _applyEffects();
              _saveSettings();
            }),
            _effectToggle('FLANGER', flangerEnabled, (v) {
              setState(() => flangerEnabled = v);
              _applyEffects();
              _saveSettings();
            }),
          ],
        ),
      ]),
    );
  }

  Widget _effectToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            Flexible(
              child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70)),
            ),
            Transform.scale(
              scale: 0.68,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: uiAccent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioEditorPanel() {
    final pad = pads[editorPadIndex.clamp(0, pads.length - 1).toInt()];
    return Container(
      margin: const EdgeInsets.fromLTRB(3, 6, 10, 8), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF101018),
        borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.65))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.graphic_eq, color: Colors.purpleAccent, size: 17),
          const SizedBox(width: 5),
          Expanded(child: Text('EDITOR · ${pad.audioName ?? pad.name}', maxLines: 1,
            overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 11))),
          DropdownButton<int>(value: editorPadIndex, dropdownColor: const Color(0xFF20202B),
            items: List.generate(pads.length, (i) => DropdownMenuItem(value: i,
              child: Text('PAD ${i + 1}', style: const TextStyle(fontSize: 10)))),
            onChanged: (v) { if (v != null) setState(() => editorPadIndex = v); }),
        ]),
        const SizedBox(height: 5),
        Expanded(child: Container(decoration: BoxDecoration(color: const Color(0xFF08080D),
          border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(6)),
          child: CustomPaint(painter: _EditorWavePainter(inPoint: editorIn, outPoint: editorOut),
            child: const SizedBox.expand()))),
        Text('IN ${(editorIn * 100).round()}%     OUT ${(editorOut * 100).round()}%',
          style: const TextStyle(color: Colors.white70, fontSize: 10)),
        Row(children: [const Text('IN', style: TextStyle(color: Colors.purpleAccent, fontSize: 10)),
          Expanded(child: Slider(value: editorIn, min: 0, max: (editorOut - 0.02).clamp(0.0, 1.0).toDouble(),
            activeColor: Colors.purpleAccent, onChanged: (v) => setState(() => editorIn = v)))]),
        Row(children: [const Text('OUT', style: TextStyle(color: Colors.blueAccent, fontSize: 10)),
          Expanded(child: Slider(value: editorOut, min: (editorIn + 0.02).clamp(0.0, 1.0).toDouble(), max: 1,
            activeColor: Colors.blueAccent, onChanged: (v) => setState(() => editorOut = v)))]),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: pad.audioPath == null ? null : () => _playPad(editorPadIndex),
            icon: const Icon(Icons.play_arrow, size: 16), label: const Text('ESCUCHAR', style: TextStyle(fontSize: 10)))),
          const SizedBox(width: 5),
          Expanded(child: OutlinedButton.icon(onPressed: pad.audioPath == null ? null : () => _showStatus(
            'Selección marcada: IN ${editorIn.toStringAsFixed(2)} · OUT ${editorOut.toStringAsFixed(2)}. El recorte destructivo aún no está implementado.'),
            icon: const Icon(Icons.content_cut, size: 16), label: const Text('MARCAR CORTE', style: TextStyle(fontSize: 10)))),
        ]),
        const Text('Vista de forma de onda ilustrativa; el recorte/exportación real de selección queda pendiente.',
          style: TextStyle(color: Colors.white54, fontSize: 9)),
      ]),
    );
  }

  Widget _buildVirtualPiano({bool compact = false}) {
    const labels = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];
    return Container(
      height: compact ? 62 : 86,
      margin: EdgeInsets.symmetric(horizontal: compact ? 5 : 8, vertical: 1),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF12121A), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
      child: Row(children: [
        SizedBox(width: 92, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('PIANO VIRTUAL', textAlign: TextAlign.center, style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          DropdownButton<String>(value: pianoTone, isDense: true, dropdownColor: const Color(0xFF20202B),
            items: const [DropdownMenuItem(value: 'Piano', child: Text('Piano', style: TextStyle(fontSize: 10))), DropdownMenuItem(value: 'Electrónico', child: Text('Electrónico', style: TextStyle(fontSize: 10)))],
            onChanged: (v) { if (v != null) { setState(() { pianoTone = v; _pianoCache.clear(); }); _saveSettings(); } }),
        ])),
        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: List.generate(25, (i) {
          final note = 60 + i;
          final isBlack = const [1, 3, 6, 8, 10].contains(note % 12);
          final custom = pianoAudioPaths.containsKey(note);
          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: Tooltip(
            message: 'MIDI $note · Mantén pulsado para cargar un audio propio',
            child: Material(color: isBlack ? const Color(0xFF343443) : Colors.white, borderRadius: BorderRadius.circular(3),
              child: InkWell(onTap: () => _playPianoNote(note), onLongPress: () => _loadPianoAudio(note),
                child: Stack(children: [
                  Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(labels[note % 12], style: TextStyle(color: isBlack ? Colors.white : Colors.black, fontSize: 8)))),
                  if (custom) const Positioned(top: 2, right: 2, child: Icon(Icons.music_note, size: 9, color: Colors.green)),
                ])),
            ),
          )));
        }))),
      ]),
    );
  }

  Widget _buildBankSelector() {
    const bankLabels = ['CHAMP', 'DEMB', 'SK-5', 'USER'];
    const fullNames = ['Champeta', 'Dembow', 'Casio SK-5', 'Personal'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          const Text('BANCO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 5),
          for (int i = 0; i < 4; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: selectedBank == i ? Colors.deepPurpleAccent : const Color(0xFF292936),
                    ),
                    onPressed: () {
                      setState(() => selectedBank = i);
                      _saveSettings();
                      _showStatus('${fullNames[i]} seleccionado · 16 pads independientes');
                    },
                    child: Text(bankLabels[i], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPads({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 5 : 8, 3, compact ? 4 : 8, 4),
      child: GridView.builder(
        itemCount: pads.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: compact ? (compactPads ? 2.0 : 1.45) : (compactPads ? 1.75 : 1.2),
        ),
        itemBuilder: (context, index) {
          final pad = pads[index];
          final hasAudio = pad.audioPath != null;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: pad.active
                  ? pad.color.withOpacity(0.85)
                  : pad.color.withOpacity(hasAudio ? 0.20 : 0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: pad.color,
                width: pad.active ? 2.5 : 1,
              ),
              boxShadow: pad.active
                  ? [
                      BoxShadow(
                        color: pad.color.withOpacity(0.5),
                        blurRadius: 12,
                      ),
                    ]
                  : [],
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 3 : 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _padLabel(index),
                          style: TextStyle(
                            fontSize: compact ? 9 : 11,
                            fontWeight: FontWeight.bold,
                            color: pad.color,
                          ),
                        ),
                      ),
                      if (hasAudio)
                        InkWell(
                          onTap: () => _clearPad(index),
                          child: const Icon(
                            Icons.close,
                            size: 15,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _playPad(index),
                      child: Center(
                        child: Icon(
                          hasAudio ? Icons.music_note : Icons.library_music,
                          size: compact ? 15 : 19,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: compact ? 19 : 23,
                    child: ElevatedButton.icon(
                      onPressed: () => _loadAudio(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasAudio
                            ? const Color(0xFF292936)
                            : Colors.deepPurpleAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        hasAudio ? Icons.refresh : Icons.add,
                        size: 13,
                      ),
                      label: Text(
                        hasAudio ? 'CAMBIAR AUDIO' : 'CARGAR AUDIO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: compact ? 7 : 9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasAudio
                        ? (pad.audioName ?? 'Audio cargado')
                        : 'Tecla ${pad.keyLabel} · MIDI ${pad.midiNote}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 7 : 9,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: const Color(0xFF191923),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 11,
        ),
      ),
    );
  }
}

class RotaryKnob extends StatelessWidget {
  const RotaryKnob({
    super.key,
    this.compact = false,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.accent = Colors.cyanAccent,
  });

  final bool compact;
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final next = (value - details.delta.dy * (max - min) / 150)
            .clamp(min, max)
            .toDouble();
        onChanged(next);
      },
      onDoubleTap: () => onChanged(
        label == 'PITCH' ? 1.0 : 0.8,
      ),
      child: SizedBox(
        width: compact ? 42 : 54,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 7 : 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: compact ? 1 : 3),
            CustomPaint(
              size: Size.square(compact ? 25 : 34),
              painter: KnobPainter(
                progress: ((value - min) / (max - min)).clamp(0.0, 1.0),
                accent: accent,
              ),
            ),
            SizedBox(height: compact ? 1 : 2),
            Text(
              display,
              style: TextStyle(
                fontSize: compact ? 8 : 10,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KnobPainter extends CustomPainter {
  KnobPainter({required this.progress, this.accent = Colors.cyanAccent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;

    final basePaint = Paint()
      ..color = const Color(0xFF343440)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, basePaint);

    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, borderPaint);

    final startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    final arcPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 4),
      startAngle,
      sweepAngle * progress,
      false,
      arcPaint,
    );

    final angle = startAngle + sweepAngle * progress;
    final pointerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final end = Offset(
      center.dx + math.cos(angle) * radius * 0.72,
      center.dy + math.sin(angle) * radius * 0.72,
    );

    canvas.drawLine(center, end, pointerPaint);
    canvas.drawCircle(center, 3, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant KnobPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}

class _EditorWavePainter extends CustomPainter {
  _EditorWavePainter({required this.inPoint, required this.outPoint});
  final double inPoint;
  final double outPoint;
  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final random = math.Random(17);
    final wave = Paint()..color = const Color(0xFFB56BFF).withOpacity(0.8)..strokeWidth = 1.2;
    final grid = Paint()..color = Colors.white.withOpacity(0.07)..strokeWidth = 1;
    for (int i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), grid);
    for (int i = 0; i < size.width.toInt(); i += 3) {
      final h = 3 + random.nextDouble() * size.height * 0.72;
      canvas.drawLine(Offset(i.toDouble(), mid - h / 2), Offset(i.toDouble(), mid + h / 2), wave);
    }
    final xIn = size.width * inPoint;
    final xOut = size.width * outPoint;
    canvas.drawRect(Rect.fromLTRB(xIn, 0, xOut, size.height), Paint()..color = Colors.purpleAccent.withOpacity(0.08));
    canvas.drawLine(Offset(xIn, 0), Offset(xIn, size.height), Paint()..color = Colors.purpleAccent..strokeWidth = 2);
    canvas.drawLine(Offset(xOut, 0), Offset(xOut, size.height), Paint()..color = Colors.blueAccent..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(covariant _EditorWavePainter oldDelegate) =>
      oldDelegate.inPoint != inPoint || oldDelegate.outPoint != outPoint;
}
