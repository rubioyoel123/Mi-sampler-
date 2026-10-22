
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final String name;
  final String keyLabel;
  final Color color;
  final int midiNote;

  String? audioPath;
  String? audioName;
  double volume = 1.0;
  double pitch = 1.0;
  bool active = false;

  AudioPlayer? player;

  Map<String, dynamic> toJson() => {
        'audioPath': audioPath,
        'audioName': audioName,
        'volume': volume,
        'pitch': pitch,
      };

  void loadJson(Map<String, dynamic> json) {
    audioPath = json['audioPath'] as String?;
    audioName = json['audioName'] as String?;
    volume = (json['volume'] as num?)?.toDouble() ?? 1.0;
    pitch = (json['pitch'] as num?)?.toDouble() ?? 1.0;
  }
}

class SamplerHome extends StatefulWidget {
  const SamplerHome({super.key});

  @override
  State<SamplerHome> createState() => _SamplerHomeState();
}

class _SamplerHomeState extends State<SamplerHome> {
  final MidiCommand midi = MidiCommand();
  final FocusNode keyboardFocus = FocusNode();

  final List<SamplePad> pads = List.generate(
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
  );

  StreamSubscription<MidiDataReceivedEvent>? midiSubscription;

  double masterVolume = 0.8;
  double masterPitch = 1.0;
  int selectedBank = 0;
  bool midiLearn = false;
  int? learningPad;
  String status = 'Listo para mezclar';
  List<MidiDevice> midiDevices = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initMidi();
  }

  @override
  void dispose() {
    midiSubscription?.cancel();
    keyboardFocus.dispose();
    for (final pad in pads) {
      pad.player?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        masterVolume = prefs.getDouble('masterVolume') ?? 0.8;
        masterPitch = prefs.getDouble('masterPitch') ?? 1.0;

        for (int i = 0; i < pads.length; i++) {
          final path = prefs.getString('pad_$i');
          final name = prefs.getString('pad_name_$i');

          pads[i].audioPath = path;
          pads[i].audioName = name;
          pads[i].volume = prefs.getDouble('pad_volume_$i') ?? 1.0;
          pads[i].pitch = prefs.getDouble('pad_pitch_$i') ?? 1.0;
        }
      });
    } catch (e) {
      _showStatus('No se pudieron cargar los ajustes: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble('masterVolume', masterVolume);
      await prefs.setDouble('masterPitch', masterPitch);

      for (int i = 0; i < pads.length; i++) {
        final pad = pads[i];

        if (pad.audioPath != null) {
          await prefs.setString('pad_$i', pad.audioPath!);
        } else {
          await prefs.remove('pad_$i');
        }

        if (pad.audioName != null) {
          await prefs.setString('pad_name_$i', pad.audioName!);
        } else {
          await prefs.remove('pad_name_$i');
        }

        await prefs.setDouble('pad_volume_$i', pad.volume);
        await prefs.setDouble('pad_pitch_$i', pad.pitch);
      }
    } catch (e) {
      _showStatus('Error al guardar: $e');
    }
  }

  Future<void> _initMidi() async {
    try {
      midiDevices = await midi.devices ?? [];

      midiSubscription = midi.onMidiDataReceived?.listen((event) {
        final message = event.message;

        if (message is! NoteOnMessage || message.velocity <= 0) {
          return;
        }

        final note = message.note;

        if (midiLearn && learningPad != null) {
          final index = learningPad!;

          setState(() {
            pads[index] = pads[index];
            midiLearn = false;
            learningPad = null;
            status = 'Nota MIDI $note recibida';
          });

          _showStatus(
            'Nota recibida: $note. Los pads usan notas MIDI 36 a 51.',
          );
          return;
        }

        final index = pads.indexWhere((pad) => pad.midiNote == note);

        if (index != -1) {
          _playPad(index);
        }
      });

      if (mounted) {
        setState(() {
          status = midiDevices.isEmpty
              ? 'No se detectó controlador MIDI'
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
    final extension = source.uri.pathSegments.last;
    final destination = File(
      '${library.path}/${DateTime.now().microsecondsSinceEpoch}_$extension',
    );

    await source.copy(destination.path);
    return destination.path;
  }

  Future<void> _loadAudio(int index) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.audio);

      if (files.isEmpty || files.first.path == null) return;

      final file = files.first;
      final copiedPath = await _copyAudioToLibrary(file.path!);

      setState(() {
        pads[index].audioPath = copiedPath;
        pads[index].audioName = file.name;
      });

      await _saveSettings();
      _showStatus('Audio cargado en ${pads[index].name}');
    } catch (e) {
      _showStatus('No se pudo cargar el audio: $e');
    }
  }

  Future<void> _playPad(int index) async {
    final pad = pads[index];

    if (pad.audioPath == null) {
      _showStatus('Carga un audio en ${pad.name} primero');
      return;
    }

    try {
      pad.player ??= AudioPlayer();

      await pad.player!.stop();
      await pad.player!.setVolume(
        (masterVolume * pad.volume).clamp(0.0, 1.0),
      );
      await pad.player!.setPlaybackRate(
        (masterPitch * pad.pitch).clamp(0.5, 2.0),
      );

      setState(() => pad.active = true);

      await pad.player!.play(DeviceFileSource(pad.audioPath!));

      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => pad.active = false);
      });

      _showStatus('Reproduciendo ${pad.name}');
    } catch (e) {
      _showStatus('Error al reproducir audio: $e');
    }
  }

  Future<void> _stopAll() async {
    for (final pad in pads) {
      await pad.player?.stop();
      pad.active = false;
    }

    if (mounted) {
      setState(() => status = 'Reproducción detenida');
    }
  }

  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent || event.repeat) return;

    final key = event.logicalKey.keyLabel.toUpperCase();

    final index = pads.indexWhere((pad) => pad.keyLabel == key);

    if (index != -1) {
      _playPad(index);
    }
  }

  void _clearPad(int index) async {
    await pads[index].player?.stop();

    setState(() {
      pads[index].audioPath = null;
      pads[index].audioName = null;
    });

    await _saveSettings();
    _showStatus('Pad ${index + 1} limpiado');
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
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF191923),
          actions: [
            IconButton(
              tooltip: 'Detener todos los audios',
              onPressed: _stopAll,
              icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
            ),
            IconButton(
              tooltip: 'Guardar ajustes',
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildMasterControls(),
              _buildBankSelector(),
              Expanded(child: _buildPads()),
              _buildStatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterControls() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF191923),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Text(
            'DJ DANNYS YOEL',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.volume_up),
              const SizedBox(width: 8),
              const Text('VOLUMEN'),
              Expanded(
                child: Slider(
                  value: masterVolume,
                  min: 0,
                  max: 1,
                  onChanged: (value) {
                    setState(() => masterVolume = value);
                  },
                  onChangeEnd: (_) => _saveSettings(),
                ),
              ),
              Text('${(masterVolume * 100).round()}%'),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.graphic_eq),
              const SizedBox(width: 8),
              const Text('PITCH'),
              Expanded(
                child: Slider(
                  value: masterPitch,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (value) {
                    setState(() => masterPitch = value);
                  },
                  onChangeEnd: (_) => _saveSettings(),
                ),
              ),
              Text('${masterPitch.toStringAsFixed(2)}x'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text(
            'BANCO',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          for (int i = 0; i < 8; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: selectedBank == i
                        ? Colors.deepPurpleAccent
                        : const Color(0xFF292936),
                  ),
                  onPressed: () {
                    setState(() => selectedBank = i);
                    _showStatus(
                      'Banco ${i + 1}: esta versión usa 16 pads de audio',
                    );
                  },
                  child: Text('${i + 1}'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPads() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        itemCount: pads.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (context, index) {
          final pad = pads[index];
          final hasAudio = pad.audioPath != null;

          return GestureDetector(
            onTap: () => _playPad(index),
            onLongPress: () => _loadAudio(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                color: pad.active
                    ? pad.color
                    : pad.color.withOpacity(hasAudio ? 0.30 : 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: pad.color,
                  width: pad.active ? 3 : 1.5,
                ),
                boxShadow: pad.active
                    ? [
                        BoxShadow(
                          color: pad.color.withOpacity(0.6),
                          blurRadius: 18,
                        ),
                      ]
                    : [],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasAudio ? Icons.music_note : Icons.add,
                            size: 28,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pad.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasAudio
                                ? (pad.audioName ?? 'Audio cargado')
                                : 'Mantén para cargar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                          Text(
                            'Tecla ${pad.keyLabel} · MIDI ${pad.midiNote}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasAudio)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: 'Quitar audio',
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        onPressed: () => _clearPad(index),
                        icon: const Icon(Icons.close),
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
      padding: const EdgeInsets.all(10),
      color: const Color(0xFF191923),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.cyanAccent),
      ),
    );
  }
}
