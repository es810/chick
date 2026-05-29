import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (_, __) => _shimmerTile(),
    );
  }
}

/// Use inside another scroll view (e.g. dashboard ListView) — avoids nested ListView crash/blank UI.
class LoadingShimmerColumn extends StatelessWidget {
  const LoadingShimmerColumn({super.key, this.itemCount = 3, this.itemHeight = 80});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (_) => _shimmerTile(height: itemHeight)),
    );
  }
}

Widget _shimmerTile({double height = 80}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
}

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
