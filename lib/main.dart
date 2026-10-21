
import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SamplerPerroApp());
}

class SamplerPerroApp extends StatelessWidget {
  const SamplerPerroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sampler Perro PRO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101116),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFF315),
          secondary: Color(0xFFFFF315),
        ),
      ),
      home: const SamplerHome(),
    );
  }
}

class SamplerPad {
  SamplerPad(int number)
      : name = 'PAD $number';

  String name;
  Uint8List? audioBytes;
  String? fileName;
  bool active = false;
  final AudioPlayer player = AudioPlayer();
}

class SamplerHome extends StatefulWidget {
  const SamplerHome({super.key});

  @override
  State<SamplerHome> createState() => _SamplerHomeState();
}

class _SamplerHomeState extends State<SamplerHome> {
  final MidiCommand midi = MidiCommand();

  late final List<SamplerPad> pads =
      List.generate(16, (index) => SamplerPad(index + 1));

  StreamSubscription<MidiDataReceivedEvent>? midiSubscription;
  StreamSubscription<MidiSetupChange>? setupSubscription;

  List<MidiDevice> devices = [];
  MidiDevice? selectedDevice;

  String midiStatus = 'MIDI desconectado';
  String lastAction = 'Carga un sonido para comenzar';
  bool loadingMidi = false;
  bool stopping = false;

  @override
  void initState() {
    super.initState();
    initializeMidi();
  }

  Future<void> initializeMidi() async {
    midiSubscription = midi.onMidiDataReceived?.listen((event) {
      final message = event.message;

      if (message is NoteOnMessage && message.velocity > 0) {
        final index = message.note - 36;

        if (index >= 0 && index < pads.length) {
          playPad(index);
        }
      }
    });

    setupSubscription = midi.onMidiSetupChanged?.listen((_) {
      refreshMidiDevices();
    });

    await refreshMidiDevices();
  }

  Future<void> refreshMidiDevices() async {
    if (!mounted) return;

    setState(() {
      loadingMidi = true;
    });

    try {
      final found = await midi.devices ?? <MidiDevice>[];

      if (!mounted) return;

      setState(() {
        devices = found;
        loadingMidi = false;

        if (selectedDevice != null &&
            !devices.any((d) => d.id == selectedDevice!.id)) {
          selectedDevice = null;
          midiStatus = 'Controlador desconectado';
        } else if (devices.isEmpty && selectedDevice == null) {
          midiStatus = 'No se encontraron dispositivos MIDI';
        } else if (selectedDevice == null) {
          midiStatus = 'Dispositivo MIDI disponible';
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadingMidi = false;
        midiStatus = 'Error al buscar dispositivos MIDI';
      });
    }
  }

  Future<void> connectMidi(MidiDevice device) async {
    try {
      await midi.connectToDevice(device);

      if (!mounted) return;

      setState(() {
        selectedDevice = device;
        midiStatus = 'Conectado: ${device.name}';
        lastAction = 'Controlador MIDI conectado';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        midiStatus = 'No se pudo conectar al controlador';
      });
    }
  }

  Future<void> loadSample(int index) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'wav',
          'mp3',
          'ogg',
          'm4a',
          'aac',
        ],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron leer los datos del audio.'),
          ),
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        pads[index].audioBytes = bytes;
        pads[index].fileName = file.name;
        pads[index].name = file.name;
        lastAction = 'Audio cargado en PAD ${index + 1}';
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar el audio: $error'),
        ),
      );
    }
  }

  Future<void> playPad(int index) async {
    if (index < 0 || index >= pads.length) return;

    final pad = pads[index];
    final bytes = pad.audioBytes;

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;

      setState(() {
        lastAction = 'Primero carga un sonido en PAD ${index + 1}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Carga un sonido en PAD ${index + 1}.'),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        pad.active = true;
        lastAction = 'Reproduciendo: ${pad.fileName ?? pad.name}';
      });
    }

    try {
      await pad.player.stop();
      await pad.player.play(BytesSource(bytes));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        pad.active = false;
        lastAction = 'No se pudo reproducir el audio';
      });
    }
  }

  Future<void> stopAll() async {
    if (stopping) return;

    setState(() {
      stopping = true;
    });

    try {
      for (final pad in pads) {
        await pad.player.stop();
      }
    } finally {
      if (mounted) {
        setState(() {
          for (final pad in pads) {
            pad.active = false;
          }

          stopping = false;
          lastAction = 'Todos los sonidos detenidos';
        });
      }
    }
  }

  @override
  void dispose() {
    midiSubscription?.cancel();
    setupSubscription?.cancel();
    midi.dispose();

    for (final pad in pads) {
      pad.player.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF191B22),
        title: const Text(
          'SAMPLER PERRO PRO',
          style: TextStyle(
            color: Color(0xFFFFF315),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1D25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF363944),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PANEL DE CONTROL',
                    style: TextStyle(
                      color: Color(0xFFFFF315),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lastAction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    midiStatus,
                    style: TextStyle(
                      color: selectedDevice == null
                          ? Colors.white60
                          : const Color(0xFF65E69A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              loadingMidi ? null : refreshMidiDevices,
                          icon: loadingMidi
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: const Text('BUSCAR MIDI'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFF315),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: stopping ? null : stopAll,
                          icon: const Icon(Icons.stop_circle),
                          label: const Text(
                            'DETENER TODO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (devices.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<MidiDevice>(
                      value: selectedDevice,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Controlador MIDI',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Selecciona un dispositivo'),
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
                          connectMidi(device);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Notas MIDI 36 a 51 activan los pads 1 a 16.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    'TUS 16 PADS',
                    style: TextStyle(
                      color: Color(0xFFFFF315),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'CARGAR Y REPRODUCIR',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                itemCount: pads.length,
                itemBuilder: (context, index) {
                  final pad = pads[index];
                  final hasAudio = pad.audioBytes != null;

                  return Material(
                    color: pad.active
                        ? const Color(0xFFFFF315)
                        : const Color(0xFF22252E),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => playPad(index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: pad.active
                                ? const Color(0xFFFFF315)
                                : const Color(0xFF414552),
                            width: pad.active ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              hasAudio
                                  ? Icons.graphic_eq
                                  : Icons.add_circle_outline,
                              size: 27,
                              color: pad.active
                                  ? Colors.black
                                  : const Color(0xFFFFF315),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'PAD ${index + 1}',
                              style: TextStyle(
                                color: pad.active
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasAudio ? 'CARGADO' : 'VACÍO',
                              style: TextStyle(
                                color: pad.active
                                    ? Colors.black87
                                    : Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 2,
                                  ),
                                  minimumSize: const Size(0, 28),
                                  foregroundColor: pad.active
                                      ? Colors.black
                                      : const Color(0xFFFFF315),
                                  side: BorderSide(
                                    color: pad.active
                                        ? Colors.black54
                                        : const Color(0xFFFFF315),
                                  ),
                                ),
                                onPressed: () => loadSample(index),
                                child: const Text(
                                  'CARGAR',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
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
          ],
        ),
      ),
    );
  }
}
