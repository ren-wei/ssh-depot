import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/command_runner/command_runner.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_utils.dart';
import 'package:ssh_depot/feature/parts/ssl/commands/ssl_commands.dart';

class SslCubit extends ChangeNotifier {
  SslCubit({required CommandRunner commandRunner}) : _commandRunner = commandRunner;

  final CommandRunner _commandRunner;

  List<NginxCertificateInfo> nginxCertificates = const [];

  Future<void> refreshCertificates() async {
    final certificates = await _commandRunner.runCaptureCommand(
      command: certificateListCommand(),
      timeout: const Duration(seconds: 20),
    );
    if (certificates == null) {
      return;
    }

    nginxCertificates = certificates;
    notifyListeners();
  }

  Future<RemoteCommandResult?> certificateDetails(String certName) {
    final cleanCertName = certName.trim();
    if (!isSafeCertificateName(cleanCertName)) {
      _commandRunner.setStatus('无效证书名称');
      return Future.value();
    }
    return _commandRunner.runCaptureCommand(
      command: certificateDetailsCommand(cleanCertName),
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
      command: requestCertificateCommand(
        domains: domains,
        email: email,
        useWebroot: useWebroot,
        webroot: webroot,
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
      command: renewCertificateCommand(cleanCertName, dryRun: dryRun),
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
      command: updateCertificateDomainsCommand(
        certName: cleanCertName,
        domains: cleanDomains,
        useWebroot: useWebroot,
        webroot: webroot,
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
      command: deleteCertificateCommand(cleanCertName),
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
