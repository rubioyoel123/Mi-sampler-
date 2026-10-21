
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101116),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF2D75),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SamplerHomePage(),
    );
  }
}

class SamplePad {
  SamplePad({
    required this.name,
    required this.color,
    required this.midiNote,
  });

  final String name;
  final Color color;
  final int midiNote;
  String? filePath;
  String? fileName;
  bool playing = false;
}

class SamplerHomePage extends StatefulWidget {
  const SamplerHomePage({super.key});

  @override
  State<SamplerHomePage> createState() => _SamplerHomePageState();
}

class _SamplerHomePageState extends State<SamplerHomePage> {
  final MidiCommand _midi = MidiCommand();
  final List<AudioPlayer> _players =
      List.generate(8, (_) => AudioPlayer());

  StreamSubscription<MidiDataReceivedEvent>? _midiSubscription;
  StreamSubscription<MidiSetupChange>? _setupSubscription;

  List<MidiDevice> _devices = [];
  MidiDevice? _selectedDevice;

  double _masterVolume = 0.85;
  bool _midiConnected = false;
  bool _loadingMidi = false;
  String _status = 'Listo para mezclar';

  final List<SamplePad> _pads = [
    SamplePad(
      name: 'PERREO',
      color: const Color(0xFFFF2D75),
      midiNote: 36,
    ),
    SamplePad(
      name: 'BASS',
      color: const Color(0xFF8A5CFF),
      midiNote: 37,
    ),
    SamplePad(
      name: 'SIRENA',
      color: const Color(0xFF00C9FF),
      midiNote: 38,
    ),
    SamplePad(
      name: 'HORN',
      color: const Color(0xFFFFA62B),
      midiNote: 39,
    ),
    SamplePad(
      name: 'VOZ',
      color: const Color(0xFFFF477E),
      midiNote: 40,
    ),
    SamplePad(
      name: 'DRUM',
      color: const Color(0xFF00D6A3),
      midiNote: 41,
    ),
    SamplePad(
      name: 'FX',
      color: const Color(0xFFFFD43B),
      midiNote: 42,
    ),
    SamplePad(
      name: 'DROP',
      color: const Color(0xFF5790FF),
      midiNote: 43,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeMidi();
  }

  Future<void> _initializeMidi() async {
    _midiSubscription = _midi.onMidiDataReceived?.listen(
      _handleMidiData,
    );

    _setupSubscription = _midi.onMidiSetupChanged?.listen((_) {
      _refreshMidiDevices();
    });

    await _refreshMidiDevices();
  }

  Future<void> _refreshMidiDevices() async {
    try {
      final devices = await _midi.devices ?? <MidiDevice>[];

      if (!mounted) return;

      setState(() {
        _devices = devices;
        if (_selectedDevice != null &&
            !devices.any((device) => device.id == _selectedDevice!.id)) {
          _selectedDevice = null;
          _midiConnected = false;
        }
        _status = devices.isEmpty
            ? 'Conecta tu controlador MIDI por USB'
            : 'Controlador MIDI disponible';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'No se pudieron buscar dispositivos MIDI');
    }
  }

  Future<void> _connectMidi() async {
    if (_devices.isEmpty) {
      await _refreshMidiDevices();
    }

    if (_devices.isEmpty) {
      if (!mounted) return;
      setState(() => _status = 'No se detectó ningún controlador MIDI');
      return;
    }

    setState(() {
      _loadingMidi = true;
      _status = 'Conectando MIDI...';
    });

    try {
      final device = _selectedDevice ?? _devices.first;
      await _midi.connectToDevice(device);

      if (!mounted) return;

      setState(() {
        _selectedDevice = device;
        _midiConnected = true;
        _status = 'MIDI conectado: ${device.name}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _midiConnected = false;
        _status = 'No se pudo conectar el controlador MIDI';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingMidi = false);
      }
    }
  }

  void _handleMidiData(MidiDataReceivedEvent event) {
    final message = event.message;

    if (message is NoteOnMessage && message.velocity > 0) {
      final index = _pads.indexWhere(
        (pad) => pad.midiNote == message.note,
      );

      if (index != -1) {
        unawaited(_playPad(index));
      }
    }
  }

  Future<void> _loadSample(int index) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'ogg', 'm4a', 'aac'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final path = file.path;

      if (path == null) {
        if (!mounted) return;
        setState(() => _status = 'No se pudo acceder al archivo');
        return;
      }

      setState(() {
        _pads[index].filePath = path;
        _pads[index].fileName = file.name;
        _status = 'Sonido cargado: ${file.name}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Error al cargar el sonido');
    }
  }

  Future<void> _playPad(int index) async {
    final pad = _pads[index];
    final path = pad.filePath;

    if (path == null) {
      await _loadSample(index);
      return;
    }

    try {
      setState(() {
        pad.playing = true;
        _status = 'Reproduciendo ${pad.name}';
      });

      await _players[index].stop();
      await _players[index].setVolume(_masterVolume);
      await _players[index].play(DeviceFileSource(path));

      _players[index].onPlayerComplete.first.then((_) {
        if (!mounted) return;
        setState(() => pad.playing = false);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        pad.playing = false;
        _status = 'Error al reproducir el sonido';
      });
    }
  }

  Future<void> _stopAll() async {
    for (final player in _players) {
      await player.stop();
    }

    if (!mounted) return;

    setState(() {
      for (final pad in _pads) {
        pad.playing = false;
      }
      _status = 'Todos los sonidos detenidos';
    });
  }

  Widget _buildPad(int index) {
    final pad = _pads[index];

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _playPad(index),
      onLongPress: () => _loadSample(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: pad.playing
              ? pad.color.withValues(alpha: 0.35)
              : const Color(0xFF1B1D26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: pad.color,
            width: pad.playing ? 3 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: pad.color.withValues(alpha: pad.playing ? 0.35 : 0.08),
              blurRadius: pad.playing ? 20 : 7,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                pad.playing ? Icons.graphic_eq : Icons.music_note,
                color: pad.color,
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                pad.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                pad.fileName ?? 'Toca para cargar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'MIDI ${pad.midiNote}',
                style: TextStyle(
                  color: pad.color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF2D75), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _midiSubscription?.cancel();
    _setupSubscription?.cancel();
    _midi.dispose();

    for (final player in _players) {
      player.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 850 ? 4 : 2;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D75),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.graphic_eq,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SAMPLER PERREO',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            Text(
                              'DJ SAMPLE STATION',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar MIDI',
                        onPressed: _refreshMidiDevices,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF302039),
                          Color(0xFF191B27),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF4A2A54),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          'CONTROLADOR MIDI',
                          Icons.usb,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<MidiDevice>(
                          value: _selectedDevice,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Dispositivo disponible',
                            border: OutlineInputBorder(),
                          ),
                          items: _devices.map((device) {
                            return DropdownMenuItem<MidiDevice>(
                              value: device,
                              child: Text(
                                device.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _midiConnected
                              ? null
                              : (device) {
                                  setState(() {
                                    _selectedDevice = device;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loadingMidi || _midiConnected
                                ? null
                                : _connectMidi,
                            icon: Icon(
                              _midiConnected
                                  ? Icons.check_circle
                                  : Icons.cable,
                            ),
                            label: Text(
                              _loadingMidi
                                  ? 'CONECTANDO...'
                                  : _midiConnected
                                      ? 'MIDI CONECTADO'
                                      : 'CONECTAR CONTROLADOR',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(
                        'SAMPLE BANK',
                        Icons.grid_view_rounded,
                      ),
                      Text(
                        '${_pads.where((p) => p.filePath != null).length}/8 CARGADOS',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pads.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    itemBuilder: (context, index) => _buildPad(index),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1D26),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF30323E),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          'MASTER VOLUME',
                          Icons.volume_up,
                        ),
                        Slider(
                          value: _masterVolume,
                          min: 0,
                          max: 1,
                          divisions: 100,
                          label:
                              '${(_masterVolume * 100).round()}%',
                          onChanged: (value) {
                            setState(() => _masterVolume = value);
                            for (final player in _players) {
                              unawaited(player.setVolume(value));
                            }
                          },
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _stopAll,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('DETENER TODOS LOS SAMPLES'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1D26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 10,
                          color: Color(0xFF00D6A3),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _status,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'SAMPLER PERREO  •  DJ EDITION',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
