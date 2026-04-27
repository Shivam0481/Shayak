// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SHAYAK';

  @override
  String hello(String name) {
    return 'Hello, $name 👋';
  }

  @override
  String get whatDoYouNeedHelpWith => 'What do you need help with?';

  @override
  String get oneTapSos => 'ONE TAP SOS';

  @override
  String get emergencyRescueAlert => 'Emergency rescue alert';

  @override
  String get nearbyRequests => 'Nearby Requests';

  @override
  String get seeAll => 'See All';

  @override
  String get noActiveRequests => 'No active requests nearby';

  @override
  String get areaSafe => 'Your area is safe right now.';

  @override
  String get newRequest => 'New Request';

  @override
  String get tapToOpenMap => 'Tap to open Live Map';

  @override
  String get markersDescription => 'Red • Yellow • Green markers';

  @override
  String get available => 'Available';

  @override
  String get offline => 'Offline';

  @override
  String get food => 'Food';

  @override
  String get blood => 'Blood';

  @override
  String get medicine => 'Medicine';

  @override
  String get rescue => 'Rescue';

  @override
  String get mentalHealth => 'Mental Health';

  @override
  String get transport => 'Transport';

  @override
  String get labour => 'Labour';

  @override
  String get other => 'Other';

  @override
  String get respond => 'Respond';

  @override
  String get cancel => 'Cancel';

  @override
  String get requestDetails => 'Request Details';
}
