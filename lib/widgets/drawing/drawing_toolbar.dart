import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/drawing_stroke.dart';
import '../../viewmodels/drawing_canvas_controller.dart';

/// Tool, colour and size picker plus undo/redo/clear for a [DrawingCanvas].
///
/// Laid out as two scrollable rows so it stays usable on small phones without
/// stealing height from the canvas.
class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({
    required this.controller,
    this.showColors = true,
    super.key,
  });

  final DrawingCanvasController controller;
  final bool showColors;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final tool in controller.availableTools)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _ToolButton(
                                  tool: tool,
                                  selected: controller.tool == tool,
                                  accent: tool.isEraser
                                      ? AppColors.ink
                                      : controller.color,
                                  onTap: () => controller.selectTool(tool),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ActionButton(
                      icon: Icons.undo,
                      tooltip: 'Undo',
                      onPressed: controller.canUndo ? controller.undo : null,
                    ),
                    _ActionButton(
                      icon: Icons.redo,
                      tooltip: 'Redo',
                      onPressed: controller.canRedo ? controller.redo : null,
                    ),
                    _ActionButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Clear page',
                      onPressed: controller.strokes.isEmpty
                          ? null
                          : () => _confirmClear(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (showColors)
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final color
                                  in DrawingCanvasController.palette)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _ColorDot(
                                    color: color,
                                    selected: !controller.tool.isEraser &&
                                        controller.color == color,
                                    onTap: () => controller.selectColor(color),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 8),
                    for (final width in DrawingWidth.values)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _WidthButton(
                          width: width,
                          selected: controller.width == width,
                          onTap: () => controller.selectWidth(width),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear the page?'),
          content: const Text('This rubs out everything you have drawn.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep drawing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear ?? false) controller.clear();
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final DrawingTool tool;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: tool.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 54,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.lavender : AppColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.violet : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tool.icon,
                size: 20,
                color: selected ? accent : AppColors.ink.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 2),
              // Keeps the label on one line whatever the platform text scale.
              Flexible(
                child: FittedBox(
                  child: Text(
                    tool.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                      color: selected
                          ? AppColors.violet
                          : AppColors.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.ink : Colors.white,
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: selected ? 0.45 : 0.2),
                blurRadius: selected ? 10 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidthButton extends StatelessWidget {
  const _WidthButton({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final DrawingWidth width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotSize = switch (width) {
      DrawingWidth.small => 7.0,
      DrawingWidth.medium => 12.0,
      DrawingWidth.large => 18.0,
    };

    return Semantics(
      button: true,
      selected: selected,
      label: width.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: selected ? AppColors.lavender : AppColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.violet : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.violet
                    : AppColors.ink.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      icon: Icon(icon),
    );
  }
}
