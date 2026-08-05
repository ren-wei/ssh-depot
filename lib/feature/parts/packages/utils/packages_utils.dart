import 'package:ssh_depot/feature/utils/shell_quote.dart';

bool isSafePackageName(String value) {
  return RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9+._:-]*$').hasMatch(value);
}

String installPackageCommand(String packageName) {
  return 'apt update && apt install -y ${shellQuote(packageName)}';
}

String removePackageCommand(String packageName) {
  return 'apt remove -y ${shellQuote(packageName)}';
}
