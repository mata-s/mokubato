import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({
    super.key,
    required this.focusNodes,
  });

  final List<FocusNode> focusNodes;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(focusNodes),
      builder: (context, _) {
        final isVisible = focusNodes.any((node) => node.hasFocus);

        if (!isVisible) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 44,
          color: const Color(0xFFF3F3F3),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              FocusScope.of(context).unfocus();
            },
            child: const Text('完了'),
          ),
        );
      },
    );
  }
}