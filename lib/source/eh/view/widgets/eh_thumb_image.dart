import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/source/core/source_registry.dart';
import 'package:zephyr/type/enum.dart';

class EhThumbImage extends StatefulWidget {
  const EhThumbImage({
    super.key,
    required this.url,
    required this.cacheKey,
    this.fit = BoxFit.cover,
  });

  final String url;
  final String cacheKey;
  final BoxFit fit;

  @override
  State<EhThumbImage> createState() => _EhThumbImageState();
}

class _EhThumbImageState extends State<EhThumbImage> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(EhThumbImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.cacheKey != widget.cacheKey) {
      _future = _load();
    }
  }

  Future<String> _load() async {
    if (widget.url.isEmpty || widget.cacheKey.isEmpty) {
      throw StateError('eh thumb missing url/path');
    }
    return getCachePicture(
      from: ehSourceId,
      url: widget.url,
      path: widget.cacheKey,
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
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          logger.w('eh thumb load failed', error: snapshot.error);
          return const ColoredBox(
            color: Color(0x11000000),
            child: Center(child: Icon(Icons.broken_image_outlined)),
          );
        }
        return Image.file(File(snapshot.data!), fit: widget.fit);
      },
    );
  }
}
