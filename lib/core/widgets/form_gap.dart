import 'package:flutter/material.dart';

/// Vertical gap between form fields (~14 logical px).
const double kFormFieldGap = 14;

class FormGap extends StatelessWidget {
  const FormGap({super.key, this.height = kFormFieldGap});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// Nearly full-width dialog inset for phone form modals.
const EdgeInsets kFormDialogInset =
    EdgeInsets.symmetric(horizontal: 12, vertical: 24);
