import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SamplePadApp());
}

class SamplePadApp extends StatelessWidget {
  const SamplePadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sampler Para PRO',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFE0),
          secondary: Color(0xFF9900FF),
        ),
      ),
      home: const SampleStateHome(),
    );
  }
}

class SamplePad {
  String name;
  Uint8List? bytes;
  String? fileName;
  final AudioPlayer player = AudioPlayer();

  SamplePad({required this.name});
}

class SampleStateHome extends StatefulWidget {
  const SampleStateHome({super.key});

  @override
  State<SampleStateHome> createState() => _SampleStateHomeState();
}

class _SampleStateHomeState extends State<SampleStateHome> {
  final MidiCommand _midiCommand = MidiCommand();

  static const int samplePadNumber = 12;

  late final List<SamplePad> pads;

  StreamSubscription<MidiDataReceivedEvent>? _midiDataSubscription;
  StreamSubscription<MidiSetupChange>? _midiDeviceSubscription;

  List<MidiDevice> devices = [];
  MidiDevice? selectedDevice;

  String midiStatus = 'MIDI desconectado';
  String lastAction = 'Carga un sonido para comenzar';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    pads = List.generate(
      samplePadNumber,
      (index) => SamplePad(name: 'PAD ${index + 1}'),
    );

    _initMidi();
  }

  Future<void> _initMidi() async {
    try {
      _midiDataSubscription =
          _midiCommand.onMidiDataReceived?.listen((event) {
        final message = event.message;

        if (message is NoteOnMessage && message.velocity > 0) {
          final index = message.note % samplePadNumber;
          _playPadSound(index);
        }
      });

      _midiDeviceSubscription =
          _midiCommand.onMidiSetupChanged?.listen((_) {
        _refreshMidiDevices();
      });

      await _refreshMidiDevices();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        midiStatus = 'Error al iniciar MIDI: $e';
      });
    }
  }

  Future<void> _refreshMidiDevices() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final result = await _midiCommand.devices;

      if (!mounted) return;

      setState(() {
        devices = result ?? [];

        if (selectedDevice != null &&
            !devices.any((d) => d.id == selectedDevice!.id)) {
          selectedDevice = null;
        }

        isLoading = false;

        if (devices.isEmpty) {
          selectedDevice = null;
          midiStatus = 'No se encontraron dispositivos MIDI';
        } else {
          midiStatus =
              'Dispositivos MIDI encontrados: ${devices.length}';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        midiStatus = 'Error al buscar dispositivos MIDI: $e';
      });
    }
  }

  Future<void> _connectMidiDevice(MidiDevice device) async {
    try {
      await _midiCommand.connectToDevice(device);

      if (!mounted) return;

      setState(() {
        selectedDevice = device;
        midiStatus = 'Conectado: ${device.name}';
        lastAction = 'Controlador MIDI conectado';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        midiStatus = 'No se pudo conectar al controlador MIDI: $e';
      });
    }
  }

  Future<void> _loadSample(int index) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'wav',
          'mp3',
          'ogg',
          'aac',
          'm4a',
        ],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        _showMessage('No se pudieron leer los datos del audio.');
        return;
      }

      if (!mounted) return;

      setState(() {
        pads[index].bytes = bytes;
        pads[index].fileName = file.name;
        pads[index].name = file.name;
        lastAction = 'Audio cargado en PAD ${index + 1}';
      });
    } catch (e) {
      _showMessage('Error al cargar el audio: $e');
    }
  }

  Future<void> _playPadSound(int index) async {
    if (index < 0 || index >= pads.length) return;

    final pad = pads[index];
    final bytes = pad.bytes;

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;

      setState(() {
        lastAction = 'Primero carga un sonido en PAD ${index + 1}';
      });

      return;
    }

    try {
      await pad.player.stop();
      await pad.player.play(BytesSource(bytes));

      if (!mounted) return;

      setState(() {
        lastAction = 'Reproduciendo: ${pad.name}';
      });
    } catch (e) {
      _showMessage('Error al reproducir el audio: $e');
    }
  }

  Future<void> _stopAll() async {
    for (final pad in pads) {
      try {
        await pad.player.stop();
      } catch (_) {
        // Continúa deteniendo los demás pads.
      }
    }

    if (!mounted) return;

    setState(() {
      lastAction = 'Todos los sonidos detenidos';
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _midiDataSubscription?.cancel();
    _midiDeviceSubscription?.cancel();

    for (final pad in pads) {
      pad.player.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SAMPLER PARA PRO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF111827),
        actions: [
          IconButton(
            tooltip: 'Actualizar MIDI',
            onPressed: _refreshMidiDevices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF00FFE0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    midiStatus,
                    style: const TextStyle(
                      color: Color(0xFF00FFE0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<MidiDevice>(
                          isExpanded: true,
                          value: devices.any(
                            (d) => d.id == selectedDevice?.id,
                          )
                              ? devices.firstWhere(
                                  (d) => d.id == selectedDevice!.id,
                                )
                              : null,
                          hint: const Text('Seleccionar MIDI'),
                          items: devices.map((device) {
                            return DropdownMenuItem<MidiDevice>(
                              value: device,
                              child: Text(
                                device.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (device) {
                            if (device != null) {
                              _connectMidiDevice(device);
                            }
                          },
                        ),
                      ),
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.graphic_eq,
                    color: Color(0xFF00FFE0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lastAction,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Detener todos los sonidos',
                    onPressed: _stopAll,
                    icon: const Icon(
                      Icons.stop_circle,
                      color: Colors.redAccent,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: pads.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, index) {
                  final pad = pads[index];
                  final loaded = pad.bytes != null;

                  return Material(
                    color: loaded
                        ? const Color(0xFF3B1764)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _playPadSound(index),
                      onLongPress: () => _loadSample(index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: loaded
                                ? const Color(0xFF00FFE0)
                                : const Color(0xFF475569),
                            width: loaded ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              loaded
                                  ? Icons.graphic_eq
                                  : Icons.add_circle_outline,
                              size: 32,
                              color: loaded
                                  ? const Color(0xFF00FFE0)
                                  : Colors.white70,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PAD ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              loaded ? pad.name : 'Vacío',
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _loadSample(index),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  foregroundColor:
                                      const Color(0xFF00FFE0),
                                ),
                                child: const Text(
                                  'CARGAR',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'Toca un PAD para reproducir • Pulsa CARGAR para elegir un audio',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
