import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/command_runner/remote_command_runner.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_utils.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/parts/ssl/commands/ssl_commands.dart';
import 'package:ssh_depot/feature/parts/ssl/parsers/ssl_parsers.dart';

class SslCubit extends ChangeNotifier {
  SslCubit({required RemoteCommandRunner commandRunner}) : _commandRunner = commandRunner;

  final RemoteCommandRunner _commandRunner;

  List<NginxCertificateInfo> nginxCertificates = const [];

  Future<void> refreshCertificates() async {
    final result = await _commandRunner.runCaptureCommand(
      command: CommandWithSummary(
        command: certificateListCommand(),
        summary: '刷新证书列表',
      ),
      timeout: const Duration(seconds: 20),
    );
    if (result == null || !result.succeeded) {
      return;
    }

    nginxCertificates = parseCertificates(result.output);
    notifyListeners();
  }

  Future<RemoteCommandResult?> certificateDetails(String certName) {
    final cleanCertName = certName.trim();
    if (!isSafeCertificateName(cleanCertName)) {
      _commandRunner.setStatus('无效证书名称');
      return Future.value();
    }
    return _commandRunner.runCaptureCommand(
      command: CommandWithSummary(
        command: certificateDetailsCommand(cleanCertName),
        summary: '查看证书 $cleanCertName',
      ),
      timeout: const Duration(seconds: 12),
    );
  }

  Future<RemoteCommandResult?> checkCertificateEnvironment() {
    return _commandRunner.runCaptureCommand(
      command: certificateEnvironmentCommand(),
      timeout: const Duration(seconds: 20),
    );
  }

  Future<RemoteCommandResult?> requestCertificate({
    required String domain,
    required String email,
    required bool useWebroot,
    required String webroot,
  }) async {
    final domains = parseCertificateRequestDomains(domain);
    if (domains.isEmpty) {
      _commandRunner.setStatus('无效域名');
      return null;
    }
    if (email.trim().isEmpty) {
      _commandRunner.setStatus('请输入邮箱');
      return null;
    }
    if (useWebroot && webroot.trim().isEmpty) {
      _commandRunner.setStatus('请输入 Webroot 路径');
      return null;
    }
    final result = await _commandRunner.runCaptureCommand(
      command: CommandWithSummary(
        command: requestCertificateCommand(
          domains: domains,
          email: email,
          useWebroot: useWebroot,
          webroot: webroot,
        ),
        summary: '申请证书 ${domains.first}',
      ),
      timeout: const Duration(minutes: 5),
    );
    await refreshCertificates();
    return result;
  }

  Future<RemoteCommandResult?> renewCertificate(String certName, {bool dryRun = false}) async {
    final cleanCertName = certName.trim();
    if (!isSafeCertificateName(cleanCertName)) {
      _commandRunner.setStatus('无效证书名称');
      return null;
    }
    final result = await _commandRunner.runCaptureCommand(
      command: CommandWithSummary(
        command: renewCertificateCommand(cleanCertName, dryRun: dryRun),
        summary: dryRun ? '测试续期证书 $cleanCertName' : '续期证书 $cleanCertName',
      ),
      timeout: const Duration(minutes: 5),
    );
    await refreshCertificates();
    return result;
  }

  Future<RemoteCommandResult?> updateCertificateDomains({
    required String certName,
    required List<String> domains,
    required bool useWebroot,
    required String webroot,
  }) async {
    final cleanCertName = certName.trim();
    final cleanDomains = {
      for (final domain in domains) ...parseCertificateRequestDomains(domain),
    }.toList();
    if (!isSafeCertificateName(cleanCertName)) {
      _commandRunner.setStatus('无效证书名称');
      return null;
    }
    if (cleanDomains.isEmpty) {
      _commandRunner.setStatus('证书至少需要保留一个域名');
      return null;
    }
    if (useWebroot && webroot.trim().isEmpty) {
      _commandRunner.setStatus('请输入 Webroot 路径');
      return null;
    }
    final result = await _commandRunner.runCaptureCommand(
      command: CommandWithSummary(
        command: updateCertificateDomainsCommand(
          certName: cleanCertName,
          domains: cleanDomains,
          useWebroot: useWebroot,
          webroot: webroot,
        ),
        summary: '更新证书域名 $cleanCertName',
      ),
      timeout: const Duration(minutes: 5),
    );
    await refreshCertificates();
    return result;
  }

  Future<RemoteCommandResult?> deleteCertificate(String certName) async {
    final cleanCertName = certName.trim();
    if (!isSafeCertificateName(cleanCertName)) {
      _commandRunner.setStatus('无效证书名称');
      return null;
    }
    final result = await _commandRunner.runCaptureCommand(
      command: CommandWithSummary(
        command: deleteCertificateCommand(cleanCertName),
        summary: '删除证书 $cleanCertName',
      ),
      timeout: const Duration(minutes: 2),
    );
    await refreshCertificates();
    return result;
  }

  void clear() {
    nginxCertificates = const [];
    notifyListeners();
  }
}
