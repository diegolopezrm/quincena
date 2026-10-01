import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A shop or a place to eat near where a payment happened.
@immutable
class NearbyPlace {
  const NearbyPlace({
    required this.name,
    required this.metres,
    this.category,
    this.kind,
  });

  final String name;

  /// How far it was from the phone.
  final double metres;

  /// The Quincena category its kind of place suggests, or null.
  final String? category;

  /// What OpenStreetMap calls it: `supermarket`, `restaurant`, `fuel`.
  final String? kind;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'metres': metres.round(),
    if (category != null) 'category': category,
    if (kind != null) 'kind': kind,
  };

  static NearbyPlace fromJson(Map<String, Object?> json) => NearbyPlace(
    name: json['name']! as String,
    metres: (json['metres'] as num?)?.toDouble() ?? 0,
    category: json['category'] as String?,
    kind: json['kind'] as String?,
  );
}

/// Looks up the places around a point in OpenStreetMap's data, through
/// Photon, a free geocoder that needs no key and answers browsers too.
///
/// Only the coordinates leave the device, and only when the person turned
/// the location on; nothing about the payment goes with them.
class PlaceFinder {
  PlaceFinder({
    http.Client? client,
    this.radius = 80,
    this.timeout = const Duration(seconds: 8),
    Uri? endpoint,
  }) : _client = client ?? http.Client(),
       _endpoint = endpoint ?? Uri.parse('https://photon.komoot.io/reverse');

  final http.Client _client;
  final Uri _endpoint;

  /// How far around the point to look, in metres. A card terminal is inside
  /// the shop; the phone's location is off by a few tens of metres.
  final int radius;
  final Duration timeout;

  final Map<String, List<NearbyPlace>> _cache = <String, List<NearbyPlace>>{};

  /// Named shops, places to eat and the like within [radius] of the point,
  /// nearest first. Empty when there are none or the lookup fails.
  Future<List<NearbyPlace>> near(double latitude, double longitude) async {
    // Within about ten metres it is the same answer.
    final String key =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    final List<NearbyPlace>? cached = _cache[key];
    if (cached != null) return cached;
    final Uri uri = _endpoint.replace(
      queryParameters: <String, Object>{
        'lat': '$latitude',
        'lon': '$longitude',
        'radius': (radius / 1000).toStringAsFixed(3),
        'limit': '15',
        'osm_tag': <String>['shop', 'amenity', 'leisure'],
      },
    );
    try {
      final http.Response response = await _client
          .get(uri, headers: _headers)
          .timeout(timeout);
      if (response.statusCode != 200) return const <NearbyPlace>[];
      final Map<String, Object?> body =
          jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true))
              as Map<String, Object?>;
      final List<NearbyPlace> places = <NearbyPlace>[
        for (final Object? f
            in body['features'] as List<Object?>? ?? const <Object?>[])
          if (_place(f, latitude, longitude) case final NearbyPlace p) p,
      ]..sort((NearbyPlace a, NearbyPlace b) => a.metres.compareTo(b.metres));
      _cache[key] = places;
      return places;
    } on Object {
      return const <NearbyPlace>[];
    }
  }

  /// Browsers set their own; elsewhere the service asks apps to say who they
  /// are.
  static const Map<String, String> _headers = kIsWeb
      ? <String, String>{}
      : <String, String>{
          'User-Agent':
              'Quincena/1.0 (+https://github.com/diegolopezrm/quincena)',
        };

  NearbyPlace? _place(Object? feature, double lat, double lng) {
    if (feature is! Map) return null;
    final Map<String, Object?> props =
        (feature['properties'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final String? name = props['name'] as String?;
    if (name == null || name.trim().isEmpty) return null;
    final List<Object?> at =
        ((feature['geometry'] as Map?)?['coordinates'] as List<Object?>?) ??
        const <Object?>[];
    if (at.length < 2 || at[0] is! num || at[1] is! num) return null;
    final String key = '${props['osm_key']}';
    final String value = '${props['osm_value']}';
    return NearbyPlace(
      name: name.trim(),
      metres: metresBetween(
        lat,
        lng,
        (at[1]! as num).toDouble(),
        (at[0]! as num).toDouble(),
      ),
      category: categoryForPlace(
        shop: key == 'shop' ? value : null,
        amenity: key == 'amenity' ? value : null,
        leisure: key == 'leisure' ? value : null,
      ),
      kind: value,
    );
  }

  void close() => _client.close();
}

const Map<String, String> _amenities = <String, String>{
  'restaurant': 'restaurants',
  'fast_food': 'restaurants',
  'cafe': 'restaurants',
  'ice_cream': 'restaurants',
  'food_court': 'restaurants',
  'bar': 'leisure',
  'pub': 'leisure',
  'nightclub': 'leisure',
  'cinema': 'leisure',
  'theatre': 'leisure',
  'fuel': 'transport',
  'parking': 'transport',
  'charging_station': 'transport',
  'pharmacy': 'health',
  'hospital': 'health',
  'clinic': 'health',
  'doctors': 'health',
  'dentist': 'health',
  'marketplace': 'groceries',
};

const Map<String, String> _shops = <String, String>{
  'supermarket': 'groceries',
  'convenience': 'groceries',
  'grocery': 'groceries',
  'greengrocer': 'groceries',
  'butcher': 'groceries',
  'bakery': 'groceries',
  'deli': 'groceries',
  'frozen_food': 'groceries',
  'beverages': 'groceries',
  'chemist': 'health',
  'medical_supply': 'health',
  'optician': 'health',
  'car': 'transport',
  'car_repair': 'transport',
  'car_parts': 'transport',
  'bicycle': 'transport',
  'tyres': 'transport',
};

/// The Quincena category for a kind of place in OpenStreetMap's terms.
/// Any other shop is shopping.
String? categoryForPlace({String? shop, String? amenity, String? leisure}) {
  final String? byAmenity = amenity == null ? null : _amenities[amenity];
  if (byAmenity != null) return byAmenity;
  if (leisure == 'fitness_centre' || leisure == 'sports_centre') {
    return 'health';
  }
  if (shop != null) return _shops[shop] ?? 'shopping';
  return null;
}

/// Metres between two points on the Earth.
double metresBetween(double lat1, double lng1, double lat2, double lng2) {
  const double r = 6371000;
  double rad(double d) => d * math.pi / 180;
  final double dLat = rad(lat2 - lat1);
  final double dLng = rad(lng2 - lng1);
  final double a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}
