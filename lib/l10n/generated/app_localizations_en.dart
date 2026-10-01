// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String greeting(String name) {
    return 'Hi, $name';
  }

  @override
  String freeUntil(String date) {
    return 'Free until $date';
  }

  @override
  String standingDetail(int days, String committed) {
    return '$days days to go. $committed is already set aside for rent, the loan and the fixed bills.';
  }

  @override
  String standingSemantics(String date, String free, int days, String balance) {
    return 'Free until $date: $free. $days days to go. $balance in the account.';
  }

  @override
  String get legendFree => 'Free';

  @override
  String get legendCommitted => 'Committed';

  @override
  String get inTheAccount => 'In the account';

  @override
  String get askYourMoney => 'ASK YOUR MONEY';

  @override
  String get seeRecorded => 'See what Gemini really answered';

  @override
  String get badgeDemo => 'DEMO';

  @override
  String get badgeLive => 'LIVE';

  @override
  String get newConversation => 'New conversation';

  @override
  String get settings => 'Settings';

  @override
  String get askHint => 'Ask your money anything';

  @override
  String get ask => 'Ask';

  @override
  String get thinking => 'Going through your payments';

  @override
  String get noteSavedExpense => 'You saved the expense';

  @override
  String get noteChoseMonthly => 'You chose how much to set aside';

  @override
  String get noteAskedCancel => 'You asked to cancel subscriptions';

  @override
  String get noteAskedPayments => 'You asked to see the payments';

  @override
  String get noteTappedAction => 'You tapped an action';

  @override
  String get problemKey => 'The key didn\'t work. Check it in Settings.';

  @override
  String get problemBusy =>
      'The model is getting too many questions. Try again in a minute.';

  @override
  String get problemOther => 'I couldn\'t answer this time. Try again.';

  @override
  String get whoAnswers => 'Who answers';

  @override
  String get modeDemo => 'Demo';

  @override
  String get modeLive => 'Live Gemini';

  @override
  String get demoExplain =>
      'The five questions on the home screen, answered offline with the same components the model uses.';

  @override
  String liveActive(String model) {
    return '$model is answering. Ask anything about the account.';
  }

  @override
  String get liveNeedsKey =>
      'With your Gemini key you can ask anything. It stays in this tab: it isn\'t saved, and it only travels to Google.';

  @override
  String get keyLabel => 'Gemini key';

  @override
  String get keyHint => 'From aistudio.google.com';

  @override
  String get connect => 'Connect';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get developerMode => 'Developer mode';

  @override
  String get developerExplain =>
      'Shows the genui_gen inspector over the conversation: the tree the agent built, the data model, what a screen reader announces and the messages.';

  @override
  String get copySession => 'Copy the session';

  @override
  String get sessionCopied =>
      'Session copied, without what you typed. Paste it into an issue and it can be replayed.';

  @override
  String get startOver => 'Start over';

  @override
  String get about =>
      'Quincena is a demo of genui and genui_gen. The account, the person and the merchants are made up.';

  @override
  String get recordedTitle => 'What Gemini answered';

  @override
  String get recordedIntro =>
      'These sessions are not the demo\'s script. Gemini got each question, asked the account through tools and composed the screen from the app\'s catalog. genui_gen recorded everything it sent, and it replays here step by step, with no network.';

  @override
  String recordedMeta(String model, int steps) {
    return '$model · $steps steps';
  }

  @override
  String get stepBefore => 'Before the answer';

  @override
  String get stepCreate => 'Creates the surface';

  @override
  String get stepComponents => 'Sends the components';

  @override
  String get stepData => 'Sends the data';

  @override
  String get stepDataChanged => 'The data changes';

  @override
  String get stepEvent => 'The app replies to the agent';

  @override
  String get stepMessage => 'Message';

  @override
  String stepOf(int position, int length) {
    return '$position of $length';
  }

  @override
  String stepSemantics(int position, int length) {
    return 'Step $position of $length';
  }

  @override
  String get setAsideMonthly => 'Set aside each month';

  @override
  String get arrivesIn => 'You get there in ';

  @override
  String beforeDeadline(String deadline) {
    return ', before $deadline.';
  }

  @override
  String afterDeadline(String deadline) {
    return ', after $deadline.';
  }

  @override
  String goalProgress(int percent) {
    return '$percent percent of the goal saved';
  }

  @override
  String goalSlider(String name) {
    return 'Monthly amount for $name';
  }

  @override
  String perMonth(String amount) {
    return '$amount a month';
  }

  @override
  String get cancelSaves => 'Cancel what you switched off and you save';

  @override
  String used(String ago) {
    return 'used $ago';
  }

  @override
  String get noUsage => 'no usage data';

  @override
  String get limit => 'Limit';

  @override
  String more(String amount) {
    return '$amount more';
  }

  @override
  String less(String amount) {
    return '$amount less';
  }

  @override
  String get reference => 'Reference';

  @override
  String inTotal(String amount) {
    return '$amount in total';
  }
}
