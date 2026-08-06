part of 'connection_view.dart';

TextStyle _titleStyle(BuildContext context) {
  return Theme.of(
    context,
  ).textTheme.titleSmall!.copyWith(color: _text, fontWeight: FontWeight.w800);
}

TextStyle _captionStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall!.copyWith(color: _muted);
}

ButtonStyle _outlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: _text,
    disabledForegroundColor: _muted.withValues(alpha: 0.48),
    side: const BorderSide(color: _line),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _filledConnectButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _accent,
    foregroundColor: const Color(0xff042014),
    disabledBackgroundColor: _accent.withValues(alpha: 0.38),
    padding: const EdgeInsets.symmetric(horizontal: 28),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

T? _maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}
