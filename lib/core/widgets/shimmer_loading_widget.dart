import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE5E7EB),
        highlightColor: const Color(0xFFF3F4F6),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}

/// Suitable & Modern Shimmer Skeleton for Rahbar Dashboard
class RahbarDashboardShimmerWidget extends StatelessWidget {
  const RahbarDashboardShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile card shimmer
          const ShimmerSkeleton(
            width: double.infinity,
            height: 72,
            borderRadius: 18,
          ),
          const SizedBox(height: 14),

          // Date bar shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerSkeleton(width: 160, height: 22, borderRadius: 8),
              ShimmerSkeleton(width: 110, height: 28, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 14),

          // KPI Grid shimmer (2x2)
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              ShimmerSkeleton(
                width: double.infinity,
                height: 90,
                borderRadius: 18,
              ),
              ShimmerSkeleton(
                width: double.infinity,
                height: 90,
                borderRadius: 18,
              ),
              ShimmerSkeleton(
                width: double.infinity,
                height: 90,
                borderRadius: 18,
              ),
              ShimmerSkeleton(
                width: double.infinity,
                height: 90,
                borderRadius: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Arizalar banner shimmer
          const ShimmerSkeleton(
            width: double.infinity,
            height: 80,
            borderRadius: 16,
          ),
          const SizedBox(height: 20),

          // Department list shimmer
          const ShimmerSkeleton(width: 180, height: 20, borderRadius: 8),
          const SizedBox(height: 12),
          const ShimmerSkeleton(
            width: double.infinity,
            height: 64,
            borderRadius: 16,
          ),
          const SizedBox(height: 10),
          const ShimmerSkeleton(
            width: double.infinity,
            height: 64,
            borderRadius: 16,
          ),
          const SizedBox(height: 10),
          const ShimmerSkeleton(
            width: double.infinity,
            height: 64,
            borderRadius: 16,
          ),
        ],
      ),
    );
  }
}

/// Suitable & Modern Shimmer Skeleton for Staff Home Page
class HomeShimmerWidget extends StatelessWidget {
  const HomeShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting card shimmer
          const ShimmerSkeleton(
            width: double.infinity,
            height: 90,
            borderRadius: 16,
          ),
          const SizedBox(height: 20),

          // Main card shimmer
          const ShimmerSkeleton(
            width: double.infinity,
            height: 190,
            borderRadius: 20,
          ),
          const SizedBox(height: 24),

          // Action button shimmer
          const ShimmerSkeleton(
            width: double.infinity,
            height: 60,
            borderRadius: 16,
          ),
          const SizedBox(height: 24),

          // Timeline shimmer header
          const ShimmerSkeleton(width: 180, height: 20, borderRadius: 8),
          const SizedBox(height: 12),

          // Timeline cards shimmer
          const ShimmerSkeleton(
            width: double.infinity,
            height: 80,
            borderRadius: 16,
          ),
          const SizedBox(height: 10),
          const ShimmerSkeleton(
            width: double.infinity,
            height: 80,
            borderRadius: 16,
          ),
        ],
      ),
    );
  }
}
