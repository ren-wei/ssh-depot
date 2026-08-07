import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/parts/overview/parsers/overview_parser.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

Command overviewCommandFor(List<String> services) {
  return OverviewSnapshotCommand(services);
}

class OverviewSnapshotCommand extends Command {
  const OverviewSnapshotCommand(this.services);

  final List<String> services;

  @override
  String get summary => '刷新概览';

  @override
  String get text {
    final quotedServices = services.map(shellQuote).join(' ');
    return '''
$_overviewBaseCommand
for svc in $quotedServices; do
  status=\$(systemctl is-active "\$svc" 2>/dev/null || true)
  enabled=\$(systemctl is-enabled "\$svc" 2>/dev/null || true)
  printf "service=%s;status=%s;enabled=%s\\n" "\$svc" "\${status:-unknown}" "\${enabled:-unknown}"
done
''';
  }

  @override
  OverviewSnapshot? parse(RemoteCommandResult result) {
    if (!result.succeeded) {
      return null;
    }
    return const OverviewParser().parse(result.output);
  }
}

const _overviewBaseCommand = r'''
set -e
if command -v lsb_release >/dev/null 2>&1; then
  distribution=$(lsb_release -ds 2>/dev/null)
else
  . /etc/os-release
  distribution=${PRETTY_NAME:-unknown}
fi
kernel=$(uname -r 2>/dev/null || true)
uptime_text=$(uptime -p 2>/dev/null || uptime 2>/dev/null || true)
read _ cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal _ < /proc/stat
cpu_idle_1=$((cpu_idle + cpu_iowait))
cpu_total_1=$((cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq + cpu_steal))
sleep 0.2
read _ cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal _ < /proc/stat
cpu_idle_2=$((cpu_idle + cpu_iowait))
cpu_total_2=$((cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq + cpu_steal))
cpu_total_delta=$((cpu_total_2 - cpu_total_1))
cpu_idle_delta=$((cpu_idle_2 - cpu_idle_1))
if [ "$cpu_total_delta" -gt 0 ]; then
  cpu=$((100 * (cpu_total_delta - cpu_idle_delta) / cpu_total_delta))
else
  cpu=0
fi
memory=$(free -m | awk '/^Mem:/ { if ($2 > 0) printf "%.0f", (($2 - $7) * 100 / $2); }')
disk=$(df -P / | awk 'NR==2 { gsub(/%/, "", $5); print $5; }')
printf "distribution=%s\n" "$distribution"
printf "kernel=%s\n" "$kernel"
printf "uptime=%s\n" "$uptime_text"
printf "cpu=%s\n" "$cpu"
printf "memory=%s\n" "${memory:-0}"
printf "disk=%s\n" "${disk:-0}"
''';
