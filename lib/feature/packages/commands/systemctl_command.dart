import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

class SystemctlCommand extends Command {
  const SystemctlCommand._({
    required this.summary,
    required this.text,
    this.parser,
  });

  factory SystemctlCommand.serviceAction({
    required String unit,
    required String action,
    required String summary,
  }) {
    final actionText = switch (action) {
      'start' => 'start',
      'stop' => 'stop',
      'restart' => 'restart',
      'status' => 'status',
      _ => throw ArgumentError.value(action, 'action', 'Unsupported service action'),
    };
    final pagerArg = actionText == 'status' ? ' --no-pager' : '';
    return SystemctlCommand._(
      summary: summary,
      text: 'systemctl $actionText ${shellQuote(unit)}$pagerArg',
      parser: (result) => result,
    );
  }

  factory SystemctlCommand.start(String unit) {
    return SystemctlCommand._(summary: '启动服务', text: 'systemctl start ${shellQuote(unit)}');
  }

  factory SystemctlCommand.stop(String unit) {
    return SystemctlCommand._(summary: '停止服务', text: 'systemctl stop ${shellQuote(unit)}');
  }

  factory SystemctlCommand.restart(String unit) {
    return SystemctlCommand._(summary: '重启服务', text: 'systemctl restart ${shellQuote(unit)}');
  }

  factory SystemctlCommand.reload(String unit) {
    return SystemctlCommand._(summary: '重载服务', text: 'systemctl reload ${shellQuote(unit)}');
  }

  factory SystemctlCommand.status(String unit, {bool noPager = true}) {
    final pagerArg = noPager ? ' --no-pager' : '';
    return SystemctlCommand._(
      summary: '查看服务状态',
      text: 'systemctl status ${shellQuote(unit)}$pagerArg',
    );
  }

  factory SystemctlCommand.listServices() {
    return const SystemctlCommand._(
      summary: '搜索服务',
      text: 'systemctl list-unit-files --type=service --no-pager --no-legend; '
          'systemctl list-units --type=service --all --no-pager --no-legend',
    );
  }

  factory SystemctlCommand.serviceSnapshot(String unit) {
    final quotedUnit = shellQuote(unit);
    return SystemctlCommand._(
      summary: '获取服务状态',
      text: 'status=\$(systemctl is-active $quotedUnit 2>/dev/null || true); '
          'enabled=\$(systemctl is-enabled $quotedUnit 2>/dev/null || true); '
          'printf "service=%s;status=%s;enabled=%s\\n" $quotedUnit "\${status:-unknown}" "\${enabled:-unknown}"',
    );
  }

  @override
  final String summary;

  @override
  final String text;

  final Object? Function(RemoteCommandResult result)? parser;

  @override
  Object? parse(RemoteCommandResult result) => parser?.call(result);
}
