import 'package:flutter/material.dart';

/// Simple vertical timeline indicator used for batch history and timeline tabs.
///
/// This avoids relying on external timeline packages that internally use
/// [LayoutBuilder] in unsupported ways (causing intrinsic dimension errors
/// inside slivers) while still giving us control over the connector line and
/// indicator appearance.
class VerticalTimelineIndicator extends StatelessWidget {
  const VerticalTimelineIndicator({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.indicator,
    this.indicatorSize = 32,
    this.lineWidth = 2,
    this.horizontalPadding = 12,
    this.lineColor,
    this.beforeLineColor,
    this.afterLineColor,
  });

  /// Whether this node is the first entry in the list.
  final bool isFirst;

  /// Whether this node is the last entry in the list.
  final bool isLast;

  /// Custom widget rendered as the indicator (typically a decorated circle).
  final Widget indicator;

  /// Size of the indicator widget (width = height).
  final double indicatorSize;

  /// Thickness of the connector line.
  final double lineWidth;

  /// Extra horizontal padding used to give the indicator breathing room.
  final double horizontalPadding;

  /// Default line color if [beforeLineColor] / [afterLineColor] are not set.
  final Color? lineColor;

  /// Color for the connector line segment above the indicator.
  final Color? beforeLineColor;

  /// Color for the connector line segment below the indicator.
  final Color? afterLineColor;

  @override
  Widget build(BuildContext context) {
    final defaultColor = lineColor ??
        Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6);
    final resolvedBefore = beforeLineColor ?? defaultColor;
    final resolvedAfter = afterLineColor ?? defaultColor;

    return SizedBox(
      width: indicatorSize + horizontalPadding * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: lineWidth,
                    color: isFirst ? Colors.transparent : resolvedBefore,
                  ),
                ),
                SizedBox(height: indicatorSize),
                Expanded(
                  child: Container(
                    width: lineWidth,
                    color: isLast ? Colors.transparent : resolvedAfter,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: Center(child: indicator),
          ),
        ],
      ),
    );
  }
}
