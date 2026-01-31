import 'package:flutter/material.dart';
import '../../app/theme.dart';

class ShimmerLoading extends StatefulWidget {
  final Widget Function(BuildContext context, Widget child) builder;
  final int itemCount;
  final Widget Function(BuildContext context, int index)? itemBuilder;
  final bool isList;

  const ShimmerLoading.list({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  }) : builder = _listBuilder, isList = true;

  const ShimmerLoading.custom({
    super.key,
    required this.builder,
  }) : isList = false, itemCount = 0, itemBuilder = null;

  static Widget _listBuilder(BuildContext context, Widget child) {
    return child;
  }

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (widget.isList) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
            itemCount: widget.itemCount,
            itemBuilder: (context, index) {
              return ShimmerItem(controller: _controller, child: widget.itemBuilder!(context, index));
            },
          );
        }
        return widget.builder(context, ShimmerItem(controller: _controller));
      },
    );
  }
}

class ShimmerItem extends StatelessWidget {
  final AnimationController controller;
  final Widget? child;

  const ShimmerItem({super.key, required this.controller, this.child});

  @override
  Widget build(BuildContext context) {
    if (child != null) {
      return ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppColors.shimmerBase(context),
              AppColors.shimmerHighlight(context),
              AppColors.shimmerBase(context),
            ],
            stops: const [0.25, 0.5, 0.75],
            transform: _SlidingGradientTransform(controller.value),
          ).createShader(bounds);
        },
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.shimmerBase(context),
            AppColors.shimmerHighlight(context),
            AppColors.shimmerBase(context),
          ],
          stops: const [0.25, 0.5, 0.75],
          transform: _SlidingGradientTransform(controller.value),
        ),
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}
