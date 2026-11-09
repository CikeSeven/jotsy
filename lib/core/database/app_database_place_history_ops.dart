part of 'app_database.dart';

/// 用过的地点：从日记 metadata 的 `context.location` 汇总，供发布 / 编辑
/// 面板的“用过的地点”直接选用。
///
/// 不另建表、不另存设置：地点本来就随日记保存，汇总出来的历史天然随备份、
/// 局域网同步与删除走，删掉（含进回收站）或改掉最后一篇用到它的日记，它就
/// 不在列表里。同一地点文案算一个地点，篇数与最近使用时间按全部用到它的
/// 日记算；坐标、地址组件与地址层级取最近一篇**带坐标**的日记，一篇都没有
/// 时（一直手填）才取最近一篇。
///
/// 为什么不直接取最近一篇：最近一篇可能恰好没存坐标（清空后重新手打了同一
/// 个地名、导入的日记、选用时这个地点还没有坐标），只看它就会把更早定位
/// 得到的坐标整个丢掉，选用后取不了天气；而这一篇又会成为下次的“最近”，
/// 坐标从此再也回不来。挑行用窗口函数：先按“有没有合法坐标”再按发表时间
/// 排，每个地点取第一行。合法坐标与 [DiaryPlaceUsage._fromRow] 同口径（经纬度
/// 都是数字），坏掉的 geo 不会顶掉更早的好坐标。
///
/// 口径：不含回收站；私密日记经 [_writeDiaryScopeFilter] 排除——在普通日记
/// 里写字时不该露出私密日记去过哪里，`readsFrom` 因此带上日记本两表；
/// 归档与未解封的胶囊照常算（地点是写日记的人自己去过的地方，不是胶囊
/// 封存的内容）。metadata 不是合法 JSON 的行（理论上不会有）先经
/// `json_valid` 跳过，坏一行不连累整个列表。
///
/// 输入：无；输出：按最近一次使用（日记的发表时间）新 → 旧的地点；无副作用。
mixin _AppDatabasePlaceHistoryOps
    on _$AppDatabase, _AppDatabaseDiaryScopeSql, _AppDatabaseDiaryQueries {
  /// 用过的地点，随日记写入重新推送。
  Stream<List<DiaryPlaceUsage>> watchPlaceHistory() {
    final variables = <Variable<Object>>[];
    final sql = StringBuffer('''
WITH used AS (
  SELECT
    trim(json_extract(d.metadata, '\$.context.location')) AS label,
    d.created_at AS created_at,
    json_extract(d.metadata, '\$.context.locationPrecision') AS precision,
    CASE
      WHEN json_type(d.metadata, '\$.context.geo.latitude') IN ('integer', 'real')
        AND json_type(d.metadata, '\$.context.geo.longitude') IN ('integer', 'real')
      THEN json_extract(d.metadata, '\$.context.geo')
    END AS geo
  FROM diaries d
  WHERE d.is_deleted = 0
    AND json_valid(d.metadata)
    AND json_type(d.metadata, '\$.context.location') = 'text'
    AND trim(json_extract(d.metadata, '\$.context.location')) <> ''
''');
    _writeDiaryScopeFilter(sql, variables, DiaryListScope.all);
    sql.write('''
),
ranked AS (
  SELECT
    label,
    precision,
    geo,
    COUNT(*) OVER (PARTITION BY label) AS uses,
    MAX(created_at) OVER (PARTITION BY label) AS last_used_at,
    ROW_NUMBER() OVER (
      PARTITION BY label
      ORDER BY geo IS NULL, created_at DESC
    ) AS pick
  FROM used
)
SELECT label, uses, last_used_at, precision, geo
FROM ranked
WHERE pick = 1
ORDER BY last_used_at DESC, label ASC
''');
    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(DiaryListScope.all, <TableInfo>[diaries]),
    ).watch().map(
      (rows) => List<DiaryPlaceUsage>.unmodifiable(<DiaryPlaceUsage>[
        for (final row in rows)
          DiaryPlaceUsage._fromRow(
            label: row.read<String>('label'),
            uses: row.read<int>('uses'),
            lastUsedAt: _readDateTime(row, 'last_used_at'),
            precision: row.readNullable<String>('precision'),
            geoJson: row.readNullable<String>('geo'),
          ),
      ]),
    );
  }
}

/// 一个用过的地点（[AppDatabase.watchPlaceHistory] 的一行）。
///
/// [latitude] / [longitude] / [addressComponent] 来自最近一篇用到它且带坐标
/// 的日记的 `geo`（自动定位时才有）；从没带过坐标的地点三者都为 null。
/// [precision] 是同一篇日记保存的地址层级名称（原样字符串，由界面层解析）。
@immutable
class DiaryPlaceUsage {
  const DiaryPlaceUsage({
    required this.label,
    required this.uses,
    required this.lastUsedAt,
    this.precision,
    this.latitude,
    this.longitude,
    this.addressComponent,
  });

  /// geo 只认数字坐标；结构不对时当作手填地点，不阻断列表。
  factory DiaryPlaceUsage._fromRow({
    required String label,
    required int uses,
    required DateTime lastUsedAt,
    required String? precision,
    required String? geoJson,
  }) {
    double? latitude;
    double? longitude;
    Map<String, Object?>? addressComponent;
    if (geoJson != null) {
      try {
        final geo = jsonDecode(geoJson);
        if (geo is Map) {
          final lat = geo['latitude'];
          final lng = geo['longitude'];
          if (lat is num && lng is num) {
            latitude = lat.toDouble();
            longitude = lng.toDouble();
            final components = geo['addressComponent'];
            if (components is Map) {
              addressComponent = Map<String, Object?>.unmodifiable(
                components.map(
                  (Object? key, Object? value) =>
                      MapEntry<String, Object?>('$key', value),
                ),
              );
            }
          }
        }
      } on FormatException {
        // 坏的 geo 只影响这一项的坐标。
      }
    }
    return DiaryPlaceUsage(
      label: label,
      uses: uses,
      lastUsedAt: lastUsedAt,
      precision: precision,
      latitude: latitude,
      longitude: longitude,
      addressComponent: addressComponent,
    );
  }

  /// 地点文案（已去首尾空白），也是去重的依据。
  final String label;

  /// 用到它的日记篇数。
  final int uses;

  /// 最近一篇用到它的日记的发表时间。
  final DateTime lastUsedAt;
  final String? precision;
  final double? latitude;
  final double? longitude;
  final Map<String, Object?>? addressComponent;

  /// 是否带坐标（自动定位得到的地点）。
  bool get hasCoordinates => latitude != null && longitude != null;
}
