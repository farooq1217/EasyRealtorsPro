import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E242C) : const Color(0xFFE6E8ED);
    final highlight = isDark ? const Color(0xFF2B3440) : const Color(0xFFF4F5F7);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class ShimmerListPlaceholder extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const ShimmerListPlaceholder({
    super.key,
    this.itemCount = 8,
    this.itemHeight = 72,
    this.padding = const EdgeInsets.all(12),
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerBox(width: 44, height: 44, borderRadius: BorderRadius.all(Radius.circular(12))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(height: 14),
                      SizedBox(height: 10),
                      ShimmerBox(height: 12, width: 180),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const ShimmerBox(height: 10, width: 260),
          ],
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemCount: itemCount,
    );
  }
}

class ShimmerPageLoading extends StatelessWidget {
  final int itemCount;

  const ShimmerPageLoading({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    return ShimmerListPlaceholder(itemCount: itemCount);
  }
}

/// Shimmer widget that waits for Firestore data to be verified before hiding
/// This ensures data is fully ready before displaying
class FirestoreShimmerWrapper extends StatefulWidget {
  final Widget child;
  final Future<bool> Function()? dataReadyCheck;
  final Stream<bool>? dataReadyStream;
  final Widget shimmerWidget;
  final Duration maxWaitTime;

  const FirestoreShimmerWrapper({
    super.key,
    required this.child,
    this.dataReadyCheck,
    this.dataReadyStream,
    Widget? shimmerWidget,
    this.maxWaitTime = const Duration(seconds: 10),
  }) : shimmerWidget = shimmerWidget ?? const ShimmerPageLoading();

  @override
  State<FirestoreShimmerWrapper> createState() => _FirestoreShimmerWrapperState();
}

class _FirestoreShimmerWrapperState extends State<FirestoreShimmerWrapper> {
  bool _isDataReady = false;
  Timer? _maxWaitTimer;

  @override
  void initState() {
    super.initState();
    _checkDataReady();
    _startMaxWaitTimer();
  }

  void _startMaxWaitTimer() {
    _maxWaitTimer = Timer(widget.maxWaitTime, () {
      if (mounted && !_isDataReady) {
        setState(() {
          _isDataReady = true; // Show data even if not fully ready after max wait
        });
      }
    });
  }

  Future<void> _checkDataReady() async {
    if (widget.dataReadyCheck != null) {
      final ready = await widget.dataReadyCheck!();
      if (mounted) {
        setState(() {
          _isDataReady = ready;
        });
      }
    }
  }

  @override
  void dispose() {
    _maxWaitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dataReadyStream != null) {
      return StreamBuilder<bool>(
        stream: widget.dataReadyStream,
        initialData: false,
        builder: (context, snapshot) {
          final isReady = snapshot.data ?? false;
          if (isReady && _isDataReady) {
            _maxWaitTimer?.cancel();
            return widget.child;
          }
          return widget.shimmerWidget;
        },
      );
    }

    if (_isDataReady) {
      return widget.child;
    }

    return widget.shimmerWidget;
  }
}

/// Helper to check if Firestore collection has been synced
Future<bool> checkFirestoreCollectionReady(String collection, {int minDocs = 0}) async {
  if (Firebase.apps.isEmpty) return true; // If Firestore not available, consider ready
  
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .limit(1)
        .get();
    
    // If we can query Firestore successfully, it's ready
    return true;
  } catch (e) {
    return false;
  }
}
