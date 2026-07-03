/// User's birth information — the single input to the whole calculation chain.
enum CalendarType { solar, lunar }

enum Gender { male, female }

class BirthInput {
  final CalendarType calendarType;
  final int year;
  final int month;
  final int day;
  final bool isLeapMonth; // lunar only (闰月)
  final int hour; // 0-23
  final int minute; // 0-59
  final Gender gender;
  final String location;
  final double longitude; // degrees east, for true solar time

  const BirthInput({
    required this.calendarType,
    required this.year,
    required this.month,
    required this.day,
    this.isLeapMonth = false,
    required this.hour,
    required this.minute,
    required this.gender,
    required this.location,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'calendarType': calendarType.name,
        'year': year,
        'month': month,
        'day': day,
        'isLeapMonth': isLeapMonth,
        'hour': hour,
        'minute': minute,
        'gender': gender.name,
        'location': location,
        'longitude': longitude,
      };

  factory BirthInput.fromJson(Map<String, dynamic> json) => BirthInput(
        calendarType: CalendarType.values.byName(json['calendarType'] as String),
        year: json['year'] as int,
        month: json['month'] as int,
        day: json['day'] as int,
        isLeapMonth: json['isLeapMonth'] as bool? ?? false,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        gender: Gender.values.byName(json['gender'] as String),
        location: json['location'] as String,
        longitude: (json['longitude'] as num).toDouble(),
      );
}

/// Preset cities with longitudes for true solar time.
class CityPreset {
  final String name;
  final double longitude;
  const CityPreset(this.name, this.longitude);
}

const List<CityPreset> kCityPresets = [
  CityPreset('北京', 116.41),
  CityPreset('上海', 121.47),
  CityPreset('广州', 113.26),
  CityPreset('深圳', 114.06),
  CityPreset('成都', 104.07),
  CityPreset('重庆', 106.55),
  CityPreset('武汉', 114.31),
  CityPreset('西安', 108.94),
  CityPreset('杭州', 120.16),
  CityPreset('南京', 118.80),
  CityPreset('沈阳', 123.43),
  CityPreset('哈尔滨', 126.53),
  CityPreset('昆明', 102.71),
  CityPreset('兰州', 103.83),
  CityPreset('乌鲁木齐', 87.62),
  CityPreset('台北', 121.56),
  CityPreset('香港', 114.17),
  CityPreset('澳门', 113.55),
  CityPreset('新加坡', 103.82),
  CityPreset('吉隆坡', 101.69),
];
