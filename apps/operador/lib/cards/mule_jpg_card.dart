import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_codec;
import 'package:mule_data/mule_data.dart';

/// Etapa 4: ficha JPG independiente por mula.
/// No reescribe la fotografía original ni la recorta.
///
/// La identidad impresa (id de ficha + revisión + origen) permite distinguir
/// fichas homónimas y respaldos de revisiones anteriores. Los metadatos
/// estructurados viajan separados dentro del paquete .mule.
Future<Uint8List> renderMuleJpgCard({
  required CaptureSession session,
  required Map<String, Object?> ticket,
  required int revisionNumber,
  required String supervisor,
  Uint8List? originalPhoto,
  Uint8List? officialLogo,
}) async {
  const width = 1200;
  const height = 1740;
  const navy = Color(0xFF0B132B);
  const cyan = Color(0xFF5BC0DE);
  const cream = Color(0xFFF4D6B0);
  const subdued = Color(0xFF596273);
  const border = Color(0xFFD7DADF);
  const orange = Color(0xFFD97706);
  const white = Colors.white;

  if (revisionNumber < 1) {
    throw ArgumentError.value(revisionNumber, 'revisionNumber');
  }
  final code = (ticket['code'] ?? '').toString().trim();
  final provider = (ticket['provider'] ?? '').toString().trim();
  final meter = (ticket['meter'] ?? '').toString().trim();
  final time = (ticket['time'] ?? '').toString().trim();
  final ticketId = (ticket['id'] ?? '').toString();
  final evidenceState = (ticket['evidence_state'] ?? '').toString();
  if (code.isEmpty || provider.isEmpty || meter.isEmpty || time.isEmpty ||
      ticketId.isEmpty || !{'photo', 'omitted'}.contains(evidenceState)) {
    throw const FormatException('Ficha incompleta: no puede generarse el JPG.');
  }
  if (evidenceState == 'photo' && (originalPhoto == null || originalPhoto.isEmpty)) {
    throw StateError('Falta la fotografía original del horómetro.');
  }
  if (evidenceState == 'omitted' &&
      (ticket['omission_reason'] ?? '').toString().trim().isEmpty) {
    throw const FormatException('Indica por qué se omitió la fotografía.');
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paper = Paint()..color = white;
  canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paper);

  void rectangle(Rect rect, Color color, {double radius = 0}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  void write(
    String value,
    double x,
    double y, {
    double size = 32,
    Color color = navy,
    FontWeight weight = FontWeight.w400,
    double maxWidth = 1090,
    int maxLines = 2,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: 1.20,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    text.paint(canvas, Offset(x, y));
    text.dispose();
  }

  void field(String label, String value, double y, {double x = 55, double maxWidth = 1090}) {
    write(label.toUpperCase(), x, y, size: 25, color: subdued,
        weight: FontWeight.w600, maxWidth: maxWidth);
    write(value.isEmpty ? '—' : value, x, y + 37, size: 43,
        color: navy, weight: FontWeight.w700, maxWidth: maxWidth, maxLines: 2);
  }

  // Encabezado según INTERFAZ_MULEAGENT_V1.
  rectangle(Rect.fromLTWH(0, 0, width.toDouble(), 210), navy);
  final stageName = session.stage == Stage.entry ? 'ENTRADA' : 'SALIDA';
  if (session.stage == Stage.exit) {
    rectangle(Rect.fromLTWH(0, 201, width.toDouble(), 9), orange);
  } else {
    rectangle(Rect.fromLTWH(0, 201, width.toDouble(), 9), cyan);
  }
  if (officialLogo != null && officialLogo.isNotEmpty) {
    final codec = await ui.instantiateImageCodec(officialLogo, targetWidth: 170);
    final frame = await codec.getNextFrame();
    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(35, 22, 162, 162),
      image: frame.image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    frame.image.dispose();
    codec.dispose();
  }
  write('MuleAgent', 214, 42, size: 62, color: white,
      weight: FontWeight.w700, maxWidth: 900, maxLines: 1);
  write('FICHA DE $stageName', 217, 124, size: 31, color: cream,
      weight: FontWeight.w600, maxWidth: 900, maxLines: 1);

  write('FECHA DE JORNADA', 55, 244, size: 24, color: subdued);
  write(session.date, 55, 280, size: 38, weight: FontWeight.w700);
  write('REVISIÓN $revisionNumber', 804, 280, size: 34,
      weight: FontWeight.w600, maxWidth: 350, maxLines: 1);
  rectangle(const Rect.fromLTWH(55, 349, 1090, 2), border);

  field('Mula', code, 374);
  field('Proveedor', provider, 491);

  if (session.stage == Stage.entry) {
    field('Mulero', (ticket['driver'] ?? '').toString().trim(), 609);
  } else {
    field('Etapa', 'Salida de mula', 609);
  }

  field('Hora', time, 727, maxWidth: 500);
  field('Horómetro', '$meter h', 727, x: 580, maxWidth: 560);

  write('EVIDENCIA DE HORÓMETRO', 55, 858, size: 26,
      color: subdued, weight: FontWeight.w600);
  rectangle(const Rect.fromLTWH(55, 904, 1090, 640), const Color(0xFFF8F6F3), radius: 14);
  final line = Paint()
    ..color = border
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(55, 904, 1090, 640),
        const Radius.circular(14)),
    line,
  );
  if (evidenceState == 'photo') {
    final codec = await ui.instantiateImageCodec(
      originalPhoto!,
      targetWidth: 1060,
      targetHeight: 610,
    );
    final frame = await codec.getNextFrame();
    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(73, 922, 1054, 604),
      image: frame.image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    frame.image.dispose();
    codec.dispose();
  } else {
    write('FOTOGRAFÍA OMITIDA', 110, 1120, size: 40,
        weight: FontWeight.w700, maxWidth: 980);
    write((ticket['omission_reason'] ?? '').toString(), 110, 1185,
        size: 31, color: subdued, maxWidth: 980, maxLines: 4);
  }

  rectangle(const Rect.fromLTWH(55, 1578, 1090, 2), border);
  write('REGISTRADO POR', 55, 1603, size: 23,
      color: subdued, weight: FontWeight.w600);
  write(supervisor.trim().isEmpty ? 'Sin identificar' : supervisor.trim(),
      55, 1636, size: 29, weight: FontWeight.w600,
      maxWidth: 610, maxLines: 1);
  write('IDENTIFICADOR DE FICHA', 710, 1603, size: 23,
      color: subdued, weight: FontWeight.w600, maxWidth: 440);
  write(ticketId, 710, 1636, size: 21,
      weight: FontWeight.w500, maxWidth: 440, maxLines: 2);

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(width, height);
  picture.dispose();
  final pngData = await rendered.toByteData(format: ui.ImageByteFormat.png);
  rendered.dispose();
  if (pngData == null) {
    throw StateError('No se pudo convertir la ficha a JPG.');
  }
  final decoded = image_codec.decodePng(pngData.buffer.asUint8List());
  if (decoded == null) {
    throw StateError('No se pudo codificar la imagen final.');
  }
  return Uint8List.fromList(image_codec.encodeJpg(decoded, quality: 88));
}
