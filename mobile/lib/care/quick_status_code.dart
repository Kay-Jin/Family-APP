/// One-tap status codes stored in `family_status_posts.status_code`.
abstract final class QuickStatusCode {
  static const home = 'home';
  static const onWay = 'on_way';
  static const tired = 'tired';
  static const needChat = 'need_chat';

  static const all = [home, onWay, tired, needChat];

  static String l10nKeyFor(String code) {
    switch (code) {
      case home:
        return 'quick_status_home';
      case onWay:
        return 'quick_status_on_way';
      case tired:
        return 'quick_status_tired';
      case needChat:
        return 'quick_status_need_chat';
      default:
        return 'status';
    }
  }

  static bool isValid(String code) => all.contains(code);
}
