
Future<void> _loadSample(int index) async {
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'ogg', 'm4a', 'aac'],
    );

    if (files.isEmpty) return;

    final file = files.single;
    final path = file.path;

    if (path == null) {
      if (!mounted) return;
      setState(() => _status = 'No se pudo acceder al archivo');
      return;
    }

    if (!mounted) return;

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
