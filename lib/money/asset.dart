/// Whether an asset is a currency a central bank issues or a crypto asset.
enum AssetKind { fiat, crypto }

/// Something an account can hold: pesos, dollars, bitcoin.
///
/// [code] is what is stored and what the rate sources use: ISO 4217 for fiat,
/// the exchange ticker for crypto.
class Asset {
  const Asset._(
    this.code, {
    required this.kind,
    required this.decimals,
    required this.nameEs,
    required this.nameEn,
    this.localSymbol,
    this.symbol,
  });

  /// An asset the app has no entry for, such as a token someone holds on an
  /// exchange. It is treated as crypto with eight decimals.
  const Asset.unknown(this.code)
    : kind = AssetKind.crypto,
      decimals = 8,
      nameEs = code,
      nameEn = code,
      localSymbol = null,
      symbol = null;

  final String code;
  final AssetKind kind;

  /// How many decimals an amount shows. Pesos show none: no one in Colombia
  /// writes centavos. Crypto shows up to this many, without trailing zeros.
  final int decimals;
  final String nameEs;
  final String nameEn;

  /// The symbol used where this is the person's own currency: `$` for pesos
  /// in Colombia, `$` for dollars in the United States.
  final String? localSymbol;

  /// The symbol used next to other currencies, where a bare `$` would be
  /// ambiguous: `US$`, `COL$`, `€`.
  final String? symbol;

  bool get isCrypto => kind == AssetKind.crypto;

  String name(String languageCode) => languageCode == 'en' ? nameEn : nameEs;

  /// The name of an account that holds only this, as one an exchange keeps
  /// for it: the name with the ticker, «Cardano (ADA)», so a list of them
  /// reads alike; the ticker alone when it is the name, as «BNB».
  String accountName(String languageCode) {
    final String n = name(languageCode);
    return n == code || n.endsWith('($code)') ? n : '$n ($code)';
  }

  static const Asset cop = Asset._(
    'COP',
    kind: AssetKind.fiat,
    decimals: 0,
    nameEs: 'Peso colombiano',
    nameEn: 'Colombian peso',
    localSymbol: r'$',
    symbol: r'COL$',
  );
  static const Asset usd = Asset._(
    'USD',
    kind: AssetKind.fiat,
    decimals: 2,
    nameEs: 'Dólar estadounidense',
    nameEn: 'US dollar',
    localSymbol: r'$',
    symbol: r'US$',
  );
  static const Asset eur = Asset._(
    'EUR',
    kind: AssetKind.fiat,
    decimals: 2,
    nameEs: 'Euro',
    nameEn: 'Euro',
    localSymbol: '€',
    symbol: '€',
  );
  static const Asset mxn = Asset._(
    'MXN',
    kind: AssetKind.fiat,
    decimals: 2,
    nameEs: 'Peso mexicano',
    nameEn: 'Mexican peso',
    localSymbol: r'$',
    symbol: r'MX$',
  );
  static const Asset brl = Asset._(
    'BRL',
    kind: AssetKind.fiat,
    decimals: 2,
    nameEs: 'Real brasileño',
    nameEn: 'Brazilian real',
    localSymbol: r'R$',
    symbol: r'R$',
  );
  static const Asset gbp = Asset._(
    'GBP',
    kind: AssetKind.fiat,
    decimals: 2,
    nameEs: 'Libra esterlina',
    nameEn: 'British pound',
    localSymbol: '£',
    symbol: '£',
  );
  static const Asset cad = Asset._(
    'CAD',
    kind: AssetKind.fiat,
    decimals: 2,
    nameEs: 'Dólar canadiense',
    nameEn: 'Canadian dollar',
    localSymbol: r'$',
    symbol: r'CA$',
  );

  static const Asset btc = Asset._(
    'BTC',
    kind: AssetKind.crypto,
    decimals: 8,
    nameEs: 'Bitcoin',
    nameEn: 'Bitcoin',
  );
  static const Asset eth = Asset._(
    'ETH',
    kind: AssetKind.crypto,
    decimals: 6,
    nameEs: 'Ether',
    nameEn: 'Ether',
  );
  static const Asset usdt = Asset._(
    'USDT',
    kind: AssetKind.crypto,
    decimals: 2,
    nameEs: 'Tether (USDT)',
    nameEn: 'Tether (USDT)',
  );
  static const Asset usdc = Asset._(
    'USDC',
    kind: AssetKind.crypto,
    decimals: 2,
    nameEs: 'USD Coin',
    nameEn: 'USD Coin',
  );
  static const Asset bnb = Asset._(
    'BNB',
    kind: AssetKind.crypto,
    decimals: 4,
    nameEs: 'BNB',
    nameEn: 'BNB',
  );
  static const Asset sol = Asset._(
    'SOL',
    kind: AssetKind.crypto,
    decimals: 4,
    nameEs: 'Solana',
    nameEn: 'Solana',
  );

  static const Asset fdusd = Asset._(
    'FDUSD',
    kind: AssetKind.crypto,
    decimals: 2,
    nameEs: 'First Digital USD',
    nameEn: 'First Digital USD',
  );
  static const Asset dai = Asset._(
    'DAI',
    kind: AssetKind.crypto,
    decimals: 2,
    nameEs: 'Dai',
    nameEn: 'Dai',
  );

  /// Coins an exchange account often holds, known by name so their accounts
  /// read like the others. Like any coin the app does not know, they show
  /// up to eight decimals.
  static const List<Asset> _named = <Asset>[
    fdusd,
    dai,
    Asset._(
      'XRP',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'XRP',
      nameEn: 'XRP',
    ),
    Asset._(
      'ADA',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'Cardano',
      nameEn: 'Cardano',
    ),
    Asset._(
      'DOGE',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'Dogecoin',
      nameEn: 'Dogecoin',
    ),
    Asset._(
      'TRX',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'TRON',
      nameEn: 'TRON',
    ),
    Asset._(
      'DOT',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'Polkadot',
      nameEn: 'Polkadot',
    ),
    Asset._(
      'LTC',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'Litecoin',
      nameEn: 'Litecoin',
    ),
    Asset._(
      'POL',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'Polygon',
      nameEn: 'Polygon',
    ),
    Asset._(
      'AVAX',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'Avalanche',
      nameEn: 'Avalanche',
    ),
    Asset._(
      'LINK',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'Chainlink',
      nameEn: 'Chainlink',
    ),
    Asset._(
      'SHIB',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'Shiba Inu',
      nameEn: 'Shiba Inu',
    ),
    Asset._(
      'TON',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'Toncoin',
      nameEn: 'Toncoin',
    ),
    Asset._(
      'VET',
      kind: AssetKind.crypto,
      decimals: 8,
      nameEs: 'VeChain',
      nameEn: 'VeChain',
    ),
  ];

  /// The currencies offered when creating an account, most used first.
  static const List<Asset> fiat = <Asset>[cop, usd, eur, mxn, brl, gbp, cad];

  /// The crypto assets offered by name. Any other ticker can be typed.
  static const List<Asset> crypto = <Asset>[usdt, btc, eth, usdc, bnb, sol];

  static final Map<String, Asset> _byCode = <String, Asset>{
    for (final Asset a in <Asset>[...fiat, ...crypto, ..._named]) a.code: a,
  };

  /// The asset for [code], or an [Asset.unknown] when the app has none.
  static Asset of(String code) {
    final String key = code.trim().toUpperCase();
    return _byCode[key] ?? Asset.unknown(key);
  }

  @override
  bool operator ==(Object other) => other is Asset && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
