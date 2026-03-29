/// 家庭一键登录（邮箱 + 密码）。
///
/// Supabase 的邮箱登录必须是合法邮箱格式，因此将您提供的「ID」映射为
/// `{id}@member.family`。请在 Supabase 控制台 **Authentication → Users**
/// 中创建相同邮箱的用户（或关闭邮箱确认后由家人首次点「注册」创建）。
///
/// **安全**：密码写在源码中仅适合私人仓库；若将代码公开，请删除本文件或改用
/// `--dart-define` / 后台邀请制账号。
abstract final class FamilyQuickLogin {
  /// 与 [babaId] / [mamaId] 拼接成完整邮箱。
  static const String emailDomain = 'member.family';

  static String emailForId(String id) => '${id.trim()}@$emailDomain';

  static const String babaId = 'jinshanglong';
  static const String mamaId = 'peimeiling';
  static const String sharedPassword = 'meiling1314521';

  static String get babaEmail => emailForId(babaId);
  static String get mamaEmail => emailForId(mamaId);
}
