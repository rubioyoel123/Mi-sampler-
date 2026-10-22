
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MiSamplerApp());
}

const Color bgColor = Color(0xFF101217);
const Color panelColor = Color(0xFF191D25);
const Color borderColor = Color(0xFF303743);
const Color accentColor = Color(0xFF75A7D2);

class MiSamplerApp extends StatelessWidget {
  const MiSamplerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sampler Perreo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        colorScheme: const ColorScheme.dark(
          primary: accentColor,
          surface: panelColor,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: accentColor,
          thumbColor: accentColor,
          inactiveTrackColor: borderColor,
        ),
      ),
      home: const SamplerStudio(),
    );
  }
}

class SamplerStudio extends StatefulWidget {
  const SamplerStudio({super.key});

  @override
  State<SamplerStudio> createState() => _SamplerStudioState();
}

class _SamplerStudioState extends State<SamplerStudio> {
  final FocusNode _focusNode = FocusNode();
  final MidiCommand _midiCommand = MidiCommand();

  StreamSubscription<dynamic>? _midiSubscription;
  Timer? _stopTimer;

  double masterVolume = 1.0;
  double masterPitch = 1.0;

  int selectedPad = 0;
  String midiStatus = 'MIDI no conectado';
  List<dynamic> midiDevices = [];

  final List<Map<String, dynamic>> pads = [
    {'name': 'KICK', 'color': const Color(0xFFC18B58), 'key': '1', 'midi': 36},
    {'name': 'SNARE', 'color': const Color(0xFFC18B58), 'key': '2', 'midi': 37},
    {'name': 'HI-HAT', 'color': const Color(0xFFC18B58), 'key': '3', 'midi': 38},
    {'name': 'CLAP', 'color': const Color(0xFFC18B58), 'key': '4', 'midi': 39},
    {'name': 'LOOP 1', 'color': const Color(0xFF689BC2), 'key': 'Q', 'midi': 40},
    {'name': 'LOOP 2', 'color': const Color(0xFF689BC2), 'key': 'W', 'midi': 41},
    {'name': 'SAMPLE 1', 'color': const Color(0xFF689BC2), 'key': 'E', 'midi': 42},
    {'name': 'SAMPLE 2', 'color': const Color(0xFF83A98E), 'key': 'R', 'midi': 43},
    {'name': 'SYNTH', 'color': const Color(0xFF83A98E), 'key': 'A', 'midi': 44},
    {'name': 'BASS', 'color': const Color(0xFF83A98E), 'key': 'S', 'midi': 45},
    {'name': 'VOX 1', 'color': const Color(0xFF83A98E), 'key': 'D', 'midi': 46},
    {'name': 'VOX 2', 'color': const Color(0xFF83A98E), 'key': 'F', 'midi': 47},
    {'name': 'FX 1', 'color': const Color(0xFF9D89BC), 'key': 'Z', 'midi': 48},
    {'name': 'FX 2', 'color': const Color(0xFF9D89BC), 'key': 'X', 'midi': 49},
    {'name': 'SHOT 1', 'color': const Color(0xFFC0A66B), 'key': 'C', 'midi': 50},
    {'name': 'SHOT 2', 'color': const Color(0xFFC0A66B), 'key': 'V', 'midi': 51},
  ];

  String _fileName(String path) {
    return path.split(RegExp(r'[/\\]')).last;
  }

  @override
  void initState() {
    super.initState();

    for (final pad in pads) {
      pad['player'] = AudioPlayer();
      pad['path'] = null;
      pad['active'] = false;
      pad['start'] = 0.0;
      pad['end'] = 0.0;
      pad['duration'] = 0.0;
      pad['gain'] = 1.0;
    }

    _initMidi();
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _midiSubscription?.cancel();
    _focusNode.dispose();

    for (final pad in pads) {
      (pad['player'] as AudioPlayer).dispose();
    }

    super.dispose();
  }

