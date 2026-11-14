import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Barre de défilement rapide (Fast Scrollbar) à droite avec poignée glissable
/// et bulle d'aperçu flottante (lettre A-Z ou position), compatible NestedScrollView.
class SonoritizFastScrollbar extends StatefulWidget {
  final Widget child;
  final int itemCount;
  final String Function(int index)? labelBuilder;
  final double topMargin;
  final double bottomMargin;

  const SonoritizFastScrollbar({
    Key? key,
    required this.child,
    required this.itemCount,
    this.labelBuilder,
    this.topMargin = 12.0,
    this.bottomMargin = 110.0,
  }) : super(key: key);

  @override
  State<SonoritizFastScrollbar> createState() => _SonoritizFastScrollbarState();
}

class _SonoritizFastScrollbarState extends State<SonoritizFastScrollbar> {
  static const double _thumbHeight = 46.0;

  ScrollPosition? _scrollPosition;
  double _scrollFraction = 0.0;
  bool _canScroll = false;
  bool _isScrolling = false;
  bool _isDragging = false;
  String? _lastBubbleLabel;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMetricsFromTree());
  }

  @override
  void didUpdateWidget(covariant SonoritizFastScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncMetricsFromTree());
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  ScrollPosition? _findDescendantVerticalScrollPosition() {
    ScrollPosition? found;
    void visitor(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        final dir = scrollable.axisDirection;
        if (dir == AxisDirection.down || dir == AxisDirection.up) {
          found = scrollable.position;
          return;
        }
      }
      element.visitChildren(visitor);
    }

    if (mounted) {
      context.visitChildElements(visitor);
    }
    return found;
  }

  void _syncMetricsFromTree() {
    if (!mounted) return;
    final pos = _findDescendantVerticalScrollPosition();
    if (pos != null && pos.hasPixels && pos.hasContentDimensions) {
      _scrollPosition = pos;
      final extent = pos.maxScrollExtent - pos.minScrollExtent;
      final scrollable = extent > 60.0 && widget.itemCount >= 5;
      final frac = extent > 0
          ? ((pos.pixels - pos.minScrollExtent) / extent).clamp(0.0, 1.0)
          : 0.0;
      if (scrollable != _canScroll || (frac - _scrollFraction).abs() > 0.002) {
        setState(() {
          _canScroll = scrollable;
          _scrollFraction = frac;
        });
      }
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
      return false;
    }

    if (notification.context != null) {
      final scrollable = Scrollable.maybeOf(notification.context!);
      if (scrollable != null) {
        _scrollPosition = scrollable.position;
      }
    }

    final minExt = notification.metrics.minScrollExtent;
    final maxExt = notification.metrics.maxScrollExtent;
    final total = maxExt - minExt;
    final scrollable = total > 60.0 && widget.itemCount >= 5;
    final frac = total > 0
        ? ((notification.metrics.pixels - minExt) / total).clamp(0.0, 1.0)
        : 0.0;

    if (!_isDragging) {
      _fadeTimer?.cancel();
      if (scrollable) {
        _fadeTimer = Timer(const Duration(milliseconds: 1600), () {
          if (mounted && !_isDragging) {
            setState(() => _isScrolling = false);
          }
        });
      }
    }

    if (mounted &&
        (scrollable != _canScroll ||
            !_isScrolling ||
            (frac - _scrollFraction).abs() > 0.002)) {
      setState(() {
        _canScroll = scrollable;
        if (scrollable) _isScrolling = true;
        if (!_isDragging) {
          _scrollFraction = frac;
        }
      });
    }
    return false;
  }

  void _jumpToLocalOffset(double localDy, double trackHeight) {
    final pos = _scrollPosition ?? _findDescendantVerticalScrollPosition();
    if (pos == null || !pos.hasPixels || !pos.hasContentDimensions) return;
    _scrollPosition = pos;

    final usableHeight = (trackHeight - _thumbHeight).clamp(1.0, double.infinity);
    final fraction = ((localDy - _thumbHeight / 2) / usableHeight).clamp(0.0, 1.0);
    final totalExtent = pos.maxScrollExtent - pos.minScrollExtent;
    if (totalExtent <= 0) return;

    final targetPixels = pos.minScrollExtent + fraction * totalExtent;
    pos.jumpTo(targetPixels.clamp(pos.minScrollExtent, pos.maxScrollExtent));

    final String? nextLabel = _computeCurrentLabel(fraction);
    if (nextLabel != null && nextLabel != _lastBubbleLabel) {
      _lastBubbleLabel = nextLabel;
      HapticFeedback.selectionClick();
    }

    setState(() {
      _scrollFraction = fraction;
    });
  }

  String? _computeCurrentLabel(double fraction) {
    if (widget.itemCount <= 0) return null;
    final idx = (fraction * (widget.itemCount - 1))
        .round()
        .clamp(0, widget.itemCount - 1);
    if (widget.labelBuilder != null) {
      final built = widget.labelBuilder!(idx).trim();
      if (built.isNotEmpty) return built;
    }
    return '#${idx + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final showScrollbar = _canScroll && widget.itemCount >= 5;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Stack(
        children: [
          widget.child,
          if (showScrollbar)
            Positioned(
              top: widget.topMargin,
              bottom: widget.bottomMargin,
              right: 0,
              width: 96,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trackHeight = constraints.maxHeight;
                  if (trackHeight <= _thumbHeight + 16) {
                    return const SizedBox.shrink();
                  }
                  final usable = trackHeight - _thumbHeight;
                  final thumbTop = (_scrollFraction * usable).clamp(0.0, usable);
                  final activeLabel = _computeCurrentLabel(_scrollFraction);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Bulle d'aperçu pendant le glissement
                      if (_isDragging && activeLabel != null)
                        Positioned(
                          right: 26,
                          top: (thumbTop + (_thumbHeight / 2) - 22)
                              .clamp(0.0, trackHeight - 44),
                          child: IgnorePointer(
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.45),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                activeLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Zone tactile fine à droite (uniquement glissement vertical)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: 24,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onVerticalDragStart: (details) {
                            _fadeTimer?.cancel();
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isDragging = true;
                              _isScrolling = true;
                            });
                            _jumpToLocalOffset(
                              details.localPosition.dy,
                              trackHeight,
                            );
                          },
                          onVerticalDragUpdate: (details) {
                            _jumpToLocalOffset(
                              details.localPosition.dy,
                              trackHeight,
                            );
                          },
                          onVerticalDragEnd: (_) {
                            setState(() {
                              _isDragging = false;
                              _lastBubbleLabel = null;
                            });
                            _fadeTimer?.cancel();
                            _fadeTimer = Timer(const Duration(milliseconds: 1400), () {
                              if (mounted && !_isDragging) {
                                setState(() => _isScrolling = false);
                              }
                            });
                          },
                          onVerticalDragCancel: () {
                            setState(() {
                              _isDragging = false;
                              _lastBubbleLabel = null;
                            });
                          },
                          child: Stack(
                            children: [
                              // Rail discret
                              Positioned(
                                top: 4,
                                bottom: 4,
                                right: 5,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _isDragging
                                      ? 0.35
                                      : (_isScrolling ? 0.2 : 0.08),
                                  child: Container(
                                    width: 3,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),

                              // Poignée (thumb)
                              Positioned(
                                top: thumbTop,
                                right: _isDragging ? 2 : 3.5,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 220),
                                  opacity: (_isDragging || _isScrolling) ? 1.0 : 0.45,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    width: _isDragging ? 8 : 5,
                                    height: _thumbHeight,
                                    decoration: BoxDecoration(
                                      color: _isDragging
                                          ? AppColors.primary
                                          : (_isScrolling
                                              ? AppColors.primary.withValues(alpha: 0.92)
                                              : Colors.white.withValues(alpha: 0.55)),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: _isDragging
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
