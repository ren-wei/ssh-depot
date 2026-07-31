class SshTarget {
  const SshTarget({required this.host, this.user = 'root'});

  final String host;
  final String user;

  String get address => '$user@$host';
}
