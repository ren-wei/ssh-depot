class ServerProfile {
  const ServerProfile({
    required this.name,
    required this.host,
    this.user = 'root',
    this.remark,
  });

  final String name;
  final String host;
  final String user;
  final String? remark;

  String get target => '$user@$host';

  ServerProfile copyWith({
    String? name,
    String? host,
    String? user,
    String? remark,
  }) {
    return ServerProfile(
      name: name ?? this.name,
      host: host ?? this.host,
      user: user ?? this.user,
      remark: remark ?? this.remark,
    );
  }
}
