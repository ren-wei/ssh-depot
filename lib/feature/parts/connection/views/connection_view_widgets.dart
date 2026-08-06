part of 'connection_view.dart';

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xff0a2016),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _lineDim),
      ),
      child: child,
    );
  }
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    this.controller,
    this.hintText,
    this.errorText,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(color: _text, fontWeight: FontWeight.w700),
      cursorColor: _accent,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        hintStyle: TextStyle(color: _muted.withValues(alpha: 0.72)),
        errorStyle: const TextStyle(color: Color(0xffff8a7a), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        filled: true,
        fillColor: const Color(0xff06170f),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _lineDim.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _lineDim),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xffff8a7a)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _accent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xffff8a7a)),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _captionStyle(context).copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _EmptySavedServers extends StatelessWidget {
  const _EmptySavedServers();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xff071a11),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _lineDim),
      ),
      child: Column(
        children: [
          Icon(Icons.dns_outlined, color: _muted.withValues(alpha: 0.75)),
          const SizedBox(height: 10),
          Text('暂无已保存服务器', style: _titleStyle(context)),
          const SizedBox(height: 4),
          Text('填写右侧表单后保存配置', style: _captionStyle(context)),
        ],
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