  Future<void> _initMidi() async {
    try {
      final devices = await _midiCommand.devices;
      if (!mounted) return;

      setState(() {
        midiDevices = devices ?? [];
        midiStatus = midiDevices.isEmpty
            ? 'No se encontraron dispositivos'
            : 'Dispositivo disponible';
      });

      _midiSubscription =
          _midiCommand.onMidiDataReceived?.listen((event) {
        final message = event.message;

        if (message is NoteOnMessage && message.velocity > 0) {
          final index =
              pads.indexWhere((pad) => pad['midi'] == message.note);

          if (index != -1) {
            _playPad(index);
          }
        }
      });

      if (midiDevices.isNotEmpty) {
        await _midiCommand.connectToDevice(midiDevices.first);

        if (mounted) {
          setState(() => midiStatus = 'MIDI conectado');
        }
      }
    } catch (e) {
      debugPrint('Error MIDI: $e');

      if (mounted) {
        setState(() => midiStatus = 'No se pudo conectar MIDI');
      }
    }
  }

  Future<void> _refreshMidi() async {
    try {
      final devices = await _midiCommand.devices;
      if (!mounted) return;

      setState(() {
        midiDevices = devices ?? [];
        midiStatus = midiDevices.isEmpty
            ? 'No se encontraron dispositivos'
            : 'Dispositivos actualizados';
      });
    } catch (e) {
      debugPrint('Error al consultar MIDI: $e');
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey.keyLabel.toUpperCase();
    final index = pads.indexWhere((pad) => pad['key'] == key);

    if (index != -1) {
      _playPad(index);
    }
  }

  Future<void> _playPad(int index) async {
    if (index < 0 || index >= pads.length) return;

    final pad = pads[index];
    final path = pad['path'] as String?;

    if (mounted) {
      setState(() {
        selectedPad = index;
        pad['active'] = true;
      });
    }

    Future.delayed(const Duration(milliseconds: 130), () {
      if (mounted) {
        setState(() => pad['active'] = false);
      }
    });

    if (path == null || !File(path).existsSync()) return;

    try {
      final player = pad['player'] as AudioPlayer;

      _stopTimer?.cancel();

      await player.stop();

      await player.setVolume(
        (masterVolume * (pad['gain'] as double))
            .clamp(0.0, 1.0)
            .toDouble(),
      );

      await player.setPlaybackRate(
        masterPitch.clamp(0.5, 2.0).toDouble(),
      );

      final startMs = (pad['start'] as double).round();
      final endMs = (pad['end'] as double).round();

      await player.play(DeviceFileSource(path));

      if (startMs > 0) {
        await player.seek(Duration(milliseconds: startMs));
      }

      if (endMs > startMs) {
        final remaining = (endMs - startMs) / masterPitch;

        _stopTimer = Timer(
          Duration(
            milliseconds: remaining.round().clamp(1, 2147483647),
          ),
          () {
            player.stop();
          },
        );
      }
    } catch (e) {
      debugPrint('Error reproduciendo audio: $e');
    }
  }

  Future<void> _loadAudio(int index) async {
    if (index < 0 || index >= pads.length) return;

    try {
      final PlatformFile? result =
          await FilePicker.pickFile(type: FileType.audio);

      if (!mounted || result == null) return;

      final path = result.path;
      if (path == null || path.isEmpty) return;

      final tempPlayer = AudioPlayer();
      Duration? duration;

      try {
        await tempPlayer.setSource(DeviceFileSource(path));
        duration = await tempPlayer.getDuration();
      } catch (e) {
        debugPrint('No se pudo leer la duración: $e');
      } finally {
        await tempPlayer.dispose();
      }

      if (!mounted) return;

      final durationMs = (duration?.inMilliseconds ?? 0).toDouble();

      setState(() {
        pads[index]['path'] = path;
        pads[index]['duration'] = durationMs;
        pads[index]['start'] = 0.0;
        pads[index]['end'] = durationMs;
        selectedPad = index;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Audio cargado: ${_fileName(path)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error cargando audio: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cargar el audio.'),
          ),
        );
      }
    }
  }

  Future<void> _editSelectedPad() async {
    final pad = pads[selectedPad];

    if (pad['path'] == null) {
      await _loadAudio(selectedPad);

      if (!mounted || pads[selectedPad]['path'] == null) return;
    }

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (dialogContext) => _AudioEditorDialog(
        padName: pad['name'] as String,
        duration: pad['duration'] as double,
        initialStart: pad['start'] as double,
        initialEnd: pad['end'] as double,
        initialGain: pad['gain'] as double,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      pad['start'] = result['start'] ?? pad['start'];
      pad['end'] = result['end'] ?? pad['end'];
      pad['gain'] = result['gain'] ?? pad['gain'];
    });
  }

