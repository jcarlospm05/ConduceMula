import 'dart:io';

import 'package:administrador/incoming.dart';
import 'package:administrador/stage5_services.dart';
import 'package:flutter/material.dart';
import 'package:operador/design/mule_truck_logo.dart';

import '../application/unified_bundle.dart';

/// Etapa 5: Administrador simplificado. La capa del Supervisor no cambia.
class ReceivedReportsScreen extends StatefulWidget {
  const ReceivedReportsScreen({
    super.key,
    required this.bundle,
    this.incomingPath,
    this.onThemeToggle,
  });
  final UnifiedBundle bundle;
  final String? incomingPath;
  final VoidCallback? onThemeToggle;

  @override
  State<ReceivedReportsScreen> createState() => _ReceivedReportsScreenState();
}

class _ReceivedReportsScreenState extends State<ReceivedReportsScreen> {
  final keyInput = TextEditingController();
  final sourceInput = TextEditingController();
  late String? incomingPath = widget.incomingPath;
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  String stage = 'entry';
  bool busy = true;
  String? message;
  List<Map<String, Object?>> reports = [];
  List<Map<String, Object?>> cards = [];
  List<Map<String, Object?>> loose = [];
  List<String> notices = [];

  UnifiedBundle get bundle => widget.bundle;
  Stage5AdminServices get receiver {
    bundle.admin.actor = bundle.capture.operatorName;
    return Stage5AdminServices(
      bundle.admin,
      bundle.capture,
      bundle.services,
      access: bundle.profiles,
    );
  }

  String get date =>
      '${selectedDate.year.toString().padLeft(4, '0')}-'
      '${selectedDate.month.toString().padLeft(2, '0')}-'
      '${selectedDate.day.toString().padLeft(2, '0')}';

