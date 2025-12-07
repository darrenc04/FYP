import 'package:flutter/material.dart';

class SoundBarsAnimation extends StatelessWidget {
  final List<Animation<double>> barAnimations;

  const SoundBarsAnimation({super.key, required this.barAnimations});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (index) {
        return AnimatedBuilder(
          animation: barAnimations[index],
          builder: (context, child) {
            return Container(
              width: 20,
              height: 100 * barAnimations[index].value.clamp(0.1, 1.0),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          },
        );
      }),
    );
  }
}
