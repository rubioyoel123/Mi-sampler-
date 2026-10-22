import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:libremidi_flutter/libremidi_flutter.dart';

void main() {
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
        scaffoldBackgroundColor: const Color(0xFF101018),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF1744),
          secondary: Color(0xFFFF9100),
        ),
      ),
      home: const SamplerHome(),
    );
  }
}

class SamplerHome extends StatefulWidget {
  const SamplerHome({super.key});

  @override
  State<SamplerHome> createState() => _SamplerHomeState();
}

class _SamplerHomeState extends State<SamplerHome> {
  static const int padCount = 16;

  final List<AudioPlayer> _players =
      List.generate(padCount, (_) => AudioPlayer());

  final List<String?> _audioPaths =
      List<String?>.filled(padCount, null);

  final List<String> _audioNames =
      List<String>.filled(padCount, '');

  final List<bool> _playing =
      List<bool>.filled(padCount, false);

  final Map<LogicalKeyboardKey, int> _keyboardMap = {
    LogicalKeyboardKey.digit1: 0,
    LogicalKeyboardKey.digit2: 1,
    LogicalKeyboardKey.digit3: 2,
    LogicalKeyboardKey.digit4: 3,
    LogicalKeyboardKey.digit5: 4,
    LogicalKeyboardKey.digit6: 5,
    LogicalKeyboardKey.digit7: 6,
    LogicalKeyboardKey.digit8: 7,
    LogicalKeyboardKey.digit9: 8,
    LogicalKeyboardKey.digit0: 9,
    LogicalKeyboardKey.keyQ: 10,
    LogicalKeyboardKey.keyW: 11,
    LogicalKeyboardKey.keyE: 12,
    LogicalKeyboardKey.keyR: 13,
    LogicalKeyboardKey.keyA: 14,
    LogicalKeyboardKey.keyS: 15,
  };

  final List<String> _keyLabels = [
    '1', '2', '3', '4',
    '5', '6', '7', '8',
    '9', '0', 'Q', 'W',
    'E', 'R', 'A', 'S',
  ];

  List<dynamic> _midiPorts = [];

  dynamic _midiInput;

  StreamSubscription<dynamic>? _midiSubscription;
  StreamSubscription<dynamic>? _hotplugSubscription;

  String _midiStatus = 'MIDI desconectado';
  String _message = 'Carga tus sonidos MP3';

  bool _loadingMidi = false;

  @override
  void initState() {
    super.initState();
    _refreshMidiPorts();

    try {
      _hotplugSubscription =
          LibremidiFlutter.onHotplug.listen((_) {
        _refreshMidiPorts();
      });
    } catch (_) {
      // La aplicación seguirá funcionando sin detección automática.
    }
  }

  Future<void> _refreshMidiPorts() async {
    try {
      final ports = LibremidiFlutter.getInputPorts();

      if (!mounted) return;

      setState(() {
        _midiPorts = List<dynamic>.from(ports);
        if (_midiPorts.isEmpty && _midiInput == null) {
          _midiStatus = 'No se encontraron entradas MIDI';
        } else if (_midiInput == null) {
          _midiStatus =
              'Controladores encontrados: ${_midiPorts.length}';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _midiStatus = 'No se pudieron buscar dispositivos MIDI';
      });
    }
  }

  Future<void> _connectMidi(dynamic port) async {
    if (_loadingMidi) return;

    setState(() {
      _loadingMidi = true;
      _midiStatus = 'Conectando MIDI...';
    });

    try {
      await _midiSubscription?.cancel();
      _midiSubscription = null;

      if (_midiInput != null) {
        try {
          LibremidiFlutter.disconnectInput(_midiInput);
        } catch (_) {}
        _midiInput = null;
      }

      final input = LibremidiFlutter.openInput(port);

      _midiInput = input;

      _midiSubscription = input.messages.listen(
        (dynamic event) {
          if (event.isNoteOn && event.velocity > 0) {
            final int note = event.note;

            // Notas MIDI 36 a 51 disparan los 16 pads.
            if (note >= 36 && note <= 51) {
              _playPad(note - 36);
            }
          } else if (event.isControlChange) {
            final int controller = event.controller;

            // CC 0 a 15 disparan los 16 pads.
            if (event.value > 0 &&
                controller >= 0 &&
                controller < padCount) {
              _playPad(controller);
            }
          }
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _midiStatus = 'Error recibiendo MIDI';
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _midiStatus = 'MIDI conectado: ${port.displayName}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _midiStatus = 'No se pudo conectar el dispositivo MIDI';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMidi = false;
        });
      }
    }
  }

