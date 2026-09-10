import 'app_language.dart';

class AppTranslations {
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // Language
      'language.choose': 'Choose your language',
      'language.description':
          'Select the language you prefer to use\nthroughout the application.',
      'language.english': 'English',
      'language.hindi': 'Hindi',
      'language.continue': 'Continue',

      // Common
      'common.continue': 'Continue',
      'common.cancel': 'Cancel',
      'common.save': 'Save',
      'common.delete': 'Delete',
      'common.edit': 'Edit',
      'common.close': 'Close',
      'common.retry': 'Retry',
      'common.loading': 'Loading...',
      'common.yes': 'Yes',
      'common.no': 'No',
      'common.done': 'Done',
      'common.submit': 'Submit',
      'common.search': 'Search',
      'common.noData': 'No data available',

      // Auth
      'auth.login': 'Login',
      'auth.logout': 'Logout',
      'auth.mobileNumber': 'Mobile number',
      'auth.enterMobileNumber': 'Enter your mobile number',
      'auth.password': 'Password',
      'auth.enterPassword': 'Enter your password',
      'auth.loginToContinue': 'Login to continue',

      // Dashboard
      'dashboard.dashboard': 'Dashboard',
      'dashboard.home': 'Home',
      'dashboard.attendance': 'Attendance',
      'dashboard.tasks': 'Task',
      'dashboard.chat': 'Chat',
      'dashboard.profile': 'Profile',

      // Attendance
      'attendance.attendance': 'Attendance',
      'attendance.checkIn': 'Check In',
      'attendance.checkOut': 'Check Out',
      'attendance.startBreak': 'Start Break',
      'attendance.endBreak': 'End Break',
      'attendance.breakStarted': 'Break started',
      'attendance.breakEnded': 'Break ended',
      'attendance.today': 'Today',
      'attendance.schedule': 'Schedule',
      'attendance.timeline': 'Timeline',
      'attendance.breaks': 'Breaks',
      'attendance.workingHours': 'Working Hours',
      'attendance.checkInTime': 'Check-in Time',
      'attendance.checkOutTime': 'Check-out Time',

      // Tasks
      'tasks.tasks': 'Tasks',
      'tasks.task': 'Task',
      'tasks.myTasks': 'My Tasks',
      'tasks.pending': 'Pending',
      'tasks.completed': 'Completed',
      'tasks.noTasks': 'No tasks available',

      // Chat
      'chat.chat': 'Chat',
      'chat.messages': 'Messages',
      'chat.typeMessage': 'Type a message...',
      'chat.sayHello': 'Say hello',
      'chat.noMessages':
          'No messages here yet — send the first one.',
      'chat.deleteMessage': 'Delete message',
      'chat.deleteMessageDescription':
          'This message will disappear for everyone in this chat. This cannot be undone.',
      'chat.cancel': 'Cancel',
      'chat.delete': 'Delete',

      // Profile
      'profile.profile': 'Profile',
      'profile.personalInformation': 'Personal Information',
      'profile.editProfile': 'Edit Profile',
      'profile.settings': 'Settings',
      'profile.language': 'Language',
      'profile.changeLanguage': 'Change Language',
      'profile.logout': 'Logout',

