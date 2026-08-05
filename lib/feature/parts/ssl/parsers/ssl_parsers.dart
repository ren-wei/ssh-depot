import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_parser.dart';

List<NginxCertificateInfo> parseCertificates(String output) {
  return parseCertificateList(output);
}
