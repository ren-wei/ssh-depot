import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/parts/nginx/utils/nginx_utils.dart';

import '../utils/ssl_utils.dart';

class SslCubit extends ChangeNotifier {
  SslCubit({required CommandRunnerCubit commandRunnerCubit}) : _commandRunnerCubit = commandRunnerCubit;

  final CommandRunnerCubit _commandRunnerCubit;

  List<NginxCertificateInfo> nginxCertificates = const [];

  Future<void> refreshCertificates() async {
    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '刷新证书列表',
      command: certificateListCommand(),
      timeout: const Duration(seconds: 20),
    );
    if (result == null || !result.succeeded) {
      return;
    }

    final certificates = <NginxCertificateInfo>[];
    for (final line in const LineSplitter().convert(result.output)) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty || cleanLine == '__certificates__') {
        continue;
      }
      final certificate = parseCertificateLine(cleanLine);
      if (certificate != null) {
        certificates.add(certificate);
      }
    }
    nginxCertificates = certificates;
    notifyListeners();
  }

  Future<RemoteCommandResult?> certificateDetails(String certName) {
    final cleanCertName = certName.trim();
    if (!isSafeCertificateName(cleanCertName)) {
      _commandRunnerCubit.setStatus('无效证书名称');
      return Future.value();
    }
    return _commandRunnerCubit.runCaptureRemote(
      summary: '查看证书 $cleanCertName',
      command: certificateDetailsCommand(cleanCertName),
      timeout: const Duration(seconds: 12),
    );
  }

  Future<RemoteCommandResult?> checkCertificateEnvironment() {
    return _commandRunnerCubit.runCaptureRemote(
      summary: '检查证书环境',
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
      _commandRunnerCubit.setStatus('无效域名');
      return null;
    }
    if (email.trim().isEmpty) {
      _commandRunnerCubit.setStatus('请输入邮箱');
      return null;
    }
    if (useWebroot && webroot.trim().isEmpty) {
      _commandRunnerCubit.setStatus('请输入 Webroot 路径');
      return null;
    }
    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '申请证书 ${domains.first}',
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
      _commandRunnerCubit.setStatus('无效证书名称');
      return null;
    }
    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: dryRun ? '测试续期证书 $cleanCertName' : '续期证书 $cleanCertName',
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
      _commandRunnerCubit.setStatus('无效证书名称');
      return null;
    }
    if (cleanDomains.isEmpty) {
      _commandRunnerCubit.setStatus('证书至少需要保留一个域名');
      return null;
    }
    if (useWebroot && webroot.trim().isEmpty) {
      _commandRunnerCubit.setStatus('请输入 Webroot 路径');
      return null;
    }
    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '更新证书域名 $cleanCertName',
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
      _commandRunnerCubit.setStatus('无效证书名称');
      return null;
    }
    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '删除证书 $cleanCertName',
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