      // Onboarding
      'onboarding.completeProfile': 'Complete Profile',
      'onboarding.firstName': 'First Name',
      'onboarding.lastName': 'Last Name',
      'onboarding.email': 'Email',
      'onboarding.selectLanguage': 'Select Language',
    },

    'hi': {
      // Language
      'language.choose': 'अपनी भाषा चुनें',
      'language.description':
          'एप्लिकेशन में उपयोग करने के लिए\nअपनी पसंदीदा भाषा चुनें।',
      'language.english': 'English',
      'language.hindi': 'हिन्दी',
      'language.continue': 'जारी रखें',

      // Common
      'common.continue': 'जारी रखें',
      'common.cancel': 'रद्द करें',
      'common.save': 'सहेजें',
      'common.delete': 'हटाएं',
      'common.edit': 'संपादित करें',
      'common.close': 'बंद करें',
      'common.retry': 'पुनः प्रयास करें',
      'common.loading': 'लोड हो रहा है...',
      'common.yes': 'हाँ',
      'common.no': 'नहीं',
      'common.done': 'हो गया',
      'common.submit': 'जमा करें',
      'common.search': 'खोजें',
      'common.noData': 'कोई डेटा उपलब्ध नहीं है',

      // Auth
      'auth.login': 'लॉगिन',
      'auth.logout': 'लॉगआउट',
      'auth.mobileNumber': 'मोबाइल नंबर',
      'auth.enterMobileNumber': 'अपना मोबाइल नंबर दर्ज करें',
      'auth.password': 'पासवर्ड',
      'auth.enterPassword': 'अपना पासवर्ड दर्ज करें',
      'auth.loginToContinue': 'जारी रखने के लिए लॉगिन करें',

      // Dashboard
      'dashboard.dashboard': 'डैशबोर्ड',
      'dashboard.home': 'होम',
      'dashboard.attendance': 'उपस्थिति',
      'dashboard.tasks': 'कार्य',
      'dashboard.chat': 'चैट',
      'dashboard.profile': 'प्रोफ़ाइल',

      // Attendance
      'attendance.attendance': 'उपस्थिति',
      'attendance.checkIn': 'चेक इन',
      'attendance.checkOut': 'चेक आउट',
      'attendance.startBreak': 'ब्रेक शुरू करें',
      'attendance.endBreak': 'ब्रेक समाप्त करें',
      'attendance.breakStarted': 'ब्रेक शुरू हो गया',
      'attendance.breakEnded': 'ब्रेक समाप्त हो गया',
      'attendance.today': 'आज',
      'attendance.schedule': 'शेड्यूल',
      'attendance.timeline': 'टाइमलाइन',
      'attendance.breaks': 'ब्रेक',
      'attendance.workingHours': 'काम के घंटे',
      'attendance.checkInTime': 'चेक-इन समय',
      'attendance.checkOutTime': 'चेक-आउट समय',

      // Tasks
      'tasks.tasks': 'कार्य',
      'tasks.task': 'कार्य',
      'tasks.myTasks': 'मेरे कार्य',
      'tasks.pending': 'लंबित',
      'tasks.completed': 'पूर्ण',
      'tasks.noTasks': 'कोई कार्य उपलब्ध नहीं है',

      // Chat
      'chat.chat': 'चैट',
      'chat.messages': 'संदेश',
      'chat.typeMessage': 'संदेश लिखें...',
      'chat.sayHello': 'नमस्ते कहें',
      'chat.noMessages':
          'अभी तक कोई संदेश नहीं है — पहला संदेश भेजें।',
      'chat.deleteMessage': 'संदेश हटाएं',
      'chat.deleteMessageDescription':
          'यह संदेश इस चैट में सभी के लिए गायब हो जाएगा। इसे पूर्ववत नहीं किया जा सकता।',
      'chat.cancel': 'रद्द करें',
      'chat.delete': 'हटाएं',

      // Profile
      'profile.profile': 'प्रोफ़ाइल',
      'profile.personalInformation': 'व्यक्तिगत जानकारी',
      'profile.editProfile': 'प्रोफ़ाइल संपादित करें',
      'profile.settings': 'सेटिंग्स',
      'profile.language': 'भाषा',
      'profile.changeLanguage': 'भाषा बदलें',
      'profile.logout': 'लॉगआउट',

      // Onboarding
      'onboarding.completeProfile': 'प्रोफ़ाइल पूरी करें',
      'onboarding.firstName': 'पहला नाम',
      'onboarding.lastName': 'अंतिम नाम',
      'onboarding.email': 'ईमेल',
      'onboarding.selectLanguage': 'भाषा चुनें',
    },
  };

  static String translate(
    String key, {
    AppLanguage language = AppLanguage.english,
  }) {
    final languageTranslations = _translations[language.code];

    return languageTranslations?[key] ??
        _translations[AppLanguage.english.code]?[key] ??
        key;
  }
}