  String get phase => stage == 'entry' ? 'Entrada' : 'Salida';

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    keyInput.dispose();
    sourceInput.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!mounted || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await bundle.profiles.requireAdministrator();
      await action();
    } on FormatException catch (e) {
      message = e.message;
    } on StateError catch (e) {
      message = e.message.toString();
    } catch (_) {
      message = 'No se pudo completar. Comprueba los archivos y reintenta.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _loadRows() async {
    reports = await receiver.reports(date: date);
    cards = await receiver.cards(date, stage: stage);
    loose = await receiver.management.looseImages(date, stage: stage);
    notices = await receiver.warnings(date);
  }

  Future<void> reload() async {
    try {
      await bundle.profiles.requireAdministrator();
      await _loadRows();
    } catch (e) {
      message = e is StateError
          ? e.message.toString()
          : 'No fue posible actualizar el listado.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> receive() => _run(() async {
    final secret = keyInput.text.trim();
    final result = incomingPath == null
        ? await receiver.receive(
            key: secret.isEmpty ? null : secret,
          )
        : await receiver.importPath(
            incomingPath!,
            secret.isEmpty ? await bundle.services.password() : secret,
          );
    if (result == null) return;
    if (incomingPath != null) {
      await IncomingReports.remove(incomingPath!);
      incomingPath = null;
    }
    message = result.duplicate
        ? 'Revisión ya recibida. No se duplicaron fichas.'
        : 'Recibidas ${result.count} fichas ${result.format} (${result.stage == 'entry' ? 'entrada' : 'salida'}).';
    final parsed = DateTime.tryParse(result.date);
    if (parsed != null) selectedDate = parsed;
    await _loadRows();
  });

  Future<void> discard() => _run(() async {
    if (incomingPath == null) return;
    await IncomingReports.remove(incomingPath!);
    incomingPath = null;
    message = 'Se descartó la copia de recepción; el archivo original permanece.';
  });

  Future<void> syncOwn() => _run(() async {
    await receiver.syncOwn();
    message = 'Jornadas de este equipo incorporadas al Administrador.';
    await _loadRows();
  });

  Future<void> chooseDate() async {
    if (busy) return;
    final chosen = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (chosen == null || !mounted) return;
    selectedDate = chosen;
    await _run(() async {
      await _loadRows();
    });
  }

  Future<void> importPhoto() => _run(() async {
    if (sourceInput.text.trim().isEmpty) {
      throw const FormatException(
        'Escribe el supervisor o procedencia real de esta imagen.',
      );
    }
    final isNew = await receiver.chooseLooseJpg(
      date: date,
      stage: stage,
      source: sourceInput.text.trim(),
    );
    if (isNew == null) return;
    message = isNew
        ? 'JPG guardado como imagen sin ficha asociada.'
        : 'La imagen ya estaba archivada. No se duplicó.';
    await _loadRows();
  });

  Future<void> toggle(Map<String, Object?> card) => _run(() async {
    final include = card['included'] != true;
    await receiver.setIncluded(card, include);
    message = include ? 'Ficha incluida nuevamente.' : 'Ficha excluida del PDF.';
    await _loadRows();
  });

  Future<void> export() => _run(() async {
    final saved = await receiver.exportPdf(date, stage);
    message = saved
        ? 'PDF de $phase guardado.'
        : 'No se guardó el PDF; los datos permanecen intactos.';
  });

  Future<void> preview() => _run(() async {
    await receiver.previewPdf(date, stage);
  });

  Future<void> backup() => _run(() async {
    final saved = await receiver.backup();
    message = saved
        ? 'Respaldo administrativo cifrado guardado.'
        : 'Guardado cancelado. No se eliminaron datos.';
  });

  Future<void> restoreBackup() => _run(() async {
    final key = keyInput.text.trim();
    final restored = await receiver.restore(
      key: key.isEmpty ? null : key,
    );
    if (restored == null) return;
    message = restored
        ? 'Respaldo restaurado; se verificaron sus archivos.'
        : 'No se restauró el respaldo.';
    await _loadRows();
  });

  Future<void> photo(String path) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Cerrar imagen',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.file(bundle.services.file(path), fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget action(String name, IconData icon, VoidCallback callback,
      {bool primary = false}) {
    if (primary) {
      return FilledButton.icon(
        onPressed: busy ? null : callback,
        icon: Icon(icon),
        label: Text(name),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(name),
      onTap: busy ? null : callback,
    );
  }

  Widget reportCard(Map<String, Object?> row) {
    final isJpg = row['format'] == 'JPG';
    final isEntry = row['stage'] == 'entry';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(isEntry ? Icons.login : Icons.logout),
      title: Text(
        '${row['date']} · ${isEntry ? 'Entrada' : 'Salida'} · '
        '${isJpg ? 'JPG' : 'PDF histórico'}',
      ),
      subtitle: Text(
        'Origen: ${row['supervisor'] ?? row['device']} · '
        'Revisión ${row['number']}',
      ),
    );
  }

  Widget ticketCard(Map<String, Object?> row) {
    final included = row['included'] == true;
    final path = row['photo_path'] ?? row['jpg_path'];
    final photoPath = path is String ? path : null;
    return Opacity(
      opacity: included ? 1 : 0.54,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (photoPath != null)
                    InkWell(
                      onTap: () => photo(photoPath),
                      child: Image.file(
                        bundle.services.file(photoPath),
                        width: 84,
                        height: 72,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mula ${row['code']}',
                          style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('${row['provider']} · ${row['time']}'),
                        Text('Horómetro: ${row['meter']} h'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Origen: ${row['supervisor']} · Revisión ${row['revision_number']}'),
              if (row['possible_duplicate'] == true)
                const Text('Atención: código repetido; verificar antes de incluir.'),
              if (!included)
                const Text('Excluida del consolidado',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : () => toggle(row),
                  icon: Icon(included
                      ? Icons.remove_circle_outline : Icons.add_circle_outline),
                  label: Text(included ? 'Excluir' : 'Volver a incluir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 20,
      title: const Row(
        children: [
          MuleTruckLogo(size: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MuleAgent',
                  style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Administrador', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (widget.onThemeToggle != null)
          IconButton(
            onPressed: widget.onThemeToggle,
            tooltip: 'Cambiar tema',
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Administrar jornadas',
            style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          const Text('Importa cierres .mule de varios supervisores, '
            'revisa las fichas y prepara PDF de Entrada o Salida.'),
          const SizedBox(height: 16),
          TextField(
            controller: keyInput,
            obscureText: true,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Clave distinta del paquete (opcional)'),
          ),
          const SizedBox(height: 12),
          action(
            incomingPath == null
                ? 'Recibir archivo .mule'
                : 'Importar archivo recibido',
            Icons.file_download_outlined, receive, primary: true),
          if (incomingPath != null)
            action('Descartar copia recibida', Icons.close, discard),
          action('Incorporar jornadas de este equipo',
            Icons.sync, syncOwn),
          const Divider(height: 32),
          Text('Fecha y etapa',
            style: Theme.of(context).textTheme.titleLarge),
          action('Fecha: $date', Icons.calendar_month, chooseDate),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: stage,
            decoration: const InputDecoration(labelText: 'Etapa'),
            items: const [
              DropdownMenuItem(value: 'entry', child: Text('Entrada')),
              DropdownMenuItem(value: 'exit', child: Text('Salida')),
            ],
            onChanged: busy ? null : (value) async {
              if (value == null) return;
              stage = value;
              await _run(_loadRows);
            },
          ),
          const SizedBox(height: 16),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(message!),
            ),
          for (final notice in notices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(notice)),
                ],
              ),
            ),
          const Divider(height: 32),
          Text('Fichas consolidadas · $phase',
            style: Theme.of(context).textTheme.titleLarge),
          if (!busy && cards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No hay fichas para esta selección.'),
            ),
          for (final card in cards) ticketCard(card),
          const SizedBox(height: 12),
          Text('Imágenes sin ficha asociada',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: sourceInput,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Supervisor o procedencia declarada'),
          ),
          action('Importar JPG por fecha y etapa',
            Icons.add_photo_alternate_outlined, importPhoto),
          for (final row in loose)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined),
              title: Text('${row['name']}'),
              subtitle: Text(
                'Sin vincular a ficha · Origen: ${row['source']}'),
              onTap: () => photo(row['local_path'] as String),
            ),
          const Divider(height: 32),
          action('Generar PDF de $phase',
            Icons.picture_as_pdf_outlined, export, primary: true),
          action('Vista previa PDF de $phase',
            Icons.print_outlined, preview),
          action('Guardar respaldo administrativo',
            Icons.backup_outlined, backup),
          action('Restaurar respaldo administrativo',
            Icons.restore_outlined, restoreBackup),
          const Divider(height: 32),
          Text('Reportes recibidos',
            style: Theme.of(context).textTheme.titleLarge),
          for (final report in reports) reportCard(report),
          if (!busy && reports.isEmpty)
            const Text('No hay reportes recibidos para esta fecha.'),
        ],
      ),
    ),
  );
}
