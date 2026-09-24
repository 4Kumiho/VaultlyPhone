import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_data.dart';

import 'theme.dart';

/// Riquadro con angoli arrotondati (come le "card" del desktop).
class VCard extends StatelessWidget {
  const VCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: VColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class Caption extends StatelessWidget {
  const Caption(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(color: VColors.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      );
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 13, this.align});
  final String text;
  final double size;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: align, style: TextStyle(color: VColors.muted, fontSize: size));
}

/// Pillola di un'etichetta.
class TagPill extends StatelessWidget {
  const TagPill(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: VColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(name,
            style: const TextStyle(color: Color(0xFF9DB8FF), fontSize: 11.5, fontWeight: FontWeight.w600)),
      );
}

/// Messaggio d'errore rosso sotto un modulo.
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: VColors.negative.withValues(alpha: 0.10),
                border: Border.all(color: VColors.negative.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(message!, style: const TextStyle(color: Color(0xFFFF8A8A))),
            ),
    );
  }
}

/// Scelta tra poche opzioni (Entrata/Uscita, 1S/1M/...).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.colors,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final Map<T, Color>? colors; // colore del segmento selezionato

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: VColors.background,
        border: Border.all(color: VColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(values[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: values[i] == selected
                        ? (colors?[values[i]] ?? VColors.control).withValues(alpha: colors == null ? 1 : 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: values[i] == selected ? (colors?[values[i]] ?? VColors.text) : VColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Struttura comune dei pannelli che salgono dal basso: titolo, contenuto scorrevole, pulsanti.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({super.key, required this.title, this.subtitle, required this.fields, required this.actions});

  final String title;
  final String? subtitle;
  final List<Widget> fields;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom; // tastiera
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Muted(subtitle!),
                ],
                const SizedBox(height: 18),
                ...fields,
                const SizedBox(height: 18),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Etichetta sopra un campo.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 10),
        child: Text(text,
            style: const TextStyle(color: Color(0xFFAAB1C2), fontSize: 12.5, fontWeight: FontWeight.w600)),
      );
}

/// Apre un pannello dal basso. Il pannello vive sopra l'app, fuori dal Provider dei dati:
/// glieli si passa di nuovo, altrimenti non li trova.
Future<T?> showSheet<T>(BuildContext context, Widget sheet) {
  final data = context.read<AppData>();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(value: data, child: sheet),
  );
}

/// Messaggio breve in basso. `tone`: null, 'warning' (giallo) o 'danger' (rosso).
void showToast(BuildContext context, String message, {String? tone}) {
  final color = switch (tone) {
    'warning' => VColors.warning,
    'danger' => VColors.negative,
    _ => VColors.borderStrong,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: Duration(seconds: tone == null ? 3 : 7),
      backgroundColor: tone == null ? VColors.control : Color.alphaBlend(color.withValues(alpha: 0.16), VColors.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color)),
      content: Text(message,
          style: TextStyle(
            color: tone == null ? VColors.text : Color.lerp(color, Colors.white, 0.45),
            fontWeight: FontWeight.w600,
          )),
    ));
}
