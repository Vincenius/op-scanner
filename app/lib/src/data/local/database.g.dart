// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SetsTable extends Sets with TableInfo<$SetsTable, CardSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<DateTime> releaseDate = GeneratedColumn<DateTime>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, code, name, releaseDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}release_date'],
      ),
    );
  }

  @override
  $SetsTable createAlias(String alias) {
    return $SetsTable(attachedDatabase, alias);
  }
}

class CardSet extends DataClass implements Insertable<CardSet> {
  final String id;
  final String code;
  final String name;
  final DateTime? releaseDate;
  const CardSet({
    required this.id,
    required this.code,
    required this.name,
    this.releaseDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<DateTime>(releaseDate);
    }
    return map;
  }

  SetsCompanion toCompanion(bool nullToAbsent) {
    return SetsCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      releaseDate: releaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseDate),
    );
  }

  factory CardSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardSet(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      releaseDate: serializer.fromJson<DateTime?>(json['releaseDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'releaseDate': serializer.toJson<DateTime?>(releaseDate),
    };
  }

  CardSet copyWith({
    String? id,
    String? code,
    String? name,
    Value<DateTime?> releaseDate = const Value.absent(),
  }) => CardSet(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
  );
  CardSet copyWithCompanion(SetsCompanion data) {
    return CardSet(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      releaseDate: data.releaseDate.present
          ? data.releaseDate.value
          : this.releaseDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardSet(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('releaseDate: $releaseDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, name, releaseDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardSet &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.releaseDate == this.releaseDate);
}

class SetsCompanion extends UpdateCompanion<CardSet> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<DateTime?> releaseDate;
  final Value<int> rowid;
  const SetsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetsCompanion.insert({
    required String id,
    required String code,
    required String name,
    this.releaseDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name);
  static Insertable<CardSet> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<DateTime>? releaseDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (releaseDate != null) 'release_date': releaseDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetsCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<DateTime?>? releaseDate,
    Value<int>? rowid,
  }) {
    return SetsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      releaseDate: releaseDate ?? this.releaseDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<DateTime>(releaseDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, CatalogCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardCodeMeta = const VerificationMeta(
    'cardCode',
  );
  @override
  late final GeneratedColumn<String> cardCode = GeneratedColumn<String>(
    'card_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorsMeta = const VerificationMeta('colors');
  @override
  late final GeneratedColumn<String> colors = GeneratedColumn<String>(
    'colors',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<int> cost = GeneratedColumn<int>(
    'cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _powerMeta = const VerificationMeta('power');
  @override
  late final GeneratedColumn<int> power = GeneratedColumn<int>(
    'power',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _counterMeta = const VerificationMeta(
    'counter',
  );
  @override
  late final GeneratedColumn<int> counter = GeneratedColumn<int>(
    'counter',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attributeMeta = const VerificationMeta(
    'attribute',
  );
  @override
  late final GeneratedColumn<String> attribute = GeneratedColumn<String>(
    'attribute',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _familyMeta = const VerificationMeta('family');
  @override
  late final GeneratedColumn<String> family = GeneratedColumn<String>(
    'family',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _abilityTextMeta = const VerificationMeta(
    'abilityText',
  );
  @override
  late final GeneratedColumn<String> abilityText = GeneratedColumn<String>(
    'ability_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _triggerTextMeta = const VerificationMeta(
    'triggerText',
  );
  @override
  late final GeneratedColumn<String> triggerText = GeneratedColumn<String>(
    'trigger_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<String> setId = GeneratedColumn<String>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setCodeMeta = const VerificationMeta(
    'setCode',
  );
  @override
  late final GeneratedColumn<String> setCode = GeneratedColumn<String>(
    'set_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardCode,
    name,
    colors,
    type,
    cost,
    power,
    counter,
    attribute,
    family,
    abilityText,
    triggerText,
    setId,
    setCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('card_code')) {
      context.handle(
        _cardCodeMeta,
        cardCode.isAcceptableOrUnknown(data['card_code']!, _cardCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_cardCodeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('colors')) {
      context.handle(
        _colorsMeta,
        colors.isAcceptableOrUnknown(data['colors']!, _colorsMeta),
      );
    } else if (isInserting) {
      context.missing(_colorsMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('cost')) {
      context.handle(
        _costMeta,
        cost.isAcceptableOrUnknown(data['cost']!, _costMeta),
      );
    }
    if (data.containsKey('power')) {
      context.handle(
        _powerMeta,
        power.isAcceptableOrUnknown(data['power']!, _powerMeta),
      );
    }
    if (data.containsKey('counter')) {
      context.handle(
        _counterMeta,
        counter.isAcceptableOrUnknown(data['counter']!, _counterMeta),
      );
    }
    if (data.containsKey('attribute')) {
      context.handle(
        _attributeMeta,
        attribute.isAcceptableOrUnknown(data['attribute']!, _attributeMeta),
      );
    }
    if (data.containsKey('family')) {
      context.handle(
        _familyMeta,
        family.isAcceptableOrUnknown(data['family']!, _familyMeta),
      );
    }
    if (data.containsKey('ability_text')) {
      context.handle(
        _abilityTextMeta,
        abilityText.isAcceptableOrUnknown(
          data['ability_text']!,
          _abilityTextMeta,
        ),
      );
    }
    if (data.containsKey('trigger_text')) {
      context.handle(
        _triggerTextMeta,
        triggerText.isAcceptableOrUnknown(
          data['trigger_text']!,
          _triggerTextMeta,
        ),
      );
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('set_code')) {
      context.handle(
        _setCodeMeta,
        setCode.isAcceptableOrUnknown(data['set_code']!, _setCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_setCodeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cardCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colors'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      cost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost'],
      ),
      power: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}power'],
      ),
      counter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counter'],
      ),
      attribute: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attribute'],
      ),
      family: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family'],
      ),
      abilityText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ability_text'],
      ),
      triggerText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_text'],
      ),
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_id'],
      )!,
      setCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_code'],
      )!,
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class CatalogCard extends DataClass implements Insertable<CatalogCard> {
  final String id;
  final String cardCode;
  final String name;
  final String colors;
  final String type;
  final int? cost;
  final int? power;
  final int? counter;
  final String? attribute;
  final String? family;
  final String? abilityText;
  final String? triggerText;
  final String setId;
  final String setCode;
  const CatalogCard({
    required this.id,
    required this.cardCode,
    required this.name,
    required this.colors,
    required this.type,
    this.cost,
    this.power,
    this.counter,
    this.attribute,
    this.family,
    this.abilityText,
    this.triggerText,
    required this.setId,
    required this.setCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['card_code'] = Variable<String>(cardCode);
    map['name'] = Variable<String>(name);
    map['colors'] = Variable<String>(colors);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || cost != null) {
      map['cost'] = Variable<int>(cost);
    }
    if (!nullToAbsent || power != null) {
      map['power'] = Variable<int>(power);
    }
    if (!nullToAbsent || counter != null) {
      map['counter'] = Variable<int>(counter);
    }
    if (!nullToAbsent || attribute != null) {
      map['attribute'] = Variable<String>(attribute);
    }
    if (!nullToAbsent || family != null) {
      map['family'] = Variable<String>(family);
    }
    if (!nullToAbsent || abilityText != null) {
      map['ability_text'] = Variable<String>(abilityText);
    }
    if (!nullToAbsent || triggerText != null) {
      map['trigger_text'] = Variable<String>(triggerText);
    }
    map['set_id'] = Variable<String>(setId);
    map['set_code'] = Variable<String>(setCode);
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      cardCode: Value(cardCode),
      name: Value(name),
      colors: Value(colors),
      type: Value(type),
      cost: cost == null && nullToAbsent ? const Value.absent() : Value(cost),
      power: power == null && nullToAbsent
          ? const Value.absent()
          : Value(power),
      counter: counter == null && nullToAbsent
          ? const Value.absent()
          : Value(counter),
      attribute: attribute == null && nullToAbsent
          ? const Value.absent()
          : Value(attribute),
      family: family == null && nullToAbsent
          ? const Value.absent()
          : Value(family),
      abilityText: abilityText == null && nullToAbsent
          ? const Value.absent()
          : Value(abilityText),
      triggerText: triggerText == null && nullToAbsent
          ? const Value.absent()
          : Value(triggerText),
      setId: Value(setId),
      setCode: Value(setCode),
    );
  }

  factory CatalogCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogCard(
      id: serializer.fromJson<String>(json['id']),
      cardCode: serializer.fromJson<String>(json['cardCode']),
      name: serializer.fromJson<String>(json['name']),
      colors: serializer.fromJson<String>(json['colors']),
      type: serializer.fromJson<String>(json['type']),
      cost: serializer.fromJson<int?>(json['cost']),
      power: serializer.fromJson<int?>(json['power']),
      counter: serializer.fromJson<int?>(json['counter']),
      attribute: serializer.fromJson<String?>(json['attribute']),
      family: serializer.fromJson<String?>(json['family']),
      abilityText: serializer.fromJson<String?>(json['abilityText']),
      triggerText: serializer.fromJson<String?>(json['triggerText']),
      setId: serializer.fromJson<String>(json['setId']),
      setCode: serializer.fromJson<String>(json['setCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cardCode': serializer.toJson<String>(cardCode),
      'name': serializer.toJson<String>(name),
      'colors': serializer.toJson<String>(colors),
      'type': serializer.toJson<String>(type),
      'cost': serializer.toJson<int?>(cost),
      'power': serializer.toJson<int?>(power),
      'counter': serializer.toJson<int?>(counter),
      'attribute': serializer.toJson<String?>(attribute),
      'family': serializer.toJson<String?>(family),
      'abilityText': serializer.toJson<String?>(abilityText),
      'triggerText': serializer.toJson<String?>(triggerText),
      'setId': serializer.toJson<String>(setId),
      'setCode': serializer.toJson<String>(setCode),
    };
  }

  CatalogCard copyWith({
    String? id,
    String? cardCode,
    String? name,
    String? colors,
    String? type,
    Value<int?> cost = const Value.absent(),
    Value<int?> power = const Value.absent(),
    Value<int?> counter = const Value.absent(),
    Value<String?> attribute = const Value.absent(),
    Value<String?> family = const Value.absent(),
    Value<String?> abilityText = const Value.absent(),
    Value<String?> triggerText = const Value.absent(),
    String? setId,
    String? setCode,
  }) => CatalogCard(
    id: id ?? this.id,
    cardCode: cardCode ?? this.cardCode,
    name: name ?? this.name,
    colors: colors ?? this.colors,
    type: type ?? this.type,
    cost: cost.present ? cost.value : this.cost,
    power: power.present ? power.value : this.power,
    counter: counter.present ? counter.value : this.counter,
    attribute: attribute.present ? attribute.value : this.attribute,
    family: family.present ? family.value : this.family,
    abilityText: abilityText.present ? abilityText.value : this.abilityText,
    triggerText: triggerText.present ? triggerText.value : this.triggerText,
    setId: setId ?? this.setId,
    setCode: setCode ?? this.setCode,
  );
  CatalogCard copyWithCompanion(CardsCompanion data) {
    return CatalogCard(
      id: data.id.present ? data.id.value : this.id,
      cardCode: data.cardCode.present ? data.cardCode.value : this.cardCode,
      name: data.name.present ? data.name.value : this.name,
      colors: data.colors.present ? data.colors.value : this.colors,
      type: data.type.present ? data.type.value : this.type,
      cost: data.cost.present ? data.cost.value : this.cost,
      power: data.power.present ? data.power.value : this.power,
      counter: data.counter.present ? data.counter.value : this.counter,
      attribute: data.attribute.present ? data.attribute.value : this.attribute,
      family: data.family.present ? data.family.value : this.family,
      abilityText: data.abilityText.present
          ? data.abilityText.value
          : this.abilityText,
      triggerText: data.triggerText.present
          ? data.triggerText.value
          : this.triggerText,
      setId: data.setId.present ? data.setId.value : this.setId,
      setCode: data.setCode.present ? data.setCode.value : this.setCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogCard(')
          ..write('id: $id, ')
          ..write('cardCode: $cardCode, ')
          ..write('name: $name, ')
          ..write('colors: $colors, ')
          ..write('type: $type, ')
          ..write('cost: $cost, ')
          ..write('power: $power, ')
          ..write('counter: $counter, ')
          ..write('attribute: $attribute, ')
          ..write('family: $family, ')
          ..write('abilityText: $abilityText, ')
          ..write('triggerText: $triggerText, ')
          ..write('setId: $setId, ')
          ..write('setCode: $setCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardCode,
    name,
    colors,
    type,
    cost,
    power,
    counter,
    attribute,
    family,
    abilityText,
    triggerText,
    setId,
    setCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogCard &&
          other.id == this.id &&
          other.cardCode == this.cardCode &&
          other.name == this.name &&
          other.colors == this.colors &&
          other.type == this.type &&
          other.cost == this.cost &&
          other.power == this.power &&
          other.counter == this.counter &&
          other.attribute == this.attribute &&
          other.family == this.family &&
          other.abilityText == this.abilityText &&
          other.triggerText == this.triggerText &&
          other.setId == this.setId &&
          other.setCode == this.setCode);
}

class CardsCompanion extends UpdateCompanion<CatalogCard> {
  final Value<String> id;
  final Value<String> cardCode;
  final Value<String> name;
  final Value<String> colors;
  final Value<String> type;
  final Value<int?> cost;
  final Value<int?> power;
  final Value<int?> counter;
  final Value<String?> attribute;
  final Value<String?> family;
  final Value<String?> abilityText;
  final Value<String?> triggerText;
  final Value<String> setId;
  final Value<String> setCode;
  final Value<int> rowid;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.cardCode = const Value.absent(),
    this.name = const Value.absent(),
    this.colors = const Value.absent(),
    this.type = const Value.absent(),
    this.cost = const Value.absent(),
    this.power = const Value.absent(),
    this.counter = const Value.absent(),
    this.attribute = const Value.absent(),
    this.family = const Value.absent(),
    this.abilityText = const Value.absent(),
    this.triggerText = const Value.absent(),
    this.setId = const Value.absent(),
    this.setCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required String id,
    required String cardCode,
    required String name,
    required String colors,
    required String type,
    this.cost = const Value.absent(),
    this.power = const Value.absent(),
    this.counter = const Value.absent(),
    this.attribute = const Value.absent(),
    this.family = const Value.absent(),
    this.abilityText = const Value.absent(),
    this.triggerText = const Value.absent(),
    required String setId,
    required String setCode,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cardCode = Value(cardCode),
       name = Value(name),
       colors = Value(colors),
       type = Value(type),
       setId = Value(setId),
       setCode = Value(setCode);
  static Insertable<CatalogCard> custom({
    Expression<String>? id,
    Expression<String>? cardCode,
    Expression<String>? name,
    Expression<String>? colors,
    Expression<String>? type,
    Expression<int>? cost,
    Expression<int>? power,
    Expression<int>? counter,
    Expression<String>? attribute,
    Expression<String>? family,
    Expression<String>? abilityText,
    Expression<String>? triggerText,
    Expression<String>? setId,
    Expression<String>? setCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardCode != null) 'card_code': cardCode,
      if (name != null) 'name': name,
      if (colors != null) 'colors': colors,
      if (type != null) 'type': type,
      if (cost != null) 'cost': cost,
      if (power != null) 'power': power,
      if (counter != null) 'counter': counter,
      if (attribute != null) 'attribute': attribute,
      if (family != null) 'family': family,
      if (abilityText != null) 'ability_text': abilityText,
      if (triggerText != null) 'trigger_text': triggerText,
      if (setId != null) 'set_id': setId,
      if (setCode != null) 'set_code': setCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith({
    Value<String>? id,
    Value<String>? cardCode,
    Value<String>? name,
    Value<String>? colors,
    Value<String>? type,
    Value<int?>? cost,
    Value<int?>? power,
    Value<int?>? counter,
    Value<String?>? attribute,
    Value<String?>? family,
    Value<String?>? abilityText,
    Value<String?>? triggerText,
    Value<String>? setId,
    Value<String>? setCode,
    Value<int>? rowid,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      cardCode: cardCode ?? this.cardCode,
      name: name ?? this.name,
      colors: colors ?? this.colors,
      type: type ?? this.type,
      cost: cost ?? this.cost,
      power: power ?? this.power,
      counter: counter ?? this.counter,
      attribute: attribute ?? this.attribute,
      family: family ?? this.family,
      abilityText: abilityText ?? this.abilityText,
      triggerText: triggerText ?? this.triggerText,
      setId: setId ?? this.setId,
      setCode: setCode ?? this.setCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cardCode.present) {
      map['card_code'] = Variable<String>(cardCode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colors.present) {
      map['colors'] = Variable<String>(colors.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (cost.present) {
      map['cost'] = Variable<int>(cost.value);
    }
    if (power.present) {
      map['power'] = Variable<int>(power.value);
    }
    if (counter.present) {
      map['counter'] = Variable<int>(counter.value);
    }
    if (attribute.present) {
      map['attribute'] = Variable<String>(attribute.value);
    }
    if (family.present) {
      map['family'] = Variable<String>(family.value);
    }
    if (abilityText.present) {
      map['ability_text'] = Variable<String>(abilityText.value);
    }
    if (triggerText.present) {
      map['trigger_text'] = Variable<String>(triggerText.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<String>(setId.value);
    }
    if (setCode.present) {
      map['set_code'] = Variable<String>(setCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('cardCode: $cardCode, ')
          ..write('name: $name, ')
          ..write('colors: $colors, ')
          ..write('type: $type, ')
          ..write('cost: $cost, ')
          ..write('power: $power, ')
          ..write('counter: $counter, ')
          ..write('attribute: $attribute, ')
          ..write('family: $family, ')
          ..write('abilityText: $abilityText, ')
          ..write('triggerText: $triggerText, ')
          ..write('setId: $setId, ')
          ..write('setCode: $setCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VariantsTable extends Variants
    with TableInfo<$VariantsTable, CatalogVariant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VariantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _variantIdMeta = const VerificationMeta(
    'variantId',
  );
  @override
  late final GeneratedColumn<String> variantId = GeneratedColumn<String>(
    'variant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<String> rarity = GeneratedColumn<String>(
    'rarity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAltArtMeta = const VerificationMeta(
    'isAltArt',
  );
  @override
  late final GeneratedColumn<bool> isAltArt = GeneratedColumn<bool>(
    'is_alt_art',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_alt_art" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _variantLabelMeta = const VerificationMeta(
    'variantLabel',
  );
  @override
  late final GeneratedColumn<String> variantLabel = GeneratedColumn<String>(
    'variant_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullUrlMeta = const VerificationMeta(
    'fullUrl',
  );
  @override
  late final GeneratedColumn<String> fullUrl = GeneratedColumn<String>(
    'full_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marketPriceMeta = const VerificationMeta(
    'marketPrice',
  );
  @override
  late final GeneratedColumn<double> marketPrice = GeneratedColumn<double>(
    'market_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lowPriceMeta = const VerificationMeta(
    'lowPrice',
  );
  @override
  late final GeneratedColumn<double> lowPrice = GeneratedColumn<double>(
    'low_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceCurrencyMeta = const VerificationMeta(
    'priceCurrency',
  );
  @override
  late final GeneratedColumn<String> priceCurrency = GeneratedColumn<String>(
    'price_currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceCapturedAtMeta = const VerificationMeta(
    'priceCapturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> priceCapturedAt =
      GeneratedColumn<DateTime>(
        'price_captured_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _phashMeta = const VerificationMeta('phash');
  @override
  late final GeneratedColumn<String> phash = GeneratedColumn<String>(
    'phash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    variantId,
    cardId,
    rarity,
    isAltArt,
    variantLabel,
    thumbUrl,
    fullUrl,
    marketPrice,
    lowPrice,
    priceCurrency,
    priceCapturedAt,
    phash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'variants';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogVariant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('variant_id')) {
      context.handle(
        _variantIdMeta,
        variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_variantIdMeta);
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('rarity')) {
      context.handle(
        _rarityMeta,
        rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta),
      );
    }
    if (data.containsKey('is_alt_art')) {
      context.handle(
        _isAltArtMeta,
        isAltArt.isAcceptableOrUnknown(data['is_alt_art']!, _isAltArtMeta),
      );
    }
    if (data.containsKey('variant_label')) {
      context.handle(
        _variantLabelMeta,
        variantLabel.isAcceptableOrUnknown(
          data['variant_label']!,
          _variantLabelMeta,
        ),
      );
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_thumbUrlMeta);
    }
    if (data.containsKey('full_url')) {
      context.handle(
        _fullUrlMeta,
        fullUrl.isAcceptableOrUnknown(data['full_url']!, _fullUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_fullUrlMeta);
    }
    if (data.containsKey('market_price')) {
      context.handle(
        _marketPriceMeta,
        marketPrice.isAcceptableOrUnknown(
          data['market_price']!,
          _marketPriceMeta,
        ),
      );
    }
    if (data.containsKey('low_price')) {
      context.handle(
        _lowPriceMeta,
        lowPrice.isAcceptableOrUnknown(data['low_price']!, _lowPriceMeta),
      );
    }
    if (data.containsKey('price_currency')) {
      context.handle(
        _priceCurrencyMeta,
        priceCurrency.isAcceptableOrUnknown(
          data['price_currency']!,
          _priceCurrencyMeta,
        ),
      );
    }
    if (data.containsKey('price_captured_at')) {
      context.handle(
        _priceCapturedAtMeta,
        priceCapturedAt.isAcceptableOrUnknown(
          data['price_captured_at']!,
          _priceCapturedAtMeta,
        ),
      );
    }
    if (data.containsKey('phash')) {
      context.handle(
        _phashMeta,
        phash.isAcceptableOrUnknown(data['phash']!, _phashMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {variantId};
  @override
  CatalogVariant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogVariant(
      variantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      )!,
      rarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity'],
      ),
      isAltArt: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_alt_art'],
      )!,
      variantLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_label'],
      ),
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      )!,
      fullUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_url'],
      )!,
      marketPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}market_price'],
      ),
      lowPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}low_price'],
      ),
      priceCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price_currency'],
      ),
      priceCapturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}price_captured_at'],
      ),
      phash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phash'],
      ),
    );
  }

  @override
  $VariantsTable createAlias(String alias) {
    return $VariantsTable(attachedDatabase, alias);
  }
}

class CatalogVariant extends DataClass implements Insertable<CatalogVariant> {
  final String variantId;
  final String cardId;
  final String? rarity;
  final bool isAltArt;
  final String? variantLabel;
  final String thumbUrl;
  final String fullUrl;
  final double? marketPrice;
  final double? lowPrice;
  final String? priceCurrency;
  final DateTime? priceCapturedAt;
  final String? phash;
  const CatalogVariant({
    required this.variantId,
    required this.cardId,
    this.rarity,
    required this.isAltArt,
    this.variantLabel,
    required this.thumbUrl,
    required this.fullUrl,
    this.marketPrice,
    this.lowPrice,
    this.priceCurrency,
    this.priceCapturedAt,
    this.phash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['variant_id'] = Variable<String>(variantId);
    map['card_id'] = Variable<String>(cardId);
    if (!nullToAbsent || rarity != null) {
      map['rarity'] = Variable<String>(rarity);
    }
    map['is_alt_art'] = Variable<bool>(isAltArt);
    if (!nullToAbsent || variantLabel != null) {
      map['variant_label'] = Variable<String>(variantLabel);
    }
    map['thumb_url'] = Variable<String>(thumbUrl);
    map['full_url'] = Variable<String>(fullUrl);
    if (!nullToAbsent || marketPrice != null) {
      map['market_price'] = Variable<double>(marketPrice);
    }
    if (!nullToAbsent || lowPrice != null) {
      map['low_price'] = Variable<double>(lowPrice);
    }
    if (!nullToAbsent || priceCurrency != null) {
      map['price_currency'] = Variable<String>(priceCurrency);
    }
    if (!nullToAbsent || priceCapturedAt != null) {
      map['price_captured_at'] = Variable<DateTime>(priceCapturedAt);
    }
    if (!nullToAbsent || phash != null) {
      map['phash'] = Variable<String>(phash);
    }
    return map;
  }

  VariantsCompanion toCompanion(bool nullToAbsent) {
    return VariantsCompanion(
      variantId: Value(variantId),
      cardId: Value(cardId),
      rarity: rarity == null && nullToAbsent
          ? const Value.absent()
          : Value(rarity),
      isAltArt: Value(isAltArt),
      variantLabel: variantLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(variantLabel),
      thumbUrl: Value(thumbUrl),
      fullUrl: Value(fullUrl),
      marketPrice: marketPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(marketPrice),
      lowPrice: lowPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(lowPrice),
      priceCurrency: priceCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(priceCurrency),
      priceCapturedAt: priceCapturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(priceCapturedAt),
      phash: phash == null && nullToAbsent
          ? const Value.absent()
          : Value(phash),
    );
  }

  factory CatalogVariant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogVariant(
      variantId: serializer.fromJson<String>(json['variantId']),
      cardId: serializer.fromJson<String>(json['cardId']),
      rarity: serializer.fromJson<String?>(json['rarity']),
      isAltArt: serializer.fromJson<bool>(json['isAltArt']),
      variantLabel: serializer.fromJson<String?>(json['variantLabel']),
      thumbUrl: serializer.fromJson<String>(json['thumbUrl']),
      fullUrl: serializer.fromJson<String>(json['fullUrl']),
      marketPrice: serializer.fromJson<double?>(json['marketPrice']),
      lowPrice: serializer.fromJson<double?>(json['lowPrice']),
      priceCurrency: serializer.fromJson<String?>(json['priceCurrency']),
      priceCapturedAt: serializer.fromJson<DateTime?>(json['priceCapturedAt']),
      phash: serializer.fromJson<String?>(json['phash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'variantId': serializer.toJson<String>(variantId),
      'cardId': serializer.toJson<String>(cardId),
      'rarity': serializer.toJson<String?>(rarity),
      'isAltArt': serializer.toJson<bool>(isAltArt),
      'variantLabel': serializer.toJson<String?>(variantLabel),
      'thumbUrl': serializer.toJson<String>(thumbUrl),
      'fullUrl': serializer.toJson<String>(fullUrl),
      'marketPrice': serializer.toJson<double?>(marketPrice),
      'lowPrice': serializer.toJson<double?>(lowPrice),
      'priceCurrency': serializer.toJson<String?>(priceCurrency),
      'priceCapturedAt': serializer.toJson<DateTime?>(priceCapturedAt),
      'phash': serializer.toJson<String?>(phash),
    };
  }

  CatalogVariant copyWith({
    String? variantId,
    String? cardId,
    Value<String?> rarity = const Value.absent(),
    bool? isAltArt,
    Value<String?> variantLabel = const Value.absent(),
    String? thumbUrl,
    String? fullUrl,
    Value<double?> marketPrice = const Value.absent(),
    Value<double?> lowPrice = const Value.absent(),
    Value<String?> priceCurrency = const Value.absent(),
    Value<DateTime?> priceCapturedAt = const Value.absent(),
    Value<String?> phash = const Value.absent(),
  }) => CatalogVariant(
    variantId: variantId ?? this.variantId,
    cardId: cardId ?? this.cardId,
    rarity: rarity.present ? rarity.value : this.rarity,
    isAltArt: isAltArt ?? this.isAltArt,
    variantLabel: variantLabel.present ? variantLabel.value : this.variantLabel,
    thumbUrl: thumbUrl ?? this.thumbUrl,
    fullUrl: fullUrl ?? this.fullUrl,
    marketPrice: marketPrice.present ? marketPrice.value : this.marketPrice,
    lowPrice: lowPrice.present ? lowPrice.value : this.lowPrice,
    priceCurrency: priceCurrency.present
        ? priceCurrency.value
        : this.priceCurrency,
    priceCapturedAt: priceCapturedAt.present
        ? priceCapturedAt.value
        : this.priceCapturedAt,
    phash: phash.present ? phash.value : this.phash,
  );
  CatalogVariant copyWithCompanion(VariantsCompanion data) {
    return CatalogVariant(
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      isAltArt: data.isAltArt.present ? data.isAltArt.value : this.isAltArt,
      variantLabel: data.variantLabel.present
          ? data.variantLabel.value
          : this.variantLabel,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
      fullUrl: data.fullUrl.present ? data.fullUrl.value : this.fullUrl,
      marketPrice: data.marketPrice.present
          ? data.marketPrice.value
          : this.marketPrice,
      lowPrice: data.lowPrice.present ? data.lowPrice.value : this.lowPrice,
      priceCurrency: data.priceCurrency.present
          ? data.priceCurrency.value
          : this.priceCurrency,
      priceCapturedAt: data.priceCapturedAt.present
          ? data.priceCapturedAt.value
          : this.priceCapturedAt,
      phash: data.phash.present ? data.phash.value : this.phash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogVariant(')
          ..write('variantId: $variantId, ')
          ..write('cardId: $cardId, ')
          ..write('rarity: $rarity, ')
          ..write('isAltArt: $isAltArt, ')
          ..write('variantLabel: $variantLabel, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('fullUrl: $fullUrl, ')
          ..write('marketPrice: $marketPrice, ')
          ..write('lowPrice: $lowPrice, ')
          ..write('priceCurrency: $priceCurrency, ')
          ..write('priceCapturedAt: $priceCapturedAt, ')
          ..write('phash: $phash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    variantId,
    cardId,
    rarity,
    isAltArt,
    variantLabel,
    thumbUrl,
    fullUrl,
    marketPrice,
    lowPrice,
    priceCurrency,
    priceCapturedAt,
    phash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogVariant &&
          other.variantId == this.variantId &&
          other.cardId == this.cardId &&
          other.rarity == this.rarity &&
          other.isAltArt == this.isAltArt &&
          other.variantLabel == this.variantLabel &&
          other.thumbUrl == this.thumbUrl &&
          other.fullUrl == this.fullUrl &&
          other.marketPrice == this.marketPrice &&
          other.lowPrice == this.lowPrice &&
          other.priceCurrency == this.priceCurrency &&
          other.priceCapturedAt == this.priceCapturedAt &&
          other.phash == this.phash);
}

class VariantsCompanion extends UpdateCompanion<CatalogVariant> {
  final Value<String> variantId;
  final Value<String> cardId;
  final Value<String?> rarity;
  final Value<bool> isAltArt;
  final Value<String?> variantLabel;
  final Value<String> thumbUrl;
  final Value<String> fullUrl;
  final Value<double?> marketPrice;
  final Value<double?> lowPrice;
  final Value<String?> priceCurrency;
  final Value<DateTime?> priceCapturedAt;
  final Value<String?> phash;
  final Value<int> rowid;
  const VariantsCompanion({
    this.variantId = const Value.absent(),
    this.cardId = const Value.absent(),
    this.rarity = const Value.absent(),
    this.isAltArt = const Value.absent(),
    this.variantLabel = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.fullUrl = const Value.absent(),
    this.marketPrice = const Value.absent(),
    this.lowPrice = const Value.absent(),
    this.priceCurrency = const Value.absent(),
    this.priceCapturedAt = const Value.absent(),
    this.phash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VariantsCompanion.insert({
    required String variantId,
    required String cardId,
    this.rarity = const Value.absent(),
    this.isAltArt = const Value.absent(),
    this.variantLabel = const Value.absent(),
    required String thumbUrl,
    required String fullUrl,
    this.marketPrice = const Value.absent(),
    this.lowPrice = const Value.absent(),
    this.priceCurrency = const Value.absent(),
    this.priceCapturedAt = const Value.absent(),
    this.phash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : variantId = Value(variantId),
       cardId = Value(cardId),
       thumbUrl = Value(thumbUrl),
       fullUrl = Value(fullUrl);
  static Insertable<CatalogVariant> custom({
    Expression<String>? variantId,
    Expression<String>? cardId,
    Expression<String>? rarity,
    Expression<bool>? isAltArt,
    Expression<String>? variantLabel,
    Expression<String>? thumbUrl,
    Expression<String>? fullUrl,
    Expression<double>? marketPrice,
    Expression<double>? lowPrice,
    Expression<String>? priceCurrency,
    Expression<DateTime>? priceCapturedAt,
    Expression<String>? phash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (variantId != null) 'variant_id': variantId,
      if (cardId != null) 'card_id': cardId,
      if (rarity != null) 'rarity': rarity,
      if (isAltArt != null) 'is_alt_art': isAltArt,
      if (variantLabel != null) 'variant_label': variantLabel,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (fullUrl != null) 'full_url': fullUrl,
      if (marketPrice != null) 'market_price': marketPrice,
      if (lowPrice != null) 'low_price': lowPrice,
      if (priceCurrency != null) 'price_currency': priceCurrency,
      if (priceCapturedAt != null) 'price_captured_at': priceCapturedAt,
      if (phash != null) 'phash': phash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VariantsCompanion copyWith({
    Value<String>? variantId,
    Value<String>? cardId,
    Value<String?>? rarity,
    Value<bool>? isAltArt,
    Value<String?>? variantLabel,
    Value<String>? thumbUrl,
    Value<String>? fullUrl,
    Value<double?>? marketPrice,
    Value<double?>? lowPrice,
    Value<String?>? priceCurrency,
    Value<DateTime?>? priceCapturedAt,
    Value<String?>? phash,
    Value<int>? rowid,
  }) {
    return VariantsCompanion(
      variantId: variantId ?? this.variantId,
      cardId: cardId ?? this.cardId,
      rarity: rarity ?? this.rarity,
      isAltArt: isAltArt ?? this.isAltArt,
      variantLabel: variantLabel ?? this.variantLabel,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      fullUrl: fullUrl ?? this.fullUrl,
      marketPrice: marketPrice ?? this.marketPrice,
      lowPrice: lowPrice ?? this.lowPrice,
      priceCurrency: priceCurrency ?? this.priceCurrency,
      priceCapturedAt: priceCapturedAt ?? this.priceCapturedAt,
      phash: phash ?? this.phash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<String>(rarity.value);
    }
    if (isAltArt.present) {
      map['is_alt_art'] = Variable<bool>(isAltArt.value);
    }
    if (variantLabel.present) {
      map['variant_label'] = Variable<String>(variantLabel.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (fullUrl.present) {
      map['full_url'] = Variable<String>(fullUrl.value);
    }
    if (marketPrice.present) {
      map['market_price'] = Variable<double>(marketPrice.value);
    }
    if (lowPrice.present) {
      map['low_price'] = Variable<double>(lowPrice.value);
    }
    if (priceCurrency.present) {
      map['price_currency'] = Variable<String>(priceCurrency.value);
    }
    if (priceCapturedAt.present) {
      map['price_captured_at'] = Variable<DateTime>(priceCapturedAt.value);
    }
    if (phash.present) {
      map['phash'] = Variable<String>(phash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VariantsCompanion(')
          ..write('variantId: $variantId, ')
          ..write('cardId: $cardId, ')
          ..write('rarity: $rarity, ')
          ..write('isAltArt: $isAltArt, ')
          ..write('variantLabel: $variantLabel, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('fullUrl: $fullUrl, ')
          ..write('marketPrice: $marketPrice, ')
          ..write('lowPrice: $lowPrice, ')
          ..write('priceCurrency: $priceCurrency, ')
          ..write('priceCapturedAt: $priceCapturedAt, ')
          ..write('phash: $phash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, lastSyncAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      ),
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaRow extends DataClass implements Insertable<SyncMetaRow> {
  final int id;
  final DateTime? lastSyncAt;
  const SyncMetaRow({required this.id, this.lastSyncAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      id: Value(id),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
    );
  }

  factory SyncMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaRow(
      id: serializer.fromJson<int>(json['id']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
    };
  }

  SyncMetaRow copyWith({
    int? id,
    Value<DateTime?> lastSyncAt = const Value.absent(),
  }) => SyncMetaRow(
    id: id ?? this.id,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
  );
  SyncMetaRow copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaRow(
      id: data.id.present ? data.id.value : this.id,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaRow(')
          ..write('id: $id, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lastSyncAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaRow &&
          other.id == this.id &&
          other.lastSyncAt == this.lastSyncAt);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaRow> {
  final Value<int> id;
  final Value<DateTime?> lastSyncAt;
  const SyncMetaCompanion({
    this.id = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    this.id = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
  });
  static Insertable<SyncMetaRow> custom({
    Expression<int>? id,
    Expression<DateTime>? lastSyncAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
    });
  }

  SyncMetaCompanion copyWith({Value<int>? id, Value<DateTime?>? lastSyncAt}) {
    return SyncMetaCompanion(
      id: id ?? this.id,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('id: $id, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SetsTable sets = $SetsTable(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $VariantsTable variants = $VariantsTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sets,
    cards,
    variants,
    syncMeta,
  ];
}

typedef $$SetsTableCreateCompanionBuilder =
    SetsCompanion Function({
      required String id,
      required String code,
      required String name,
      Value<DateTime?> releaseDate,
      Value<int> rowid,
    });
typedef $$SetsTableUpdateCompanionBuilder =
    SetsCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<DateTime?> releaseDate,
      Value<int> rowid,
    });

class $$SetsTableFilterComposer extends Composer<_$AppDatabase, $SetsTable> {
  $$SetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SetsTableOrderingComposer extends Composer<_$AppDatabase, $SetsTable> {
  $$SetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetsTable> {
  $$SetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );
}

class $$SetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetsTable,
          CardSet,
          $$SetsTableFilterComposer,
          $$SetsTableOrderingComposer,
          $$SetsTableAnnotationComposer,
          $$SetsTableCreateCompanionBuilder,
          $$SetsTableUpdateCompanionBuilder,
          (CardSet, BaseReferences<_$AppDatabase, $SetsTable, CardSet>),
          CardSet,
          PrefetchHooks Function()
        > {
  $$SetsTableTableManager(_$AppDatabase db, $SetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime?> releaseDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetsCompanion(
                id: id,
                code: code,
                name: name,
                releaseDate: releaseDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                Value<DateTime?> releaseDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetsCompanion.insert(
                id: id,
                code: code,
                name: name,
                releaseDate: releaseDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetsTable,
      CardSet,
      $$SetsTableFilterComposer,
      $$SetsTableOrderingComposer,
      $$SetsTableAnnotationComposer,
      $$SetsTableCreateCompanionBuilder,
      $$SetsTableUpdateCompanionBuilder,
      (CardSet, BaseReferences<_$AppDatabase, $SetsTable, CardSet>),
      CardSet,
      PrefetchHooks Function()
    >;
typedef $$CardsTableCreateCompanionBuilder =
    CardsCompanion Function({
      required String id,
      required String cardCode,
      required String name,
      required String colors,
      required String type,
      Value<int?> cost,
      Value<int?> power,
      Value<int?> counter,
      Value<String?> attribute,
      Value<String?> family,
      Value<String?> abilityText,
      Value<String?> triggerText,
      required String setId,
      required String setCode,
      Value<int> rowid,
    });
typedef $$CardsTableUpdateCompanionBuilder =
    CardsCompanion Function({
      Value<String> id,
      Value<String> cardCode,
      Value<String> name,
      Value<String> colors,
      Value<String> type,
      Value<int?> cost,
      Value<int?> power,
      Value<int?> counter,
      Value<String?> attribute,
      Value<String?> family,
      Value<String?> abilityText,
      Value<String?> triggerText,
      Value<String> setId,
      Value<String> setCode,
      Value<int> rowid,
    });

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardCode => $composableBuilder(
    column: $table.cardCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colors => $composableBuilder(
    column: $table.colors,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get power => $composableBuilder(
    column: $table.power,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get counter => $composableBuilder(
    column: $table.counter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attribute => $composableBuilder(
    column: $table.attribute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get abilityText => $composableBuilder(
    column: $table.abilityText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerText => $composableBuilder(
    column: $table.triggerText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setId => $composableBuilder(
    column: $table.setId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setCode => $composableBuilder(
    column: $table.setCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardCode => $composableBuilder(
    column: $table.cardCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colors => $composableBuilder(
    column: $table.colors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get power => $composableBuilder(
    column: $table.power,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get counter => $composableBuilder(
    column: $table.counter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attribute => $composableBuilder(
    column: $table.attribute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get abilityText => $composableBuilder(
    column: $table.abilityText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerText => $composableBuilder(
    column: $table.triggerText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setId => $composableBuilder(
    column: $table.setId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setCode => $composableBuilder(
    column: $table.setCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cardCode =>
      $composableBuilder(column: $table.cardCode, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colors =>
      $composableBuilder(column: $table.colors, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => column);

  GeneratedColumn<int> get power =>
      $composableBuilder(column: $table.power, builder: (column) => column);

  GeneratedColumn<int> get counter =>
      $composableBuilder(column: $table.counter, builder: (column) => column);

  GeneratedColumn<String> get attribute =>
      $composableBuilder(column: $table.attribute, builder: (column) => column);

  GeneratedColumn<String> get family =>
      $composableBuilder(column: $table.family, builder: (column) => column);

  GeneratedColumn<String> get abilityText => $composableBuilder(
    column: $table.abilityText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triggerText => $composableBuilder(
    column: $table.triggerText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get setId =>
      $composableBuilder(column: $table.setId, builder: (column) => column);

  GeneratedColumn<String> get setCode =>
      $composableBuilder(column: $table.setCode, builder: (column) => column);
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          CatalogCard,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (
            CatalogCard,
            BaseReferences<_$AppDatabase, $CardsTable, CatalogCard>,
          ),
          CatalogCard,
          PrefetchHooks Function()
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cardCode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> colors = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> cost = const Value.absent(),
                Value<int?> power = const Value.absent(),
                Value<int?> counter = const Value.absent(),
                Value<String?> attribute = const Value.absent(),
                Value<String?> family = const Value.absent(),
                Value<String?> abilityText = const Value.absent(),
                Value<String?> triggerText = const Value.absent(),
                Value<String> setId = const Value.absent(),
                Value<String> setCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                cardCode: cardCode,
                name: name,
                colors: colors,
                type: type,
                cost: cost,
                power: power,
                counter: counter,
                attribute: attribute,
                family: family,
                abilityText: abilityText,
                triggerText: triggerText,
                setId: setId,
                setCode: setCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cardCode,
                required String name,
                required String colors,
                required String type,
                Value<int?> cost = const Value.absent(),
                Value<int?> power = const Value.absent(),
                Value<int?> counter = const Value.absent(),
                Value<String?> attribute = const Value.absent(),
                Value<String?> family = const Value.absent(),
                Value<String?> abilityText = const Value.absent(),
                Value<String?> triggerText = const Value.absent(),
                required String setId,
                required String setCode,
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                cardCode: cardCode,
                name: name,
                colors: colors,
                type: type,
                cost: cost,
                power: power,
                counter: counter,
                attribute: attribute,
                family: family,
                abilityText: abilityText,
                triggerText: triggerText,
                setId: setId,
                setCode: setCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      CatalogCard,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (CatalogCard, BaseReferences<_$AppDatabase, $CardsTable, CatalogCard>),
      CatalogCard,
      PrefetchHooks Function()
    >;
typedef $$VariantsTableCreateCompanionBuilder =
    VariantsCompanion Function({
      required String variantId,
      required String cardId,
      Value<String?> rarity,
      Value<bool> isAltArt,
      Value<String?> variantLabel,
      required String thumbUrl,
      required String fullUrl,
      Value<double?> marketPrice,
      Value<double?> lowPrice,
      Value<String?> priceCurrency,
      Value<DateTime?> priceCapturedAt,
      Value<String?> phash,
      Value<int> rowid,
    });
typedef $$VariantsTableUpdateCompanionBuilder =
    VariantsCompanion Function({
      Value<String> variantId,
      Value<String> cardId,
      Value<String?> rarity,
      Value<bool> isAltArt,
      Value<String?> variantLabel,
      Value<String> thumbUrl,
      Value<String> fullUrl,
      Value<double?> marketPrice,
      Value<double?> lowPrice,
      Value<String?> priceCurrency,
      Value<DateTime?> priceCapturedAt,
      Value<String?> phash,
      Value<int> rowid,
    });

class $$VariantsTableFilterComposer
    extends Composer<_$AppDatabase, $VariantsTable> {
  $$VariantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAltArt => $composableBuilder(
    column: $table.isAltArt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantLabel => $composableBuilder(
    column: $table.variantLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullUrl => $composableBuilder(
    column: $table.fullUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get marketPrice => $composableBuilder(
    column: $table.marketPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lowPrice => $composableBuilder(
    column: $table.lowPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priceCurrency => $composableBuilder(
    column: $table.priceCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get priceCapturedAt => $composableBuilder(
    column: $table.priceCapturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phash => $composableBuilder(
    column: $table.phash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VariantsTableOrderingComposer
    extends Composer<_$AppDatabase, $VariantsTable> {
  $$VariantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAltArt => $composableBuilder(
    column: $table.isAltArt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantLabel => $composableBuilder(
    column: $table.variantLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullUrl => $composableBuilder(
    column: $table.fullUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get marketPrice => $composableBuilder(
    column: $table.marketPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lowPrice => $composableBuilder(
    column: $table.lowPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priceCurrency => $composableBuilder(
    column: $table.priceCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get priceCapturedAt => $composableBuilder(
    column: $table.priceCapturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phash => $composableBuilder(
    column: $table.phash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VariantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VariantsTable> {
  $$VariantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<String> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<String> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<bool> get isAltArt =>
      $composableBuilder(column: $table.isAltArt, builder: (column) => column);

  GeneratedColumn<String> get variantLabel => $composableBuilder(
    column: $table.variantLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  GeneratedColumn<String> get fullUrl =>
      $composableBuilder(column: $table.fullUrl, builder: (column) => column);

  GeneratedColumn<double> get marketPrice => $composableBuilder(
    column: $table.marketPrice,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lowPrice =>
      $composableBuilder(column: $table.lowPrice, builder: (column) => column);

  GeneratedColumn<String> get priceCurrency => $composableBuilder(
    column: $table.priceCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get priceCapturedAt => $composableBuilder(
    column: $table.priceCapturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phash =>
      $composableBuilder(column: $table.phash, builder: (column) => column);
}

class $$VariantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VariantsTable,
          CatalogVariant,
          $$VariantsTableFilterComposer,
          $$VariantsTableOrderingComposer,
          $$VariantsTableAnnotationComposer,
          $$VariantsTableCreateCompanionBuilder,
          $$VariantsTableUpdateCompanionBuilder,
          (
            CatalogVariant,
            BaseReferences<_$AppDatabase, $VariantsTable, CatalogVariant>,
          ),
          CatalogVariant,
          PrefetchHooks Function()
        > {
  $$VariantsTableTableManager(_$AppDatabase db, $VariantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VariantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VariantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VariantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> variantId = const Value.absent(),
                Value<String> cardId = const Value.absent(),
                Value<String?> rarity = const Value.absent(),
                Value<bool> isAltArt = const Value.absent(),
                Value<String?> variantLabel = const Value.absent(),
                Value<String> thumbUrl = const Value.absent(),
                Value<String> fullUrl = const Value.absent(),
                Value<double?> marketPrice = const Value.absent(),
                Value<double?> lowPrice = const Value.absent(),
                Value<String?> priceCurrency = const Value.absent(),
                Value<DateTime?> priceCapturedAt = const Value.absent(),
                Value<String?> phash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VariantsCompanion(
                variantId: variantId,
                cardId: cardId,
                rarity: rarity,
                isAltArt: isAltArt,
                variantLabel: variantLabel,
                thumbUrl: thumbUrl,
                fullUrl: fullUrl,
                marketPrice: marketPrice,
                lowPrice: lowPrice,
                priceCurrency: priceCurrency,
                priceCapturedAt: priceCapturedAt,
                phash: phash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String variantId,
                required String cardId,
                Value<String?> rarity = const Value.absent(),
                Value<bool> isAltArt = const Value.absent(),
                Value<String?> variantLabel = const Value.absent(),
                required String thumbUrl,
                required String fullUrl,
                Value<double?> marketPrice = const Value.absent(),
                Value<double?> lowPrice = const Value.absent(),
                Value<String?> priceCurrency = const Value.absent(),
                Value<DateTime?> priceCapturedAt = const Value.absent(),
                Value<String?> phash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VariantsCompanion.insert(
                variantId: variantId,
                cardId: cardId,
                rarity: rarity,
                isAltArt: isAltArt,
                variantLabel: variantLabel,
                thumbUrl: thumbUrl,
                fullUrl: fullUrl,
                marketPrice: marketPrice,
                lowPrice: lowPrice,
                priceCurrency: priceCurrency,
                priceCapturedAt: priceCapturedAt,
                phash: phash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VariantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VariantsTable,
      CatalogVariant,
      $$VariantsTableFilterComposer,
      $$VariantsTableOrderingComposer,
      $$VariantsTableAnnotationComposer,
      $$VariantsTableCreateCompanionBuilder,
      $$VariantsTableUpdateCompanionBuilder,
      (
        CatalogVariant,
        BaseReferences<_$AppDatabase, $VariantsTable, CatalogVariant>,
      ),
      CatalogVariant,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder =
    SyncMetaCompanion Function({Value<int> id, Value<DateTime?> lastSyncAt});
typedef $$SyncMetaTableUpdateCompanionBuilder =
    SyncMetaCompanion Function({Value<int> id, Value<DateTime?> lastSyncAt});

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaRow,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaRow,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaRow>,
          ),
          SyncMetaRow,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
              }) => SyncMetaCompanion(id: id, lastSyncAt: lastSyncAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
              }) => SyncMetaCompanion.insert(id: id, lastSyncAt: lastSyncAt),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaRow,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (SyncMetaRow, BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaRow>),
      SyncMetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SetsTableTableManager get sets => $$SetsTableTableManager(_db, _db.sets);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$VariantsTableTableManager get variants =>
      $$VariantsTableTableManager(_db, _db.variants);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
}
