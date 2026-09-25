import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/source/core/source_registry.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';

class BikaCoverImage extends StatefulWidget {
  const BikaCoverImage({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final ImageDetail image;
  final BoxFit fit;
  final Alignment alignment;

  @override
  State<BikaCoverImage> createState() => _BikaCoverImageState();
}

class _BikaCoverImageState extends State<BikaCoverImage> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(BikaCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.cacheKey != widget.image.cacheKey ||
        oldWidget.image.directUrl != widget.image.directUrl) {
      _future = _load();
    }
  }

  Future<String> _load() async {
    final url = widget.image.url;
    final path = widget.image.cacheKey;
    if (url.isEmpty || path.isEmpty) {
      throw StateError('bika cover missing url/path');
    }
    return getCachePicture(
      from: bikaSourceId,
      url: url,
      path: path,
      pictureType: PictureType.cover,
      applyRealSr: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0x11000000),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
          logger.w('bika cover load failed', error: snapshot.error);
          return const ColoredBox(
            color: Color(0x11000000),
            child: Center(child: Icon(Icons.broken_image_outlined)),
          );
        }
        return Image.file(
          File(snapshot.data!),
          fit: widget.fit,
          alignment: widget.alignment,
        );
      },
    );
  }
}
