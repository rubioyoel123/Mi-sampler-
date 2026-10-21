Import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';

void main() {
  runApp(const MiSamplerApp());
}

class MiSamplerApp extends StatelessWidget {
  const MiSamplerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Sampler - DJ Dannys Yoel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.deepPurpleAccent,
        ),
      ),
      home: const SamplerAudio(),
    );
  }
}

class SamplerAudio extends StatefulWidget {
  const SamplerAudio({super.key});

  @override
  State<SamplerAudio> createState() => _SamplerAudioState();
}

class _SamplerAudioState extends State<SamplerAudio> {
  final MidiCommand _midiCommand = MidiCommand();

  final List<AudioPlayer> _players =
      List<AudioPlayer>.generate(8, (_) => AudioPlayer());

  final List<String?> _samplePaths = List<String?>.filled(8, null);

  StreamSubscription? _midiSubscription;
  StreamSubscription? _setupSubscription;

  MidiDevice? _connectedDevice;

  double _playbackRate = 1.0;

  @override
  void initState() {
    super.initState();

    _midiSubscription =
        _midiCommand.onMidiDataReceived?.listen(_handleMidiData);

    _setupSubscription =
        _midiCommand.onMidiSetupChanged?.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _midiSubscription?.cancel();
    _setupSubscription?.cancel();

    for (final player in _players) {
      player.dispose();
    }

    super.dispose();
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickFile(int index) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;

      if (path == null || path.isEmpty) {
        await _showMessage('No se pudo obtener la ruta del audio.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _samplePaths[index] = path;
      });

      await _showMessage(
        'Audio cargado en PAD ${index + 1}.',
      );
    } catch (e) {
      await _showMessage('Error al cargar el audio: $e');
    }
  }

  Future<void> _playSound(int index) async {
    final path = _samplePaths[index];

    if (path == null || path.isEmpty) {
      await _showMessage(
        'Carga un audio en PAD ${index + 1} primero.',
      );
      return;
    }

    try {
      final player = _players[index];

      await player.stop();
      await player.setPlaybackRate(_playbackRate);
      await player.play(DeviceFileSource(path));
    } catch (e) {
      await _showMessage('Error al reproducir el audio: $e');
    }
  }

  void _handleMidiData(List<int> data) {
    if (data.length < 3) return;

    final status = data[0];
    final data1 = data[1];
    final data2 = data[2];

    final command = status & 0xF0;

    // Note On: pulsación de un pad MIDI.
    if (command == 0x90 && data2 > 0) {
      // Asigna las notas MIDI 36 a 43 directamente a los 8 pads.
      final padIndex =
          (data1 >= 36 && data1 <= 43) ? data1 - 36 : data1 % 8;

      _playSound(padIndex);
    }

    // Pitch Bend: control de velocidad de reproducción.
    else if (command == 0xE0) {
      final pitchValue = (data2 << 7) | data1;

      final factor = 1.0 + ((pitchValue - 8192) / 8192.0);

      final double rate = factor.clamp(0.5, 2.0).toDouble();

      _setPlaybackRate(rate);
    }
  }

  Future<void> _setPlaybackRate(double rate) async {
    _playbackRate = rate;

    for (final player in _players) {
      try {
        await player.setPlaybackRate(rate);
      } catch (_) {
        // Algunos reproductores pueden no admitir esta función.
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectMidiDevice() async {
    try {
      final devices = await _midiCommand.devices;

      if (!mounted) return;

      if (devices.isEmpty) {
        await _showMessage(
          'No se encontraron dispositivos MIDI. '
          'Conecta tu controlador y vuelve a intentarlo.',
        );
        return;
      }

      final selectedDevice = await showDialog<MidiDevice>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Seleccionar controlador MIDI'),
            content: SizedBox(
              width: 420,
              height: 300,
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];

                  return ListTile(
                    leading: Icon(
                      device.connected
                          ? Icons.usb
                          : Icons.piano,
                      color: device.connected
                          ? Colors.greenAccent
                          : Colors.white70,
                    ),
                    title: Text(device.name),
                    subtitle: Text(
                      device.connected
                          ? 'Conectado'
                          : 'Desconectado',
                    ),
                    onTap: () {
                      Navigator.of(dialogContext).pop(device);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );

      if (selectedDevice == null || !mounted) return;

      try {
        if (selectedDevice.connected) {
          await _midiCommand.disconnectDevice(selectedDevice);

          setState(() {
            _connectedDevice = null;
          });

          await _showMessage('Controlador MIDI desconectado.');
        } else {
          await _midiCommand.connectToDevice(selectedDevice);

          if (!mounted) return;

          setState(() {
            _connectedDevice = selectedDevice;
          });

          await _showMessage(
            'Controlador conectado: ${selectedDevice.name}',
          );
        }
      } catch (e) {
        await _showMessage('Error de conexión MIDI: $e');
      }
    } catch (e) {
      await _showMessage('Error al buscar dispositivos MIDI: $e');
    }
  }

  String _fileName(int index) {
    final path = _samplePaths[index];

    if (path == null || path.isEmpty) {
      return 'Cargar audio';
    }

    return path.split(RegExp(r'[/\\]')).last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Sampler MIDI'),
        backgroundColor: Colors.black26,
        actions: [
          IconButton(
            tooltip: 'Conectar controlador MIDI',
            icon: Icon(
              Icons.piano,
              color: _connectedDevice != null
                  ? Colors.greenAccent
                  : Colors.white,
            ),
            onPressed: _selectMidiDevice,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.music_note,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectedDevice?.name ??
                        'Controlador MIDI no conectado',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(_playbackRate * 100).round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Material(
                  color: Colors.blueAccent.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _playSound(index),
                    onLongPress: () => _pickFile(index),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white24,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.graphic_eq,
                            size: 30,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'PAD ${index + 1}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _fileName(index),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
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
            padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Text(
              'Toca un pad para reproducir. '
              'Mantén pulsado para cargar un audio.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
