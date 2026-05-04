class MetadataTagMapper {
  List<String> tagsForField(String fieldKey) {
    final normalized = _normalize(fieldKey);

    final mapped = _map[normalized];
    if (mapped != null) {
      return mapped;
    }

    if (fieldKey.contains('.')) {
      return [fieldKey.replaceFirst('.', ':').replaceAll(' ', '')];
    }

    return [fieldKey.replaceAll(' ', '')];
  }

  bool isListTag(String tag) {
    final normalized = tag.toLowerCase();
    return normalized.contains('keywords') || normalized.contains('subject');
  }

  String _normalize(String key) => key.replaceAll(' ', '').toLowerCase();

  static final Map<String, List<String>> _map = {
    'xmp.copyright': ['XMP-dc:Rights', 'IPTC:CopyrightNotice'],
    'xmp.creator': ['XMP-dc:Creator', 'EXIF:Artist', 'IPTC:By-line'],
    'xmp.author': ['XMP-dc:Creator', 'EXIF:Artist', 'IPTC:By-line'],
    'xmp.keywords': ['XMP-dc:Subject', 'IPTC:Keywords'],
    'xmp.description': ['XMP-dc:Description', 'EXIF:ImageDescription', 'IPTC:Caption-Abstract'],
    'xmp.title': ['XMP-dc:Title', 'IPTC:ObjectName'],
    'xmp.headline': ['XMP-photoshop:Headline', 'IPTC:Headline'],
    'xmp.creatorcontactinfo': ['XMP-iptcCore:CreatorWorkEmail'],

    'exif.datetimeoriginal': ['EXIF:DateTimeOriginal'],
    'exif.iso': ['EXIF:ISO'],
    'exif.fnumber': ['EXIF:FNumber'],
    'exif.focallength': ['EXIF:FocalLength'],
    'exif.make': ['EXIF:Make'],
    'exif.model': ['EXIF:Model'],
    'exif.lensmodel': ['EXIF:LensModel'],
    'exif.exposuretime': ['EXIF:ExposureTime'],
    'exif.flash': ['EXIF:Flash'],
    'exif.whitebalance': ['EXIF:WhiteBalance'],

    'iptc.keywords': ['IPTC:Keywords', 'XMP-dc:Subject'],
    'iptc.caption': ['IPTC:Caption-Abstract', 'XMP-dc:Description'],
    'iptc.copyrightnotice': ['IPTC:CopyrightNotice', 'XMP-dc:Rights'],
    'iptc.creator': ['IPTC:By-line', 'XMP-dc:Creator', 'EXIF:Artist'],
    'iptc.creatorjobtitle': ['IPTC:By-lineTitle', 'XMP-photoshop:AuthorsPosition'],
    'iptc.headline': ['IPTC:Headline', 'XMP-photoshop:Headline'],
  };
}
