import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/core/source_registry.dart';
import 'package:zephyr/type/enum.dart';

class BikaAvatarImage extends StatefulWidget {
  const BikaAvatarImage({
    super.key,
    required this.image,
    required this.name,
    this.radius = 20,
  });

  final ImageDetail? image;
  final String name;
  final double radius;

  @override
  State<BikaAvatarImage> createState() => _BikaAvatarImageState();
}

class _BikaAvatarImageState extends State<BikaAvatarImage> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(BikaAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image?.cacheKey != widget.image?.cacheKey ||
        oldWidget.image?.directUrl != widget.image?.directUrl) {
      _future = _load();
    }
  }

  Future<String> _load() async {
    final image = widget.image;
    if (image == null) throw StateError('bika avatar missing');
    final url = image.url;
    final path = image.cacheKey;
    if (url.isEmpty || path.isEmpty) {
      throw StateError('bika avatar missing url/path');
    }
    return getCachePicture(
      from: bikaSourceId,
      url: url,
      path: path,
      pictureType: PictureType.user,
      applyRealSr: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.image == null) {
      return BikaAvatarFallback(name: widget.name, radius: widget.radius);
    }
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return CircleAvatar(
            radius: widget.radius,
            child: SizedBox(
              width: widget.radius,
              height: widget.radius,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          logger.w('bika avatar load failed', error: snapshot.error);
          return BikaAvatarFallback(name: widget.name, radius: widget.radius);
        }
        return CircleAvatar(
          radius: widget.radius,
          backgroundImage: FileImage(File(snapshot.data!)),
        );
      },
    );
  }
}

class BikaAvatarFallback extends StatelessWidget {
  const BikaAvatarFallback({super.key, required this.name, this.radius = 20});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      child: Text(initial, style: TextStyle(fontSize: radius * 0.8)),
    );
  }
}
