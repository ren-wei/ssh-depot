import 'package:flutter/material.dart';

import 'app_shell.dart';

void showDepotSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: depotText.withValues(alpha: 0.92),
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: depotPanel,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: depotLineDim),
      ),
    ),
  );
}
