import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'photo_picker_stub.dart' if (dart.library.js_interop) 'photo_picker_web.dart' as picker;


/// Lato in pixel della foto salvata (quadrata, PNG).
const avatarPixels = 320;

/// Avatar dell'utente: la sua foto oppure l'iniziale sul colore scelto.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.photo, this.color = 0xFF5B8CFF, this.size = 44});

  final String name;
  final Uint8List? photo;
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Color(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.2),
        border: Border.all(color: c.withValues(alpha: 0.55), width: size > 60 ? 2.5 : 1.5),
        image: photo == null ? null : DecorationImage(image: MemoryImage(photo!), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: photo != null
          ? null
          : Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(
                color: Color.lerp(c, Colors.white, 0.35),
                fontWeight: FontWeight.w700,
                fontSize: size * 0.42,
              ),
            ),
    );
  }
}

/// Foto scelta → quadrato centrale di `avatarPixels` lato, PNG. null se non è un'immagine leggibile.
/// Tutto avviene sul telefono.
Future<Uint8List?> squareAvatar(Uint8List bytes, {int quarterTurns = 0}) async {
  try {
    // Si decodifica già ridotta (il lato corto a 2× la misura finale), per non usare troppa memoria.
    final codec = await ui.instantiateImageCodecWithSize(
      await ui.ImmutableBuffer.fromUint8List(bytes),
      getTargetSize: (width, height) {
        final scale = min(1.0, avatarPixels * 2 / min(width, height));
        return ui.TargetImageSize(width: (width * scale).round(), height: (height * scale).round());
      },
    );
    final image = (await codec.getNextFrame()).image;
    final side = min(image.width, image.height).toDouble();
    final src = Rect.fromLTWH((image.width - side) / 2, (image.height - side) / 2, side, side);
    const size = avatarPixels * 1.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (quarterTurns % 4 != 0) {
      canvas
        ..translate(size / 2, size / 2)
        ..rotate(quarterTurns * pi / 2)
        ..translate(-size / 2, -size / 2);
    }
    canvas.drawImageRect(image, src, const Rect.fromLTWH(0, 0, size, size), Paint()..filterQuality = FilterQuality.high);
    final out = await recorder.endRecording().toImage(avatarPixels, avatarPixels);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Apre la scelta della foto del telefono (galleria, fotocamera o file) e ne restituisce i byte.
Future<Uint8List?> pickPhoto() => picker.pickPhoto();
