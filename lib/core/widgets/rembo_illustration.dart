import 'package:flutter/material.dart';

/// The 3D illustrations of the mockups.
enum RemboArt {
  receipt('receipt_hero'),
  key('art_access_key'),
  envelope('art_envelope_lock'),
  folder('art_receipt_folder'),
  approved('art_receipt_approved'),
  camera('art_receipt_camera'),
  download('art_receipt_download'),
  search('art_receipt_search'),
  team('art_receipt_team'),
  warning('art_receipt_warning');

  const RemboArt(this.file);
  final String file;
  String get asset => 'assets/images/$file.webp';
}

/// Decoration only: keep it to one per screen.
class RemboIllustration extends StatelessWidget {
  const RemboIllustration({
    super.key,
    this.height = 160,
    this.art = RemboArt.receipt,
  });
  final double height;
  final RemboArt art;

  @override
  Widget build(BuildContext context) => Image.asset(
    art.asset,
    height: height,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