  void _openMidiSettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: panelColor,
          title: const Row(
            children: [
              Icon(Icons.piano, color: accentColor),
              SizedBox(width: 10),
              Text('Configuración MIDI'),
            ],
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  midiStatus,
                  style: const TextStyle(color: accentColor),
                ),
                const SizedBox(height: 14),
                const Text('Dispositivos detectados'),
                const SizedBox(height: 8),
                if (midiDevices.isEmpty)
                  const Text(
                    'No hay dispositivos disponibles. '
                    'Conecta tu controlador y actualiza.',
                    style: TextStyle(color: Colors.white60),
                  )
                else
                  ...midiDevices.map(
                    (device) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.usb, color: accentColor),
                      title: Text(
                        device.name?.toString() ?? device.toString(),
                      ),
                      subtitle: const Text('Controlador MIDI'),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Asignaciones actuales de pads',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Las notas MIDI 36–51 activan los 16 pads.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _refreshMidi();

                if (mounted) {
                  setDialogState(() {});
                }
              },
              child: const Text('Actualizar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMasterControls(),
                      const SizedBox(height: 14),
                      _buildPadsPanel(),
                      const SizedBox(height: 14),
                      _buildEditorPanel(),
                    ],
                  ),
                ),
              ),
              _buildStatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: panelColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.graphic_eq,
              color: accentColor,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAMPLER PERREO',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'DJ DANNYS YOEL',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openMidiSettings,
            icon: const Icon(Icons.piano, size: 18),
            label: const Text('MIDI'),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.circle,
            size: 9,
            color: midiStatus == 'MIDI conectado'
                ? const Color(0xFF83C99B)
                : Colors.orangeAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildMasterControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _decoration(),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 14,
        spacing: 24,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONTROLES MAESTROS',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Ajusta el sonido de todo el sampler',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          SizedBox(
            width: 250,
            child: Row(
              children: [
                const Icon(
                  Icons.volume_up,
                  color: accentColor,
                  size: 19,
                ),
                Expanded(
                  child: Slider(
                    value: masterVolume,
                    onChanged: (value) {
                      setState(() => masterVolume = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text('${(masterVolume * 100).round()}%'),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 250,
            child: Row(
              children: [
                const Icon(Icons.speed, color: accentColor, size: 19),
                Expanded(
                  child: Slider(
                    min: 0.5,
                    max: 2.0,
                    value: masterPitch,
                    onChanged: (value) {
                      setState(() => masterPitch = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text('${masterPitch.toStringAsFixed(2)}x'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPadsPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: accentColor),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'BANCO DE SONIDOS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${pads.where((p) => p['path'] != null).length}/16 cargados',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pads.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.65,
            ),
            itemBuilder: (context, index) {
              final pad = pads[index];
              final color = pad['color'] as Color;
              final active = pad['active'] as bool;
              final path = pad['path'] as String?;
              final loaded = path != null;
              final selected = selectedPad == index;

              final displayName =
                  loaded ? _fileName(path!) : pad['name'] as String;

              return GestureDetector(
                onTap: () => _playPad(index),
                onDoubleTap: () => _loadAudio(index),
                onSecondaryTap: () => _loadAudio(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: active
                        ? color.withValues(alpha: 0.38)
                        : selected
                            ? color.withValues(alpha: 0.14)
                            : const Color(0xFF20242D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected || active ? color : borderColor,
                      width: selected || active ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            loaded ? Icons.graphic_eq : Icons.add,
                            size: 17,
                            color: color,
                          ),
                          const Spacer(),
                          Text(
                            '${pad['key']}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        loaded ? 'Cargado' : 'Doble clic: cargar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPanel() {
    final pad = pads[selectedPad];
    final path = pad['path'] as String?;
    final loaded = path != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: accentColor),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'MINI EDITOR DE AUDIO',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                pad['name'] as String,
                style: TextStyle(
                  color: pad['color'] as Color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            loaded
                ? _fileName(path!)
                : 'Selecciona un pad y carga un archivo de audio',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          if (loaded) ...[
            _buildTrimPreview(pad),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _editSelectedPad,
                    icon: const Icon(Icons.content_cut),
                    label: const Text('Recortar y ajustar ganancia'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _playPad(selectedPad),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Probar'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Cambiar audio',
                  onPressed: () => _loadAudio(selectedPad),
                  icon: const Icon(Icons.folder_open),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _loadAudio(selectedPad),
                icon: const Icon(Icons.folder_open),
                label: const Text('Cargar audio en el pad seleccionado'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrimPreview(Map<String, dynamic> pad) {
    final duration = pad['duration'] as double;
    final start = pad['start'] as double;
    final end = pad['end'] as double;
    final gain = pad['gain'] as double;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101318),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(48, (i) {
              final height = 8 + (math.sin(i * 1.7).abs() * 23);
              final time = duration * i / 48;
              final inRange =
                  time >= start && (end <= 0 || time <= end);

              return Expanded(
                child: Container(
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: inRange
                        ? accentColor.withValues(alpha: 0.8)
                        : borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: Text('Inicio: ${_formatTime(start)}')),
              Expanded(
                child: Text(
                  'Final: ${_formatTime(end)}',
                  textAlign: TextAlign.center,
                ),
              ),
              Text('Ganancia: ${(gain * 100).round()}%'),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(double milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final tenths = ((milliseconds % 1000) / 100).floor();

    return '${seconds ~/ 60}:'
        '${(seconds % 60).toString().padLeft(2, '0')}.$tenths';
  }

  BoxDecoration _decoration() {
    return BoxDecoration(
      color: panelColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        color: panelColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const Icon(Icons.keyboard, size: 15, color: accentColor),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Clic: reproducir  •  Doble clic o clic derecho: cargar audio',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(
            Icons.circle,
            size: 7,
            color: Color(0xFF83C99B),
          ),
          const SizedBox(width: 6),
          const Text(
            'SAMPLER',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioEditorDialog extends StatefulWidget {
  final String padName;
  final double duration;
  final double initialStart;
  final double initialEnd;
  final double initialGain;

  const _AudioEditorDialog({
    required this.padName,
    required this.duration,
    required this.initialStart,
    required this.initialEnd,
    required this.initialGain,
  });

  @override
  State<_AudioEditorDialog> createState() => _AudioEditorDialogState();
}

class _AudioEditorDialogState extends State<_AudioEditorDialog> {
  late double start;
  late double end;
  late double gain;

  @override
  void initState() {
    super.initState();
    start = widget.initialStart;
    end = widget.initialEnd;
    gain = widget.initialGain;
  }

  String formatTime(double milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final tenths = ((milliseconds % 1000) / 100).floor();

    return '${seconds ~/ 60}:'
        '${(seconds % 60).toString().padLeft(2, '0')}.$tenths';
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.duration > 0 ? widget.duration : 1000.0;
    final safeStart = start.clamp(0.0, duration).toDouble();
    final safeEnd = end.clamp(0.0, duration).toDouble();

    return AlertDialog(
      backgroundColor: panelColor,
      title: Row(
        children: [
          const Icon(Icons.content_cut, color: accentColor),
          const SizedBox(width: 10),
          Expanded(child: Text('Editar ${widget.padName}')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'RECORTE DEL AUDIO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Inicio: ${formatTime(safeStart)}',
                style: const TextStyle(color: accentColor),
              ),
              Slider(
                min: 0,
                max: duration,
                value: safeStart,
                onChanged: (value) {
                  setState(() {
                    start = value;

                    if (start >= end) {
                      end = math.min(duration, start + 1).toDouble();
                    }
                  });
                },
              ),
              Text(
                'Final: ${formatTime(safeEnd)}',
                style: const TextStyle(color: accentColor),
              ),
              Slider(
                min: 0,
                max: duration,
                value: safeEnd,
                onChanged: (value) {
                  setState(() {
                    end = value;

                    if (end <= start) {
                      start = math.max(0.0, end - 1).toDouble();
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              const Divider(color: borderColor),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.volume_up, color: accentColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ganancia del pad',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text('${(gain * 100).round()}%'),
                ],
              ),
              Slider(
                min: 0,
                max: 1,
                value: gain.clamp(0.0, 1.0).toDouble(),
                onChanged: (value) {
                  setState(() => gain = value);
                },
              ),
              const Text(
                'La ganancia controla el volumen de salida del pad.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              <String, double>{
                'start': start,
                'end': end,
                'gain': gain,
              },
            );
          },
          child: const Text('Guardar cambios'),
        ),
      ],
    );
  }
}
