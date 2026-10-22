
import 'dart:async';
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

const Color bgColor = Color(0xFF111318);
const Color panelColor = Color(0xFF191C23);
const Color borderColor = Color(0xFF303640);
const Color accentColor = Color(0xFF7297B5);

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
        appBarTheme: const AppBarTheme(
          backgroundColor: panelColor,
          foregroundColor: Color(0xFFE1E5EB),
          elevation: 0,
          centerTitle: false,
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

class _SamplerStudioState extends State<SamplerStudio>
    with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final MidiCommand _midiCommand = MidiCommand();

  StreamSubscription<dynamic>? _midiSubscription;

  double masterVolume = 1.0;
  double masterPitch = 1.0;

  late final AnimationController _visualizerController;

  final List<Map<String, dynamic>> pads = [
    {'name': 'KICK', 'color': const Color(0xFFB98553), 'key': '1', 'midi': 36},
    {'name': 'SNARE', 'color': const Color(0xFFB98553), 'key': '2', 'midi': 37},
    {'name': 'HI-HAT', 'color': const Color(0xFFB98553), 'key': '3', 'midi': 38},
    {'name': 'CLAP', 'color': const Color(0xFFB98553), 'key': '4', 'midi': 39},
    {'name': 'LOOP 1', 'color': const Color(0xFF648BA8), 'key': 'Q', 'midi': 40},
    {'name': 'LOOP 2', 'color': const Color(0xFF648BA8), 'key': 'W', 'midi': 41},
    {'name': 'SAMPLE 1', 'color': const Color(0xFF648BA8), 'key': 'E', 'midi': 42},
    {'name': 'SAMPLE 2', 'color': const Color(0xFF739985), 'key': 'R', 'midi': 43},
    {'name': 'SYNTH', 'color': const Color(0xFF739985), 'key': 'A', 'midi': 44},
    {'name': 'BASS', 'color': const Color(0xFF739985), 'key': 'S', 'midi': 45},
    {'name': 'VOX 1', 'color': const Color(0xFF739985), 'key': 'D', 'midi': 46},
    {'name': 'VOX 2', 'color': const Color(0xFF739985), 'key': 'F', 'midi': 47},
    {'name': 'FX 1', 'color': const Color(0xFF9381AA), 'key': 'Z', 'midi': 48},
    {'name': 'FX 2', 'color': const Color(0xFF9381AA), 'key': 'X', 'midi': 49},
    {'name': 'SHOT 1', 'color': const Color(0xFFB49B62), 'key': 'C', 'midi': 50},
    {'name': 'SHOT 2', 'color': const Color(0xFFB49B62), 'key': 'V', 'midi': 51},
  ];

  @override
  void initState() {
    super.initState();

    for (final pad in pads) {
      pad['player'] = AudioPlayer();
      pad['path'] = null;
      pad['active'] = false;
    }

    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    _initMidi();
  }

  @override
  void dispose() {
    _midiSubscription?.cancel();
    _focusNode.dispose();
    _visualizerController.dispose();

    for (final pad in pads) {
      (pad['player'] as AudioPlayer).dispose();
    }

    super.dispose();
  }

  Future<void> _initMidi() async {
    try {
      final devices = await _midiCommand.devices;

      if (!mounted || devices == null || devices.isEmpty) {
        return;
      }

      _midiSubscription =
          _midiCommand.onMidiDataReceived?.listen((event) {
        final message = event.message;

        if (message is NoteOnMessage && message.velocity > 0) {
          final int index =
              pads.indexWhere((pad) => pad['midi'] == message.note);

          if (index != -1 && mounted) {
            _playPad(index);
          }
        }
      });

      await _midiCommand.connectToDevice(devices.first);
    } catch (e) {
      debugPrint('No se pudo conectar el dispositivo MIDI: $e');
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final String key = event.logicalKey.keyLabel.toUpperCase();
    final int index = pads.indexWhere((pad) => pad['key'] == key);

    if (index != -1) {
      _playPad(index);
    }
  }

  Future<void> _playPad(int index) async {
    if (index < 0 || index >= pads.length) return;

    final pad = pads[index];
    final AudioPlayer player = pad['player'] as AudioPlayer;
    final String? path = pad['path'] as String?;

    if (mounted) {
      setState(() => pad['active'] = true);
    }

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => pad['active'] = false);
      }
    });

    if (path == null) return;

    try {
      await player.stop();
      await player.setVolume(masterVolume);
      await player.setPlaybackRate(
        masterPitch.clamp(0.5, 2.0).toDouble(),
      );
      await player.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('Error al reproducir el sonido: $e');
    }
  }

  Future<void> _loadAudio(int index) async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.audio,
      );

      if (!mounted || file == null) return;

      final String? path = file.path;

      if (path != null) {
        setState(() {
          pads[index]['path'] = path;
        });
      } else {
        debugPrint('No se pudo obtener la ruta del archivo seleccionado.');
      }
    } catch (e) {
      debugPrint('Error al cargar el audio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: _buildTopBar(),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildLeftPanel(),
                    _buildPadsArea(),
                    _buildRightPanel(),
                  ],
                ),
              ),
              _buildStatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      toolbarHeight: 60,
      title: const Row(
        children: [
          Icon(Icons.graphic_eq, color: accentColor, size: 27),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAMPLER PERREO',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'DJ DANNYS YOEL',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF929BA8),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        const Center(
          child: Text(
            'WINDOWS  •  AUDIO',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF929BA8),
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 18),
        IconButton(
          tooltip: 'Estado del sampler',
          icon: const Icon(
            Icons.circle,
            color: Color(0xFF739985),
            size: 11,
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildLeftPanel() {
    return Expanded(
      flex: 3,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        padding: const EdgeInsets.all(14),
        decoration: _panelDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _sectionTitle('ESPECTRO CANAL L'),
            _buildAnimatedVisualizer(accentColor),
            const Divider(color: borderColor, height: 24),
            _sectionTitle('CONTROLES MAESTROS'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _KnobControl(
                  label: 'VOLUME',
                  value: masterVolume,
                  onChanged: (value) {
                    setState(() => masterVolume = value);
                  },
                ),
                _KnobControl(
                  label: 'PITCH',
                  value: masterPitch,
                  onChanged: (value) {
                    setState(() => masterPitch = value);
                  },
                ),
              ],
            ),
            Text(
              'VOL ${(masterVolume * 100).round()}%   '
              'PITCH ${(masterPitch * 100).round()}%',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF929BA8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFB9C1CC),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: panelColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: borderColor),
    );
  }

  Widget _buildAnimatedVisualizer(Color color) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F13),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor),
      ),
      child: AnimatedBuilder(
        animation: _visualizerController,
        builder: (context, child) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(16, (index) {
              final double waveHeight =
                  math.sin(
                    _visualizerController.value * 2 * math.pi +
                        index * 0.55,
                  ) *
                  0.5 +
                  0.5;

              return Flexible(
                child: Container(
                  width: 6,
                  height: 12 + waveHeight * 75,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha: 0.35 + waveHeight * 0.45,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildPadsArea() {
    return Expanded(
      flex: 5,
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 12, 6, 12),
        padding: const EdgeInsets.all(10),
        decoration: _panelDecoration(),
        child: GridView.builder(
          padding: const EdgeInsets.all(4),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pads.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final pad = pads[index];
            final Color color = pad['color'] as Color;
            final bool active = pad['active'] as bool;
            final bool hasAudio = pad['path'] != null;

            return GestureDetector(
              onTap: () => _playPad(index),
              onDoubleTap: () => _loadAudio(index),
              onSecondaryTap: () => _loadAudio(index),
              onLongPress: () => _loadAudio(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: 0.55)
                      : hasAudio
                          ? color.withValues(alpha: 0.16)
                          : const Color(0xFF20242C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? color
                        : color.withValues(alpha: 0.55),
                    width: active ? 2 : 1,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.22),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasAudio
                                ? Icons.graphic_eq
                                : Icons.music_note_outlined,
                            size: 20,
                            color: active
                                ? Colors.white
                                : color.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            pad['name'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : const Color(0xFFD3D8E0),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'TECLA ${pad['key']}',
                            style: const TextStyle(
                              color: Color(0xFF9099A6),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasAudio)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.check_circle,
                          size: 12,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Expanded(
      flex: 3,
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 12, 12, 12),
        padding: const EdgeInsets.all(14),
        decoration: _panelDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _sectionTitle('ESPECTRO CANAL R'),
            _buildAnimatedVisualizer(const Color(0xFF648BA8)),
            const Divider(color: borderColor, height: 24),
            _sectionTitle('ESTADO DEL TEMPO'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0F13),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: const Column(
                children: [
                  Icon(Icons.speed, color: accentColor, size: 23),
                  SizedBox(height: 8),
                  Text(
                    '128.0',
                    style: TextStyle(
                      color: Color(0xFFE1E5EB),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'BPM',
                    style: TextStyle(
                      color: Color(0xFF929BA8),
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            _sectionTitle('BANCO DE SONIDOS'),
            Text(
              '${pads.where((pad) => pad['path'] != null).length}'
              ' / ${pads.length} sonidos cargados',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF929BA8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F13),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mouse_outlined,
            size: 13,
            color: accentColor,
          ),
          const SizedBox(width: 7),
          const Expanded(
            child: Text(
              'CLIC: reproducir  •  DOBLE CLIC / CLIC DERECHO: cargar audio',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF929BA8),
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.circle,
            size: 7,
            color: Color(0xFF739985),
          ),
          const SizedBox(width: 6),
          const Text(
            'SAMPLER ACTIVO',
            style: TextStyle(
              color: Color(0xFF929BA8),
              fontSize: 9,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _KnobControl extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _KnobControl({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_KnobControl> createState() => _KnobControlState();
}

class _KnobControlState extends State<_KnobControl> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _KnobControl oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _currentValue = (_currentValue - details.delta.dy * 0.01)
                  .clamp(0.0, 1.0)
                  .toDouble();

              widget.onChanged(_currentValue);
            });
          },
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF242933),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 7,
                  offset: Offset(2, 3),
                ),
              ],
            ),
            child: Transform.rotate(
              angle: (_currentValue * 1.5 * math.pi) -
                  (0.75 * math.pi),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: const TextStyle(
            color: Color(0xFFB9C1CC),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${(_currentValue * 100).round()}%',
          style: const TextStyle(
            color: Color(0xFF929BA8),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
