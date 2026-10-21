
  Future<void> loadSample(int index) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.audio,
      );

      if (files.isEmpty) return;

      final file = files.first;
      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El archivo de audio está vacío'),
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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar el audio: $e'),
        ),
      );
    }
  }
