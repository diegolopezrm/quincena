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
  String get problemLimit =>
      'That was all of today\'s questions. You can keep asking tomorrow.';

  @override
  String get askTitle => 'Ask your money';

  @override
  String get askYourMoneyLabel => 'Ask your money';

  @override
  String get ownAskFree => 'How much is free until payday?';

  @override
  String get ownAskMonth => 'Where did my money go this month?';

  @override
  String get ownAskAll => 'How much do I have in all, with dollars and crypto?';

  @override
  String get ownAskCompare => 'How am I doing against last month?';

  @override
  String get ownAskRecord => 'I want to record an expense';

  @override
  String get askOther => 'Something else';

  @override
  String askLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions left today',
      one: 'One question left today',
      zero: 'No questions left today',
    );
    return '$_temp0';
  }

  @override
  String get askWhatSees => 'What Gemini sees';

  @override
  String get geminiNoteHow =>
      'When you ask your money something, the question goes to Gemini, Google\'s model, through Quincena\'s Firebase project. You need no key and no account: Quincena knows you by an anonymous user, only to count your questions.';

  @override
  String get geminiNoteSends =>
      'Gemini does not get your database. It asks tools that run on your phone or computer for the figures it needs, and what travels is their answers: your totals by category and by month, what is free until payday, your subscriptions, your savings goal, your accounts with their balances and, when the question calls for it, a month\'s largest payments with their merchants.';

  @override
  String get geminiNoteNot =>
      'Your other movements one by one do not travel, nor your notes, nor your bank\'s alerts, nor your location.';

  @override
  String get geminiNoteTerms =>
      'Quincena uses Gemini on Google Cloud\'s Agent Platform, as a paying customer: Google does not train its models on what is sent or keep it in a cache, and only holds on to a question its filters flag as abuse. Even so, do not write in a question anything you would not share, such as an account number.';

  @override
  String geminiNoteLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Each person has $count questions a day.',
      one: 'Each person has one question a day.',
    );
    return '$_temp0 Firebase App Check makes sure they come from the Quincena app and not from another program.';
  }

  @override
  String get whoAnswers => 'Who answers';

  @override
  String get modeDemo => 'Demo';

  @override
  String get modeLive => 'Live Gemini';

  @override
  String get modeGemini => 'Gemini';

  @override
  String get modeOwnKey => 'Your key';

  @override
  String geminiExplain(String model) {
    return '$model answers through Quincena, with no key. Ask anything about the account.';
  }

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
    return '$model · $steps steps';
  }

  @override
  String recordedSeconds(double seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String secondsString = secondsNumberFormat.format(seconds);

    return '$secondsString s';
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

  @override
  String get startTitle => 'How do you want to start?';

  @override
  String get startOwnTitle => 'With my accounts';

  @override
  String get startOwnBody =>
      'Add your accounts in pesos, dollars or crypto and record what comes in and what goes out.';

  @override
  String get startDemoTitle => 'With sample data';

  @override
  String get startDemoBody =>
      'See how it works with Valentina\'s account, a designer in Medellín. You can switch to your own accounts any time.';

  @override
  String get privacyNote =>
      'Your accounts and movements are stored only on this device.';

  @override
  String onboardingStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get onboardingNameTitle => 'What\'s your name?';

  @override
  String get onboardingNameHint => 'Your name';

  @override
  String get onboardingBaseTitle => 'Which currency should your totals be in?';

  @override
  String get onboardingBaseBody =>
      'Each account keeps its own currency; totals are converted to this one.';

  @override
  String get onboardingPayTitle => 'How do you get paid?';

  @override
  String get onboardingPayBody =>
      'Quincena uses this to work out what is free until your next payday.';

  @override
  String get onboardingAccountsTitle => 'Add your accounts';

  @override
  String get onboardingAccountsBody =>
      'Banks, wallets, cash, cards or crypto. You can add more later.';

  @override
  String get onboardingSuggestions => 'To start quickly';

  @override
  String get onboardingNeedAccount => 'Add at least one account to start.';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get finish => 'Start';

  @override
  String get payTwiceMonthly => 'Twice a month';

  @override
  String payTwiceMonthlyDetail(int first, int second) {
    return 'Days $first and $second of each month';
  }

  @override
  String get payMonthly => 'Monthly';

  @override
  String payMonthlyDetail(int day) {
    return 'Day $day of each month';
  }

  @override
  String get payBiweekly => 'Every two weeks';

  @override
  String payBiweeklyDetail(String date) {
    return 'Every 14 days, counting from $date';
  }

  @override
  String get payWeekly => 'Weekly';

  @override
  String payWeeklyDetail(String weekday) {
    return 'Every $weekday';
  }

  @override
  String get payFirstDay => 'First payday';

  @override
  String get paySecondDay => 'Second payday';

  @override
  String get payDay => 'Payday';

  @override
  String get payLastPayday => 'Your last payday';

  @override
  String get payWeekday => 'Day of the week';

  @override
  String payDayOption(int day) {
    return 'Day $day';
  }

  @override
  String get tabHome => 'Home';

  @override
  String get tabMovements => 'Movements';

  @override
  String get tabAccounts => 'Accounts';

  @override
  String get addAccount => 'Add account';

  @override
  String get editAccount => 'Edit account';

  @override
  String get accountName => 'Name';

  @override
  String get accountNameHint => 'For example, Checking account';

  @override
  String get accountKind => 'Type';

  @override
  String get kindBank => 'Bank';

  @override
  String get kindCard => 'Credit card';

  @override
  String get kindCash => 'Cash';

  @override
  String get kindWallet => 'Digital wallet';

  @override
  String get kindExchange => 'Crypto exchange';

  @override
  String get kindInvestment => 'Savings or investment';

  @override
  String get kindOther => 'Other';

  @override
  String get accountAsset => 'Currency';

  @override
  String get assetFiat => 'Currencies';

  @override
  String get assetCrypto => 'Crypto';

  @override
  String get assetOther => 'Other crypto';

  @override
  String get assetOtherHint => 'Ticker, for example ADA';

  @override
  String get accountInstitution => 'Institution (optional)';

  @override
  String get accountBalanceNow => 'How much is in it today?';

  @override
  String get accountDebtNow => 'How much do you owe today?';

  @override
  String get accountSpendable => 'Money to spend';

  @override
  String get accountSpendableHelp =>
      'Its balance counts toward what is free until payday. Turn it off for savings, investments and crypto.';

  @override
  String get accountAssetLocked =>
      'The currency can\'t change: the account\'s movements are in it.';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String deleteAccountTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String deleteAccountBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count movements are deleted too. This can\'t be undone.',
      one: 'Its movement is deleted too. This can\'t be undone.',
      zero: 'It has no movements.',
    );
    return '$_temp0';
  }

  @override
  String get groupSpendable => 'To spend';

  @override
  String get groupSaved => 'Savings, investments and crypto';

  @override
  String get netWorth => 'Everything you have';

  @override
  String get noAccounts => 'No accounts yet.';

  @override
  String get yourAccounts => 'Your accounts';

  @override
  String get accountMovements => 'Account movements';

  @override
  String get balanceToday => 'Balance today';

  @override
  String get ratesTitle => 'Rates';

  @override
  String ratesUpdated(String when) {
    return 'Updated $when';
  }

  @override
  String get ratesNever => 'No rates yet: they are fetched when online.';

  @override
  String get ratesRefresh => 'Refresh rates';

  @override
  String get ratesFailed => 'Couldn\'t update them. Using the last saved ones.';

  @override
  String ratesMissing(String assets) {
    return 'No rate for $assets: it counts as zero in totals.';
  }

  @override
  String get rateManual => 'Typed by hand';

  @override
  String get rateSourceTrm => 'Official TRM';

  @override
  String get rateSourceBinance => 'Binance';

  @override
  String get rateSourceEcb => 'European Central Bank';

  @override
  String get rateEdit => 'Type a rate';

  @override
  String rateEditBody(String asset, String quote) {
    return 'What 1 $asset is worth in $quote. A rate typed by hand is not replaced when refreshing.';
  }

  @override
  String get rateUseFetched => 'Back to the automatic rate';

  @override
  String stablecoinPeg(String asset) {
    return '$asset counts as one dollar.';
  }

  @override
  String get addMovement => 'Add movement';

  @override
  String get editMovement => 'Edit movement';

  @override
  String get kindExpense => 'Expense';

  @override
  String get kindIncome => 'Income';

  @override
  String get kindTransfer => 'Transfer';

  @override
  String get amount => 'Amount';

  @override
  String get account => 'Account';

  @override
  String get fromAccount => 'From';

  @override
  String get toAccount => 'To';

  @override
  String get received => 'Received';

  @override
  String get receivedHelp =>
      'What arrived in the other account, in its currency.';

  @override
  String get category => 'Category';

  @override
  String get newCategory => 'New category';

  @override
  String get payee => 'Where or to whom?';

  @override
  String get payeeIncome => 'From where?';

  @override
  String get date => 'Date';

  @override
  String get note => 'Note (optional)';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get searchMovements => 'Search movements';

  @override
  String get noMovements => 'No movements yet.';

  @override
  String get noMovementsBody =>
      'Record an expense, an income or a transfer with the + button.';

  @override
  String get noResults => 'Nothing matches the search.';

  @override
  String get deleteMovementTitle => 'Delete this movement?';

  @override
  String get deleteTransferBody => 'Both sides of the transfer are deleted.';

  @override
  String get invalidAmount => 'Enter an amount';

  @override
  String get sameAccount => 'Pick two different accounts';

  @override
  String get needAccountFirst => 'Add an account first.';

  @override
  String get recentMovements => 'Recent movements';

  @override
  String get seeAll => 'See all';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get settingsProfile => 'Profile';

  @override
  String get settingsName => 'Name';

  @override
  String get settingsBase => 'Currency for totals';

  @override
  String get settingsPay => 'How you get paid';

  @override
  String get settingsData => 'Your data';

  @override
  String get exportData => 'Export my data';

  @override
  String get exportDone => 'File saved.';

  @override
  String get importData => 'Import a file';

  @override
  String get importConfirmTitle => 'Replace everything with this file?';

  @override
  String get importConfirmBody =>
      'What is in Quincena now is deleted and replaced by the file.';

  @override
  String get importConfirm => 'Replace';

  @override
  String get importDone => 'Data imported.';

  @override
  String importFailed(String reason) {
    return 'That file couldn\'t be read: $reason';
  }

  @override
  String get deleteAll => 'Delete everything';

  @override
  String get deleteAllTitle => 'Delete all your data?';

  @override
  String get deleteAllBody =>
      'Accounts, movements and settings are deleted from this device. This can\'t be undone; export first if you want to keep them.';

  @override
  String get useDemo => 'See the sample data';

  @override
  String get useOwn => 'Use with my accounts';

  @override
  String get backToOwn => 'Back to my accounts';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyBody =>
      'Your accounts and movements are stored only on this device. For rates, Quincena looks up public sources (the TRM, Binance and the European Central Bank) without sending anything of yours.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String standingDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days until payday.',
      one: 'One day until payday.',
      zero: 'Today is payday.',
    );
    return '$_temp0';
  }

  @override
  String standingCommittedOwn(String committed) {
    return '$committed is already committed to scheduled payments.';
  }

  @override
  String get inboxTitle => 'To review';

  @override
  String inboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movements to review',
      one: 'One movement to review',
    );
    return '$_temp0';
  }

  @override
  String get inboxBannerBody =>
      'They came from your notifications and messages.';

  @override
  String get inboxEmpty => 'Nothing to review.';

  @override
  String get inboxEmptyBody =>
      'When a payment arrives from your bank, it shows up here to confirm.';

  @override
  String get confirm => 'Confirm';

  @override
  String get edit => 'Edit';

  @override
  String get dismiss => 'Dismiss';

  @override
  String dismissAndMute(String app) {
    return 'Dismiss and stop reading $app';
  }

  @override
  String get chooseAccount => 'Choose the account';

  @override
  String get noMerchant => 'No merchant';

  @override
  String get sourceWallet => 'Apple Pay';

  @override
  String get sourceNotification => 'Notification';

  @override
  String get sourceSms => 'SMS';

  @override
  String get sourceEmail => 'Email';

  @override
  String get sourceScreenshot => 'Screenshot';

  @override
  String get sourcePaste => 'Pasted';

  @override
  String nearbyPlace(String name, int metres) {
    return 'Nearby: $name, $metres m away';
  }

  @override
  String get possibleDuplicates => 'Possible repeats';

  @override
  String get duplicateLine => 'The same payment already arrived another way.';

  @override
  String get notDuplicate => 'Not a repeat';

  @override
  String get recordedAutomatically => 'Recorded automatically';

  @override
  String get undo => 'Undo';

  @override
  String get pasteMessage => 'Paste a message';

  @override
  String get pasteHint =>
      'Paste the message or notification from your bank here';

  @override
  String get pasteRead => 'Read';

  @override
  String get pasteAdded => 'It is in To review.';

  @override
  String get pasteRecorded => 'It was recorded.';

  @override
  String get pasteNothing => 'I could not find a payment in that text.';

  @override
  String get pasteDuplicate => 'That payment was already there.';

  @override
  String get readScreenshot => 'Read a screenshot';

  @override
  String get pickImages => 'Screenshots or photos';

  @override
  String get pickPdf => 'A PDF';

  @override
  String get readingImages => 'Reading…';

  @override
  String readFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count payments. They are in To review.',
      one: 'Found a payment. It is in To review.',
    );
    return '$_temp0';
  }

  @override
  String get readNothing =>
      'No amount with its currency was found. Try a screenshot where the amount shows.';

  @override
  String get showOriginal => 'See the message';

  @override
  String get captureTitle => 'Automatic capture';

  @override
  String get captureSubtitle =>
      'Payments that arrive by themselves from your notifications and messages';

  @override
  String get captureAuto => 'Record what is clear on its own';

  @override
  String get captureAutoHelp =>
      'When the account, the category and the amount are certain and it is not a repeat, it is recorded without asking. The rest waits in To review.';

  @override
  String get captureLocation => 'Use where the payment happened';

  @override
  String get captureLocationHelp =>
      'When the alert does not say where, Quincena looks up the shops a few metres from where the phone was. The location stays here; only the coordinates go to OpenStreetMap, through Photon, to find the shops.';

  @override
  String get captureLocationDenied =>
      'Quincena can\'t use the location. You can allow it in the phone\'s settings.';

  @override
  String get openPhoneSettings => 'Open settings';

  @override
  String get captureAlwaysTitle => 'Location while Quincena is closed';

  @override
  String get captureAlwaysBody =>
      'Payments almost always arrive while Quincena is closed. To know where you were at that moment, Android asks you to choose \"Allow all the time\". Quincena only looks at the location when a payment notification arrives.';

  @override
  String get captureLocationOnlyOpen =>
      'For now only while the app is open. Choose \"Allow all the time\" for payments that arrive while it\'s closed.';

  @override
  String get captureAllowAlways => 'Allow all the time';

  @override
  String get notNow => 'Not now';

  @override
  String get continueLabel => 'Continue';

  @override
  String get captureImagesTitle => 'Screenshots and receipts';

  @override
  String get captureImagesIos =>
      'In To review you can pick a screenshot, a photo or a PDF of a payment, and Quincena reads it on the phone.\nTo send them from other apps, make a shortcut with Quincena\'s \"Read a receipt\" action and turn on \"Show in Share Sheet\".\nWith \"Take Screenshot\" before it and Back Tap (Settings, Accessibility, Touch), double-tap the back of the iPhone to read what is on the screen.';

  @override
  String get captureImagesAndroid =>
      'Share a screenshot, a photo, a PDF or a text with Quincena from any app, or pick them in To review. They are read on the phone and wait for you to confirm them.';

  @override
  String get captureImagesDesktop =>
      'Pick a screenshot, a photo or a PDF of a payment in To review, and Quincena reads it on this computer.';

  @override
  String get captureIosTitle => 'On iPhone, with Shortcuts';

  @override
  String get captureIosSteps =>
      '1. Open Shortcuts and go to Automation.\n2. Create a new one with Wallet and pick your cards.\n3. If you want to use the location, add \"Get Current Location\". Then add Quincena\'s \"Record a movement\" action, choose Apple Pay as the source and give it the amount, the merchant and the card.\n4. Choose \"Run Immediately\".\nFor your bank\'s text messages, create a Message automation for the bank\'s sender, use the same action with Message as the source and give it the message as text. From iOS 27, the Notification automation does the same with your banks\' apps.';

  @override
  String get captureOpenShortcuts => 'Open Shortcuts';

  @override
  String get captureIosReady =>
      'Add the ones you want. They arrive switched off: in Shortcuts, open each one, tap Edit, expand the first block and turn on Automation.';

  @override
  String get captureIos26Steps =>
      '1. Add the shortcut for what you want to capture.\n2. Open Shortcuts and go to Automation.\n3. Create one with Wallet and pick your cards, or with Message and your bank\'s sender.\n4. Choose the Quincena shortcut you added and \"Run Immediately\".';

  @override
  String get captureAdd => 'Add';

  @override
  String get readyBankNotifications => 'Your banks\' notifications';

  @override
  String get readyBankNotificationsHelp =>
      'Bancolombia, Nequi and the rest, as they arrive. When you add it, check that your banks\' apps are in it.';

  @override
  String get readyBankMessages => 'Your bank\'s texts';

  @override
  String get readyBankMessagesHelp =>
      'Purchase and transfer texts that carry an amount with \$.';

  @override
  String get readyApplePay => 'Apple Pay payments';

  @override
  String get readyApplePayHelp => 'Every purchase you pay for with the iPhone.';

  @override
  String get readyScreenshots => 'Receipt screenshots';

  @override
  String get readyScreenshotsHelp =>
      'When a screenshot shows an amount with \$, it reads it on the phone and leaves it for review.';

  @override
  String get captureAndroidTitle => 'On Android, with your notifications';

  @override
  String get captureAndroidBody =>
      'Quincena reads the notifications that look like payments and lets the rest go by without keeping them. Verification codes are never kept.';

  @override
  String get captureAndroidGranted => 'Notification access is on';

  @override
  String get captureAndroidGrant => 'Allow notification access';

  @override
  String get captureOtherTitle => 'On this device';

  @override
  String get captureOtherBody =>
      'Automatic capture works on the phone. Here you can paste a message from your bank.';

  @override
  String get mutedApps => 'Apps not read';

  @override
  String get unmute => 'Read again';

  @override
  String learnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'It knows $count merchants.',
      one: 'It knows one merchant.',
      zero: 'It has not learned any merchants yet.',
    );
    return '$_temp0';
  }
}
