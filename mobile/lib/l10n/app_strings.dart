import 'package:flutter/widgets.dart';

class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('zh'),
    Locale('ko'),
  ];

  static AppStrings of(BuildContext context) {
    final strings = Localizations.of<AppStrings>(context, AppStrings);
    return strings ?? AppStrings(const Locale('en'));
  }

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  String text(String key) {
    final lang = _strings[locale.languageCode] ?? _strings['en']!;
    return lang[key] ?? _strings['en']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'app_title': 'Family App',
      'welcome_home': 'Welcome Home',
      'welcome_subtitle': 'Build warm moments with your family every day.',
      'display_name': 'Display Name',
      'mock_wechat_code': 'Mock WeChat Code',
      'enter_family_app': 'Enter Family App',
      'signing_in': 'Signing in...',
      'family_home': 'Family Home',
      'invite_code': 'Invite Code',
      'overview': 'Overview',
      'questions': 'Questions',
      'photos': 'Photos',
      'birthdays': 'Birthdays',
      'care': 'Care',
      'language': 'Language',
      'system_default': 'System',
      'search_questions': 'Search questions',
      'search_photos': 'Search photos',
      'newest_first': 'Newest first',
      'oldest_first': 'Oldest first',
      'add_question': 'Add Question',
      'question_date': 'Question Date (YYYY-MM-DD)',
      'question_text': 'Question Text',
      'no_questions': 'No questions yet',
      'answer': 'Answer',
      'view_answers': 'View Answers',
      'answers': 'Answers',
      'no_answers': 'No answers yet.',
      'upload_photo': 'Upload Photo',
      'pick_image': 'Pick Image From Gallery',
      'change_image': 'Change Picked Image',
      'caption': 'Caption',
      'no_photos': 'No photos yet',
      'like': 'Like',
      'unlike': 'Unlike',
      'comment': 'Comment',
      'view': 'View',
      'edit': 'Edit',
      'delete': 'Delete',
      'birthday': 'Birthday (YYYY-MM-DD)',
      'notify_days_before': 'Notify Days Before',
      'add_birthday_reminder': 'Add Birthday Reminder',
      'no_reminders': 'No reminders yet',
      'recent_activity': 'Recent Activity',
      'latest_questions': 'Latest Questions',
      'latest_photos': 'Latest Photos',
      'latest_reminders': 'Latest Reminders',
      'no_activity': 'No activity yet',
      'family_overview_quote': 'Home is where love grows stronger each day.',
    },
    'zh': {
      'app_title': '家庭应用',
      'welcome_home': '欢迎回家',
      'welcome_subtitle': '每天和家人一起创造温暖时刻。',
      'display_name': '昵称',
      'mock_wechat_code': '模拟微信 Code',
      'enter_family_app': '进入家庭应用',
      'signing_in': '登录中...',
      'family_home': '家庭主页',
      'invite_code': '邀请码',
      'overview': '总览',
      'questions': '每日问题',
      'photos': '相册',
      'birthdays': '生日提醒',
      'care': '关怀',
      'language': '语言',
      'system_default': '跟随系统',
      'search_questions': '搜索问题',
      'search_photos': '搜索照片',
      'newest_first': '最新优先',
      'oldest_first': '最早优先',
      'add_question': '发布问题',
      'question_date': '问题日期 (YYYY-MM-DD)',
      'question_text': '问题内容',
      'no_questions': '还没有问题',
      'answer': '回答',
      'view_answers': '查看回答',
      'answers': '回答列表',
      'no_answers': '还没有回答。',
      'upload_photo': '上传照片',
      'pick_image': '从相册选择',
      'change_image': '更换已选图片',
      'caption': '描述',
      'no_photos': '还没有照片',
      'like': '点赞',
      'unlike': '取消点赞',
      'comment': '评论',
      'view': '查看',
      'edit': '编辑',
      'delete': '删除',
      'birthday': '生日 (YYYY-MM-DD)',
      'notify_days_before': '提前提醒天数',
      'add_birthday_reminder': '新增生日提醒',
      'no_reminders': '还没有提醒',
      'recent_activity': '最近动态',
      'latest_questions': '最新问题',
      'latest_photos': '最新照片',
      'latest_reminders': '最新提醒',
      'no_activity': '暂时没有动态',
      'family_overview_quote': '家，是爱每天都在生长的地方。',
    },
    'ko': {
      'app_title': '가족 앱',
      'welcome_home': '환영합니다',
      'welcome_subtitle': '가족과 함께 따뜻한 순간을 매일 쌓아가요.',
      'display_name': '이름',
      'mock_wechat_code': '모의 WeChat 코드',
      'enter_family_app': '가족 앱 시작',
      'signing_in': '로그인 중...',
      'family_home': '가족 홈',
      'invite_code': '초대 코드',
      'overview': '개요',
      'questions': '질문',
      'photos': '사진',
      'birthdays': '생일',
      'care': '케어',
      'language': '언어',
      'system_default': '시스템',
      'search_questions': '질문 검색',
      'search_photos': '사진 검색',
      'newest_first': '최신순',
      'oldest_first': '오래된순',
      'add_question': '질문 추가',
      'question_date': '질문 날짜 (YYYY-MM-DD)',
      'question_text': '질문 내용',
      'no_questions': '질문이 없습니다',
      'answer': '답변',
      'view_answers': '답변 보기',
      'answers': '답변 목록',
      'no_answers': '아직 답변이 없습니다.',
      'upload_photo': '사진 업로드',
      'pick_image': '갤러리에서 선택',
      'change_image': '선택 이미지 변경',
      'caption': '설명',
      'no_photos': '사진이 없습니다',
      'like': '좋아요',
      'unlike': '좋아요 취소',
      'comment': '댓글',
      'view': '보기',
      'edit': '수정',
      'delete': '삭제',
      'birthday': '생일 (YYYY-MM-DD)',
      'notify_days_before': '미리 알림 일수',
      'add_birthday_reminder': '생일 알림 추가',
      'no_reminders': '알림이 없습니다',
      'recent_activity': '최근 활동',
      'latest_questions': '최근 질문',
      'latest_photos': '최근 사진',
      'latest_reminders': '최근 알림',
      'no_activity': '활동이 없습니다',
      'family_overview_quote': '집은 사랑이 매일 자라는 곳입니다.',
    },
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh', 'ko'].contains(locale.languageCode);
  }

  @override
  Future<AppStrings> load(Locale locale) async {
    return AppStrings(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
