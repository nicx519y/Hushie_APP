import 'package:flutter/material.dart';

class AudioFreeTag extends StatelessWidget {

  const AudioFreeTag({
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFFF2050), width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        'Free',
        style: const TextStyle(
          color: Color(0xFFFF2050),
          fontSize: 8,
          height: 1,
        ),
      ),
    );
  }
}