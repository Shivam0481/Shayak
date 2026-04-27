// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'शायक';

  @override
  String hello(String name) {
    return 'नमस्ते, $name 👋';
  }

  @override
  String get whatDoYouNeedHelpWith => 'आपको किस मदद की जरूरत है?';

  @override
  String get oneTapSos => 'वन टैप एसओएस';

  @override
  String get emergencyRescueAlert => 'आपातकालीन बचाव अलर्ट';

  @override
  String get nearbyRequests => 'आस-पास के अनुरोध';

  @override
  String get seeAll => 'सभी देखें';

  @override
  String get noActiveRequests => 'आस-पास कोई सक्रिय अनुरोध नहीं';

  @override
  String get areaSafe => 'आपका क्षेत्र अभी सुरक्षित है।';

  @override
  String get newRequest => 'नया अनुरोध';

  @override
  String get tapToOpenMap => 'लाइव मैप खोलने के लिए टैप करें';

  @override
  String get markersDescription => 'लाल • पीला • हरा मार्कर';

  @override
  String get available => 'उपलब्ध';

  @override
  String get offline => 'ऑफ़लाइन';

  @override
  String get food => 'खाना';

  @override
  String get blood => 'खून';

  @override
  String get medicine => 'दवा';

  @override
  String get rescue => 'बचाव';

  @override
  String get mentalHealth => 'मानसिक स्वास्थ्य';

  @override
  String get transport => 'यातायात';

  @override
  String get labour => 'मजदूर';

  @override
  String get other => 'अन्य';

  @override
  String get respond => 'जवाब दें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get requestDetails => 'अनुरोध विवरण';
}
