import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../model/home/banner_model.dart' as banner_model;
import '../../services/home/banner_api_service.dart';

class BannerCarousel extends StatefulWidget {
  final Function(banner_model.Banner, int mediaIndex)? onBannerTap;
  final double aspectRatio;
  final String? folderName;
  final Duration autoPlayDuration;
  final Duration transitionDuration;
  final Curve transitionCurve;

  const BannerCarousel({
    Key? key,
    this.onBannerTap,
    this.aspectRatio = 1.8 / 1,
    this.folderName,
    this.autoPlayDuration = const Duration(seconds: 4),
    this.transitionDuration = const Duration(milliseconds: 400),
    this.transitionCurve = Curves.easeInOut,
  }) : super(key: key);

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> with AutomaticKeepAliveClientMixin {
  List<banner_model.Banner> banners = [];
  bool isLoading = true;
  int currentPage = 0;
  Timer? autoPlayTimer;
  final PageController _pageController = PageController(viewportFraction: 0.95);

  final Map<int, List<String>> _bannerImagesCache = {};
  final Map<int, int> _currentMediaIndexMap = {};
  final Map<int, PageController> _mediaPageControllers = {};
  final Map<int, Timer?> _mediaAutoPlayTimers = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    try {
      setState(() => isLoading = true);

      final fetchedBanners = await BannerApiService.getBanners(
        folderName: widget.folderName,
      );

      if (mounted) {
        final validBanners = fetchedBanners.where((banner) {
          final allImages = _getAllBannerImages(banner);
          return allImages.isNotEmpty;
        }).toList();

        debugPrint(
          ' BannerCarousel: Loaded ${validBanners.length} valid banners for folder: ${widget.folderName}',
        );

        setState(() {
          banners = validBanners;
          isLoading = false;

          for (int i = 0; i < validBanners.length; i++) {
            final images = _getAllBannerImages(validBanners[i]);
            _bannerImagesCache[i] = images;
            _currentMediaIndexMap[i] = 0;

            debugPrint('Banner $i has ${images.length} unique images');

            if (images.length > 1) {
              _mediaPageControllers[i] = PageController();
            }
          }
        });

        if (banners.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _startAutoPlay();
              if (_bannerImagesCache[0] != null && _bannerImagesCache[0]!.length > 1) {
                _startMediaAutoPlay(0);
              }
            }
          });

          _precacheAllImages();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading banners: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _precacheAllImages() async {
    for (var images in _bannerImagesCache.values) {
      for (var imageUrl in images) {
        try {
          await precacheImage(
            CachedNetworkImageProvider(imageUrl),
            context,
          );
        } catch (e) {
          debugPrint('Error precaching image: $imageUrl - $e');
        }
      }
    }
  }

  // ✅ FIXED: Remove duplicates using Set and preserve order
  List<String> _getAllBannerImages(banner_model.Banner banner) {
    final Set<String> uniqueImages = {}; // Use Set to prevent duplicates
    final List<String> orderedImages = [];

    // Add imageUrls first
    if (banner.imageUrls.isNotEmpty) {
      for (var url in banner.imageUrls) {
        if (url.isNotEmpty && !uniqueImages.contains(url)) {
          uniqueImages.add(url);
          orderedImages.add(url);
        }
      }
    }

    // Add media URLs only if not already added
    if (banner.media != null && banner.media!.isNotEmpty) {
      for (final mediaItem in banner.media!) {
        final fullUrl = mediaItem.getFullUrl();
        if (fullUrl.isNotEmpty && !uniqueImages.contains(fullUrl)) {
          uniqueImages.add(fullUrl);
          orderedImages.add(fullUrl);
        }
      }
    }

    debugPrint('🖼️ Banner has ${orderedImages.length} unique images (filtered from ${banner.imageUrls.length} imageUrls + ${banner.media?.length ?? 0} media)');

    return orderedImages;
  }

  void _startAutoPlay() {
    autoPlayTimer?.cancel();

    if (banners.length <= 1) {
      debugPrint('Only ${banners.length} banner(s), skipping auto-play');
      return;
    }

    debugPrint('▶️ Starting main banner auto-play');

    autoPlayTimer = Timer.periodic(widget.autoPlayDuration, (timer) {
      if (!mounted || !_pageController.hasClients) {
        timer.cancel();
        return;
      }

      final nextPage = (currentPage + 1) % banners.length;

      _pageController.animateToPage(
        nextPage,
        duration: widget.transitionDuration,
        curve: widget.transitionCurve,
      );
    });
  }

  void _startMediaAutoPlay(int bannerIndex) {
    _stopMediaAutoPlay(bannerIndex);

    final images = _bannerImagesCache[bannerIndex];
    if (images == null || images.length <= 1) return;

    debugPrint('▶️ Starting media auto-play for banner $bannerIndex (${images.length} images)');

    _mediaAutoPlayTimers[bannerIndex] = Timer.periodic(
      const Duration(seconds: 3),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final controller = _mediaPageControllers[bannerIndex];
        if (controller == null || !controller.hasClients) return;

        final currentIndex = _currentMediaIndexMap[bannerIndex] ?? 0;
        final nextIndex = (currentIndex + 1) % images.length;

        controller.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  void _stopMediaAutoPlay(int bannerIndex) {
    if (_mediaAutoPlayTimers[bannerIndex] != null) {
      _mediaAutoPlayTimers[bannerIndex]?.cancel();
      _mediaAutoPlayTimers[bannerIndex] = null;
    }
  }

  @override
  void dispose() {
    autoPlayTimer?.cancel();
    _pageController.dispose();

    for (var controller in _mediaPageControllers.values) {
      controller.dispose();
    }
    for (var timer in _mediaAutoPlayTimers.values) {
      timer?.cancel();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (isLoading) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.red),
          ),
        ),
      );
    }

