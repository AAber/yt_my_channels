import 'package:equatable/equatable.dart';

class Source extends Equatable {
  final String id;
  final String name;
  final String iconPath;
  final String baseUrl;

  const Source({
    required this.id,
    required this.name,
    required this.iconPath,
    required this.baseUrl,
  });

  @override
  List<Object?> get props => [id, name, iconPath, baseUrl];
}

// Predefined sources
class Sources {
  static const bneiDavid = Source(
    id: 'bneidavid',
    name: 'Bnei David',
    iconPath: 'assets/icon/david.png',
    baseUrl: 'https://bneidavid.org',
  );

  // Add more sources here in the future
  static const odYosefHai = Source(
    id: 'odyosefhai',
    name: 'Od Yosef Hai',
    iconPath: 'assets/icon/yosef.png',
    baseUrl: 'https://youtube.com/channel/UCQfTTiNEkZ3_HYr9S4zQB0g',
  );

  static const aviv = Source(
    id: 'aviv',
    name: 'Chabad Ramat Aviv',
    iconPath: 'assets/icon/aviv.png',
    baseUrl: 'https://www.youtube.com/channel/UCJYMW0GZaanXsFnt5pnI6QA',
  );

  static const maalot = Source(
    id: 'maalot',
    name: 'הסדר מעלות',
    iconPath: 'assets/icon/maalot.png',
    baseUrl: 'https://www.youtube.com/@yesmalot',
  );

  static const mayonaiyIsrael = Source(
    id: 'mayonaiyisroel',
    name: 'Mayonaiy Israel',
    iconPath: 'assets/icon/mi.png',
    baseUrl: 'https://www.youtube.com/@mayonaiyisroel',
  );

  static const holonYeshiva = Source(
    id: 'holonyeshiva',
    name: 'Holon Yeshiva',
    iconPath: 'assets/icon/holon.png',
    baseUrl: 'https://www.youtube.com/@HolonYeshiva',
  );

  static const mimaal = Source(
    id: 'mimaal',
    name: 'ממעל ממש',
    iconPath: 'assets/icon/mimaal.png',
    baseUrl: 'https://www.youtube.com/channel/UCkrqrlLmV0OBP9a3jMWTAcw',
  );

  static const shderot = Source(
    id: 'shderot',
    name: 'ישיבת שדרות',
    iconPath: 'assets/icon/shderot.png',
    baseUrl: 'https://www.youtube.com/channel/UC4jSWBYE-jIllmJmsZC5xRQ',
  );

  static const List<Source> all = [
    bneiDavid,
    odYosefHai,
    aviv,
    maalot,
    mayonaiyIsrael,
    holonYeshiva,
    mimaal,
    shderot,
  ];

  static Source? getById(String id) {
    try {
      return all.firstWhere((source) => source.id == id);
    } catch (e) {
      return null;
    }
  }
}
