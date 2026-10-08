class PassportPreset {
  final String id;
  final String country;
  final double widthMm;
  final double heightMm;
  final String label;
  final String backgroundReq;
  final String flagEmoji;

  const PassportPreset({
    required this.id,
    required this.country,
    required this.widthMm,
    required this.heightMm,
    required this.label,
    required this.backgroundReq,
    this.flagEmoji = '',
  });

  double get aspectRatio => widthMm / heightMm;
  bool get isCustom => id.startsWith('custom');

  static PassportPreset createCustom({
    required double width,
    required double height,
    required String unit,
  }) {
    final widthMm = unit == 'cm' ? width * 10.0 : width;
    final heightMm = unit == 'cm' ? height * 10.0 : height;
    final cmW = (widthMm / 10.0).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    final cmH = (heightMm / 10.0).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    final mmW = widthMm.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    final mmH = heightMm.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

    return PassportPreset(
      id: 'custom_${widthMm}_$heightMm',
      country: 'Custom Size',
      widthMm: widthMm,
      heightMm: heightMm,
      label: 'Custom ($mmW x $mmH mm / $cmW x $cmH cm)',
      backgroundReq: 'Custom dimensions photo',
      flagEmoji: '',
    );
  }

  static const List<PassportPreset> presets = [
    PassportPreset(
      id: 'in_passport',
      country: 'India',
      widthMm: 35.0,
      heightMm: 45.0,
      label: 'India (3.5 x 4.5 cm)',
      backgroundReq: 'White or light off-white',
      flagEmoji: '',
    ),
    PassportPreset(
      id: 'in_pan',
      country: 'India (PAN Card)',
      widthMm: 25.0,
      heightMm: 35.0,
      label: 'India PAN Card (2.5 x 3.5 cm)',
      backgroundReq: 'White background',
      flagEmoji: '',
    ),
    PassportPreset(
      id: 'stamp_size',
      country: 'Stamp Size',
      widthMm: 20.0,
      heightMm: 25.0,
      label: 'Stamp Size (2.0 x 2.5 cm)',
      backgroundReq: 'White or light background',
      flagEmoji: '',
    ),
    PassportPreset(
      id: 'us_passport',
      country: 'United States',
      widthMm: 50.8,
      heightMm: 50.8,
      label: 'United States (2 x 2 in)',
      backgroundReq: 'Plain white or off-white',
      flagEmoji: '',
    ),
    PassportPreset(
      id: 'uk_passport',
      country: 'United Kingdom',
      widthMm: 35.0,
      heightMm: 45.0,
      label: 'United Kingdom (35 x 45 mm)',
      backgroundReq: 'Light grey or plain cream',
      flagEmoji: '',
    ),
    PassportPreset(
      id: 'schengen',
      country: 'Schengen / Europe',
      widthMm: 35.0,
      heightMm: 45.0,
      label: 'Schengen / EU (35 x 45 mm)',
      backgroundReq: 'Light grey or light blue',
      flagEmoji: '',
    ),
    PassportPreset(
      id: 'ca_passport',
      country: 'Canada',
      widthMm: 50.0,
      heightMm: 70.0,
      label: 'Canada (50 x 70 mm)',
      backgroundReq: 'Plain white or light-coloured',
      flagEmoji: '',
    ),
    PassportPreset(
      id: 'au_passport',
      country: 'Australia',
      widthMm: 35.0,
      heightMm: 45.0,
      label: 'Australia (35 x 45 mm)',
      backgroundReq: 'Plain white or light grey',
      flagEmoji: '',
    ),
    PassportPreset(
      id: 'ae_passport',
      country: 'UAE / GCC',
      widthMm: 40.0,
      heightMm: 60.0,
      label: 'UAE / Gulf (40 x 60 mm)',
      backgroundReq: 'Plain white',
      flagEmoji: '',
    ),
    PassportPreset(
      id: 'cn_passport',
      country: 'China',
      widthMm: 33.0,
      heightMm: 48.0,
      label: 'China (33 x 48 mm)',
      backgroundReq: 'White or light blue',
      flagEmoji: '',
    ),
  ];
}