    if (banners.isEmpty) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'No banners available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                if (currentPage != index && currentPage < banners.length) {
                  _stopMediaAutoPlay(currentPage);
                }

                currentPage = index;

                final images = _bannerImagesCache[index];
                if (images != null && images.length > 1) {
                  _startMediaAutoPlay(index);
                }
              });
            },
            itemCount: banners.length,
            itemBuilder: (context, bannerIndex) {
              final banner = banners[bannerIndex];
              final allImages = _bannerImagesCache[bannerIndex] ?? [];

              if (allImages.isEmpty) {
                return const SizedBox.shrink();
              }

              if (allImages.length > 1) {
                return _buildMultiImageBanner(banner, bannerIndex, allImages);
              } else {
                return _buildSingleImageBanner(banner, 0, allImages.first);
              }
            },
          ),
        ),

        if (banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                banners.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentPage == index
                        ? Colors.red
                        : Colors.grey[400],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleImageBanner(
      banner_model.Banner banner,
      int mediaIndex,
      String imageUrl,
      ) {
    return GestureDetector(
      onTap: () {
        widget.onBannerTap?.call(banner, mediaIndex);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheKey: imageUrl,
            maxHeightDiskCache: 1000,
            maxWidthDiskCache: 1000,
            memCacheHeight: 1000,
            memCacheWidth: 1000,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            ),
            errorWidget: (context, url, error) {
              return Container(
                color: Colors.grey[200],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image not available',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMultiImageBanner(
      banner_model.Banner banner,
      int bannerIndex,
      List<String> images,
      ) {
    final controller = _mediaPageControllers[bannerIndex];
    final currentMediaIndex = _currentMediaIndexMap[bannerIndex] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: images.length,
              onPageChanged: (mediaIndex) {
                setState(() {
                  _currentMediaIndexMap[bannerIndex] = mediaIndex;
                });
              },
              itemBuilder: (context, mediaIndex) {
                return GestureDetector(
                  onTap: () {
                    widget.onBannerTap?.call(banner, mediaIndex);
                  },
                  child: CachedNetworkImage(
                    imageUrl: images[mediaIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    cacheKey: images[mediaIndex],
                    maxHeightDiskCache: 1000,
                    maxWidthDiskCache: 1000,
                    memCacheHeight: 1000,
                    memCacheWidth: 1000,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            if (images.length > 1)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${currentMediaIndex + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}