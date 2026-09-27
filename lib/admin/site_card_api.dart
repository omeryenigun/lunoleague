import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/admin/admin_directory.dart';

class SiteImage {
  const SiteImage({required this.id, required this.url, required this.sortOrder});

  final String id;
  final String url;
  final int sortOrder;

  factory SiteImage.fromJson(Map<String, dynamic> json) {
    return SiteImage(
      id: json['id'] as String,
      url: json['url'] as String,
      sortOrder: json['sortOrder'] as int,
    );
  }
}

class SiteCard {
  const SiteCard({
    required this.id,
    required this.name,
    required this.description,
    required this.nameEn,
    required this.descriptionEn,
    required this.playUrl,
    required this.iosUrl,
    required this.status,
    required this.sortOrder,
    required this.iconUrl,
    required this.images,
  });

  final String id;
  final String name;
  final String description;
  final String nameEn;
  final String descriptionEn;
  final String playUrl;
  final String iosUrl;
  final String status;
  final int sortOrder;
  final String? iconUrl;
  final List<SiteImage> images;

  bool get live => status == 'live';

  factory SiteCard.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    return SiteCard(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      nameEn: json['nameEn'] as String? ?? '',
      descriptionEn: json['descriptionEn'] as String? ?? '',
      playUrl: json['playUrl'] as String? ?? '',
      iosUrl: json['iosUrl'] as String? ?? '',
      status: json['status'] as String,
      sortOrder: json['sortOrder'] as int,
      iconUrl: json['iconUrl'] as String?,
      images: [
        if (images is List)
          for (final item in images)
            if (item is Map) SiteImage.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class SiteCardApi {
  SiteCardApi(String baseUrl, this.token)
      : _root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  final String _root;
  final String token;

  Map<String, String> get _headers => {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $token',
      };

  Future<List<SiteCard>> list() async {
    final response = await http.get(Uri.parse('$_root/v1/admin/site-cards'), headers: _headers);
    return _cards(response);
  }

  Future<List<SiteCard>> save(
    SiteCard card, {
    required String name,
    required String description,
    required String nameEn,
    required String descriptionEn,
    required String playUrl,
    required String iosUrl,
    required String status,
    required int sortOrder,
    List<String>? imageOrder,
  }) async {
    final response = await http.put(
      Uri.parse('$_root/v1/admin/site-cards/${card.id}'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'description': description,
        'nameEn': nameEn,
        'descriptionEn': descriptionEn,
        'playUrl': playUrl,
        'iosUrl': iosUrl,
        'status': status,
        'sortOrder': sortOrder,
        'imageOrder': ?imageOrder,
      }),
    );
    return _cards(response);
  }

  Future<List<SiteCard>> upload(SiteCard card, List<int> bytes, String type, {required bool icon}) async {
    final path = icon ? 'icon' : 'images';
    final response = await http.post(
      Uri.parse('$_root/v1/admin/site-cards/${card.id}/$path'),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': type,
      },
      body: bytes,
    );
    return _cards(response);
  }

  Future<List<SiteCard>> removeImage(SiteCard card, String mediaId) async {
    final response = await http.delete(
      Uri.parse('$_root/v1/admin/site-cards/${card.id}/images/$mediaId'),
      headers: _headers,
    );
    return _cards(response);
  }

  List<SiteCard> _cards(http.Response response) {
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final map = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};
    if (response.statusCode >= 400) {
      throw AdminAuthException(map['error'] as String? ?? 'Kart kaydı başarısız.');
    }
    final cards = map['cards'];
    if (cards is! List) return const [];
    return [
      for (final item in cards)
        if (item is Map) SiteCard.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}
