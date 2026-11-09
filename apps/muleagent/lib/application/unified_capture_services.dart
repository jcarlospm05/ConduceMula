import 'dart:convert';
import 'dart:io';
import 'package:operador/delivery/mule_delivery.dart';

import 'package:administrador/services.dart';
import 'package:admin_data/admin_data.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mule_data/mule_data.dart';
import 'package:mule_profiles/mule_profiles.dart';
import 'package:operador/services.dart';

/// One capture/backup path for both roles. Installation capability is never restored.
class UnifiedCaptureServices extends OperatorServices {
  UnifiedCaptureServices(
    super.repo,
    super.root,
    this.profiles,
    this.admin, {
    super.publicStorageEnabled = true,
  });
  final ProfileRepository profiles;
  final AdminRepository admin;
  late final MuleDelivery delivery = MuleDelivery(this);

  @override
  Future<bool> hasNewDelivery(CaptureSession session) async =>
      (await repo.db.query('artifacts',
          where: 'revision_id=?', whereArgs: [session.id])).isEmpty;

  @override
  Future<String?> publicFolder(CaptureSession session) =>
      delivery.publicFolder(session);

  @override
  Future<String?> savePublicReport(
    CaptureSession session, {
    bool prepared = false,
  }) => delivery.savePublic(session, prepared: prepared);

  @override
  Future<int> recoverPublicReports({bool verifyAll = false}) =>
      delivery.recoverPublic(verifyAll: verifyAll);

  @override
  Future<void> share(CaptureSession session) => delivery.share(session);

  /// Include JPG and encrypted delivery files in the pre-existing backup.
  /// No schema change: a versioned, immutable manifest lives in settings.
  @override
  Future<Map<String, dynamic>> includeFiles(
    Map<String, dynamic> snapshot, {
    List<String> extra = const [],
  }) async {
    final settings = (snapshot['tables'] as Map)['settings'];
    final additional = <String>{...extra};
    final manifests = <MuleDeliveryBundle>[];
    if (settings is List) {
      for (final row in settings) {
        if (row is! Map ||
            row['key'] is! String ||
            !(row['key'] as String).startsWith('delivery_v2_')) {
          continue;
        }
        final manifest = MuleDeliveryBundle.fromJson(
          Map<String, dynamic>.from(jsonDecode(row['value'] as String) as Map),
        );
        manifests.add(manifest);
        additional.addAll(manifest.privatePaths);
      }
    }
    final result = await super.includeFiles(
      snapshot,
      extra: additional.toList(),
    );
    final files = result['files'] as Map;
    for (final manifest in manifests) {
      if (files[manifest.packagePath]['sha256'] != manifest.packageSha256) {
        throw StateError('El paquete del respaldo cambió de contenido.');
      }
      for (final card in manifest.cards) {
        if (files[card.path]['sha256'] != card.sha256) {
          throw StateError('Una ficha JPG cambió de contenido.');
        }
      }
    }
    return result;
  }

  final ProfileRepository profiles;
  final AdminRepository admin;
  AdminServices get administration =>
      AdminServices(admin, repo, this, access: profiles);

  @override
  Future<bool> backup() async {
    final profile = await profiles.load();
    if (profile == null) {
      throw StateError('Configura el perfil antes de crear un respaldo.');
    }
    if (!profile.canSwitchRoles) return super.backup();
    return administration.backup();
  }

  @override
  Future<bool> restore(String key) async {
    final selected = await FilePicker.platform.pickFiles(type: FileType.any);
    if (selected == null) return false;
    final path = selected.files.single.path;
    if (path == null) throw StateError('No se pudo abrir el respaldo.');
    final source = File(path);
    if (await source.length() > PackageCodec.maxBytes * 2) {
      throw StateError('Archivo demasiado grande.');
    }
    final payload = await compute(decryptPayload, {
      'bytes': await source.readAsBytes(),
      'password': key,
    });
    return restorePayload(payload);
  }

  @override
  Future<bool> restorePayload(Map<String, dynamic> payload) async {
    if (payload['app'] != 'administrator' &&
        payload['kind'] == 'backup') {
      final settings = (payload['tables'] as Map)['settings'];
      final files = payload['files'] as Map;
      if (settings is List) {
        for (final row in settings) {
          if (row is! Map ||
              row['key'] is! String ||
              !(row['key'] as String).startsWith('delivery_v2_')) {
            continue;
          }
          final manifest = MuleDeliveryBundle.fromJson(
            Map<String, dynamic>.from(jsonDecode(row['value'] as String) as Map),
          );
          if (files[manifest.packagePath]?['sha256'] !=
              manifest.packageSha256) {
            throw const FormatException('Falta el paquete cifrado del cierre.');
          }
          for (final card in manifest.cards) {
            if (files[card.path]?['sha256'] != card.sha256) {
              throw const FormatException('Falta una ficha JPG del cierre.');
            }
          }
        }
      }
    }
    if (payload['app'] == 'administrator') {
      // Received archives can only enter an Administrator installation/profile.
      await profiles.requireAdministrator();
      return administration.restorePayload(payload, merge: true);
    }
    return super.restorePayload(payload);
  }
}
