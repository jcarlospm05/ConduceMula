import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Flutter-to-Android bridge: the native layer sets ACTION_SEND_MULTIPLE,
/// application/octet-stream and ClipData read grants explicitly.
/// share_plus 12 can infer MIME from file extensions despite an XFile override,
/// so it is not used to launch the mixed JPG + .mule outgoing share.
class MuleShareDocuments {
  static const channel = MethodChannel('muleagent/share-documents');

  static Future<void> share(ShareParams params) async {
    final files = params.files;
    final names = params.fileNameOverrides;
    if (params.text != null || files == null || files.isEmpty ||
        names == null || names.length != files.length ||
        names.toSet().length != names.length) {
      throw StateError('La lista de documentos a compartir no es válida.');
    }
    final result = await channel.invokeMapMethod<String, dynamic>(
      'share',
      {
        'files': [
          for (var i = 0; i < files.length; i++)
            {'source': files[i].path, 'name': names[i]},
        ],
      },
    );
    if (result == null || result['prepared'] != files.length) {
      throw StateError('Android no pudo preparar todos los archivos.');
    }
    // The chooser opening is not proof of actual WhatsApp delivery.
  }
}