  Future<void> _disconnectMidi() async {
    await _midiSubscription?.cancel();
    _midiSubscription = null;

    if (_midiInput != null) {
      try {
        LibremidiFlutter.disconnectInput(_midiInput);
      } catch (_) {}

      _midiInput = null;
    }

    if (!mounted) return;

    setState(() {
      _midiStatus = 'MIDI desconectado';
    });
  }

  Future<void> _loadSound(int index) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path;

      if (path == null || path.isEmpty) {
        if (!mounted) return;

        setState(() {
          _message = 'No se pudo abrir el archivo seleccionado';
        });
        return;
      }

      await _players[index].stop();

      if (!mounted) return;

      setState(() {
        _audioPaths[index] = path;
        _audioNames[index] = file.name;
        _playing[index] = false;
        _message = 'Sonido cargado en PAD ${index + 1}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = 'Error al cargar el MP3';
      });
    }
  }

  Future<void> _playPad(int index) async {
    if (index < 0 || index >= padCount) return;

    final path = _audioPaths[index];

    if (path == null || path.isEmpty) {
      if (!mounted) return;

      setState(() {
        _message = 'Primero carga un MP3 en PAD ${index + 1}';
      });
      return;
    }

    try {
      await _players[index].stop();
      await _players[index].play(DeviceFileSource(path));

      if (!mounted) return;

      setState(() {
        _playing[index] = true;
        _message = 'Reproduciendo PAD ${index + 1}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _playing[index] = false;
        _message = 'Error reproduciendo PAD ${index + 1}';
      });
    }
  }

  Future<void> _stopPad(int index) async {
    try {
      await _players[index].stop();

      if (!mounted) return;

      setState(() {
        _playing[index] = false;
        _message = 'PAD ${index + 1} detenido';
      });
    } catch (_) {}
  }

  Future<void> _stopAll() async {
    for (int i = 0; i < padCount; i++) {
      try {
        await _players[i].stop();
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      for (int i = 0; i < padCount; i++) {
        _playing[i] = false;
      }
      _message = 'Todos los pads detenidos';
    });
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final index = _keyboardMap[event.logicalKey];

    if (index == null) {
      return KeyEventResult.ignored;
    }

    _playPad(index);
    return KeyEventResult.handled;
  }

  Widget _buildPad(int index) {
    final hasSound = _audioPaths[index] != null;
    final isPlaying = _playing[index];

    return Card(
      color: isPlaying
          ? const Color(0xFFFF1744)
          : const Color(0xFF242434),
      elevation: 5,
      child: InkWell(
        onTap: () => _playPad(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPlaying ? Icons.graphic_eq : Icons.music_note,
                size: 30,
                color: hasSound
                    ? Colors.orangeAccent
                    : Colors.white54,
              ),
              const SizedBox(height: 5),
              Text(
                'PAD ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'TECLA ${_keyLabels[index]}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 5),
              Text(
                hasSound ? _audioNames[index] : 'Sin MP3',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(height: 5),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: 'Cargar MP3',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _loadSound(index),
                    icon: const Icon(
                      Icons.folder_open,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Detener sonido',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _stopPad(index),
                    icon: const Icon(
                      Icons.stop_circle_outlined,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _midiSubscription?.cancel();
    _hotplugSubscription?.cancel();

    if (_midiInput != null) {
      try {
        LibremidiFlutter.disconnectInput(_midiInput);
      } catch (_) {}
    }

    for (final player in _players) {
      unawaited(player.dispose());
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'SAMPLER PERREO',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF1B1B2A),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text(
                      '16 PADS • MP3 • TECLADO • MIDI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _midiStatus,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<dynamic>(
                            isExpanded: true,
                            hint: const Text('Elegir controlador MIDI'),
                            value: null,
                            items: _midiPorts.map((dynamic port) {
                              return DropdownMenuItem<dynamic>(
                                value: port,
                                child: Text(
                                  '${port.displayName}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: _loadingMidi
                                ? null
                                : (dynamic port) {
                                    if (port != null) {
                                      _connectMidi(port);
                                    }
                                  },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Buscar controladores MIDI',
                          onPressed: _refreshMidiPorts,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap
