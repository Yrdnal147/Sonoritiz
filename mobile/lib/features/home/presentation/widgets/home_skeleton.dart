import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_colors.dart';

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Premium AppBar Skeleton
          SliverAppBar(
            backgroundColor: AppColors.background,
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonBox(width: 60, height: 14),
                      const SizedBox(height: 4),
                      _buildSkeletonBox(width: 120, height: 22),
                    ],
                  ),
                  _buildSkeletonCircle(radius: 18),
                ],
              ),
            ),
          ),
          
          // Body Skeletons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionSkeleton(),
                  _buildSectionSkeleton(),
                  _buildFavoriteArtistsSkeleton(),
                  _buildSectionSkeleton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSkeletonBox(width: 150, height: 24),
                _buildSkeletonBox(width: 60, height: 14),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonBox(width: 160, height: 160, borderRadius: 12),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteArtistsSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSkeletonBox(width: 180, height: 24),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSkeletonCircle(radius: 60),
                      const SizedBox(height: 8),
                      _buildSkeletonBox(width: 80, height: 14),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({required double width, required double height, double borderRadius = 4}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: AppColors.primary.withOpacity(0.2),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _buildSkeletonCircle({required double radius}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: AppColors.primary.withOpacity(0.2),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF2A2A2A),
      ),
    );
  }
}
