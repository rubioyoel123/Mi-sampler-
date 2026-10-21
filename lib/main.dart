
import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SamplerPerreoPro());
}

class SamplerPerreoPro extends StatelessWidget {
  const SamplerPerreoPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sampler Perreo PRO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101116),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF3158),
          secondary: Color(0xFFFF3158),
        ),
      ),
      home: const SamplerHome(),
    );
  }
}

class SamplerPad {
  SamplerPad(this.number);

  final int number;
  String name = 'PAD';
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

  late final List<SamplerPad> pads = List.generate(
    16,
    (index) => SamplerPad(index),
  );

  List<MidiDevice> devices = [];
  MidiDevice? selectedDevice;

  StreamSubscription<MidiDataReceivedEvent>? midiSubscription;
  StreamSubscription<MidiSetupChange>? setupSubscription;

  String midiStatus = 'MIDI desconectado';
  String lastAction = 'Carga un sonido y comienza a mezclar';
  bool loadingMidi = false;

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < pads.length; i++) {
      pads[i].name = 'PAD ${i + 1}';
    }

    initializeMidi();
  }

  Future<void> initializeMidi() async {
    midiSubscription = midi.onMidiDataReceived?.listen((event) {
      final message = event.message;

      if (message is NoteOnMessage && message.velocity > 0) {
        // Notas MIDI 36 a 51: los 16 pads del sampler.
        final padIndex = message.note - 36;

        if (padIndex >= 0 && padIndex < pads.length) {
          playPad(padIndex);
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

        if (selectedDevice != null &&
            !devices.any((d) => d.id == selectedDevice!.id)) {
          selectedDevice = null;
          midiStatus = 'Controlador desconectado';
        }

        loadingMidi = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingMidi = false;
        midiStatus = 'Error al buscar MIDI';
      });
    }
  }

  Future<void> connectMidi(MidiDevice? device) async {
    if (device == null) return;

    try {
      await midi.connectToDevice(device);

      if (!mounted) return;

      setState(() {
        selectedDevice = device;
        midiStatus = 'Conectado: ${device.name}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        midiStatus = 'No se pudo conectar al controlador';
      });
    }
  }

  Future<void> loadSample(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo de audio')),
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
  }

  Future<void> playPad(int index) async {
    if (index < 0 || index >= pads.length) return;

    final pad = pads[index];
    final bytes = pad.audioBytes;

    if (bytes == null) {
      if (mounted) {
        setState(() {
          lastAction = 'Carga un sonido en PAD ${index + 1}';
        });
      }
      return;
    }

    try {
      await pad.player.stop();
      await pad.player.play(BytesSource(bytes));

      if (!mounted) return;

      setState(() {
        pad.active = true;
        lastAction = 'Reproduciendo: ${pad.fileName ?? pad.name}';
      });

      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        setState(() {
          pad.active = false;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        lastAction = 'No se pudo reproducir el audio';
      });
    }
  }

  Future<void> stopAll() async {
    for (final pad in pads) {
      await pad.player.stop();
    }

    if (!mounted) return;

    setState(() {
      for (final pad in pads) {
        pad.active = false;
      }
      lastAction = 'Todos los sonidos detenidos';
    });
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
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF27202C),
                    Color(0xFF15151C),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF38313D)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.graphic_eq,
                        color: Color(0xFFFF3158),
                        size: 34,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'SAMPLER PERREO PRO',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '16 PADS  •  MIDI  •  AUDIO',
                    style: TextStyle(
                      color: Colors.white60,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<MidiDevice>(
                            isExpanded: true,
                            value: devices.any(
                              (d) => d.id == selectedDevice?.id,
                            )
                                ? selectedDevice
                                : null,
                            hint: Text(
                              devices.isEmpty
                                  ? 'No se encontraron dispositivos MIDI'
                                  : 'Selecciona tu controlador MIDI',
                            ),
                            items: devices.map((device) {
                              return DropdownMenuItem<MidiDevice>(
                                value: device,
                                child: Text(
                                  device.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: connectMidi,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Buscar controladores',
                        onPressed: loadingMidi ? null : refreshMidiDevices,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  Text(
                    midiStatus,
                    style: const TextStyle(
                      color: Color(0xFFFF647E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: GridView.builder(
                  itemCount: pads.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final pad = pads[index];

                    return Material(
                      color: pad.active
                          ? const Color(0xFFFF3158)
                          : const Color(0xFF22232B),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => playPad(index),
                        onLongPress: () => loadSample(index),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: pad.active
                                  ? Colors.white
                                  : const Color(0xFF41434E),
                              width: pad.active ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                pad.audioBytes == null
                                    ? Icons.add_circle_outline
                                    : Icons.graphic_eq,
                                size: 28,
                                color: pad.active
                                    ? Colors.white
                                    : const Color(0xFFFF647E),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'PAD ${index + 1}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pad.audioBytes == null
                                    ? 'Vacío'
                                    : (pad.fileName ?? 'Audio cargado'),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'MIDI ${36 + index}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white38,
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
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              color: const Color(0xFF191A21),
              child: Column(
                children: [
                  Text(
                    lastAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => loadSample(
                            pads.indexWhere(
                              (p) => p.audioBytes == null,
                            ) < 0
                                ? 0
                                : pads.indexWhere(
                                    (p) => p.audioBytes == null,
                                  ),
                          ),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('CARGAR AUDIO'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3158),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: stopAll,
                          icon: const Icon(Icons.stop),
                          label: const Text('STOP TODO'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Clic: reproducir  •  Clic derecho o mantener pulsado: cargar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
