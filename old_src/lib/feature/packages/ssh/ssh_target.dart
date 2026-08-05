class SshTarget {
  const SshTarget({required this.host, this.user = 'root', this.controlPath});

  final String host;
  final String user;
  final String? controlPath;

  String get address => '$user@$host';
}
