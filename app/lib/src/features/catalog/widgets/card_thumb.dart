import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../config.dart';

/// Thumbnail for a variant, loaded through the server image proxy and cached.
class CardThumb extends StatelessWidget {
  const CardThumb({super.key, required this.thumbPath, this.fit = BoxFit.cover});

  final String thumbPath; // server-relative, e.g. /img/variants/OP01-016/thumb
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CachedNetworkImage(
      imageUrl: AppConfig.imageUrl(thumbPath),
      fit: fit,
      placeholder: (context, _) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, _, _) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.broken_image_outlined, color: scheme.outline),
      ),
    );
  }
}
