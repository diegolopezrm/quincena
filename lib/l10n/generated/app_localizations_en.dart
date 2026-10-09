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
    return 'You can spend until $date';
  }

  @override
  String standingSemantics(String free, String date, String when) {
    return 'You can spend $free until $date; $when.';
  }

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
  String get noteChoseMonthly => 'You saved the plan';

  @override
  String get noteAskedCancel => 'You marked what you already canceled';

  @override
  String get noteAskedPayments => 'You asked to see the payments';

  @override
  String get noteTappedAction => 'You tapped an action';

  @override
  String get noteExpenseNotSaved => 'The expense wasn\'t saved';

  @override
  String get notePlanNotSaved => 'The plan wasn\'t saved';

  @override
  String get noteCancelNotMarked => 'They weren\'t marked as canceled';

  @override
  String get problemKey => 'The key didn\'t work. Check it in Settings.';

  @override
  String get problemBusy =>
      'The model is getting too many questions. Try again in a minute.';

  @override
  String get problemOffline =>
      'No internet connection. Your accounts and transactions still work; ask again once you\'re online.';

  @override
  String get problemOther => 'I couldn\'t answer this time. Try again.';

  @override
  String get problemLimit =>
      'You\'ve used today\'s questions. They\'re back tomorrow.';

  @override
  String get askAgain => 'Ask again';

  @override
  String get askTitle => 'Ask your money';

  @override
  String get askYourMoneyLabel => 'Ask your money';

  @override
  String get ownAskFree => 'How much can I spend before I get paid?';

  @override
  String get ownAskMonth => 'Where did my money go this month?';

  @override
  String get ownAskAll => 'How much do I have in all, with dollars and crypto?';

  @override
  String get ownAskCompare => 'How am I doing compared with last month?';

  @override
  String get ownAskRecord => 'I want to record an expense';

  @override
  String get askOther => 'Something else';

  @override
  String askLeftOf(int left, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: '$left of $total questions left today',
      one: '1 of $total questions left today',
    );
    return '$_temp0';
  }

  @override
  String askNoneLeft(int total) {
    return 'You\'ve used today\'s $total questions. They\'re back tomorrow.';
  }

  @override
  String get askBackTomorrow => 'Questions are back tomorrow';

  @override
  String get askSeeConversation => 'See the conversation';

  @override
  String get askWhatSees => 'What Gemini sees';

  @override
  String get geminiNoteHow =>
      'When you ask your money something, the question goes to Gemini, Google\'s model, through Quincena\'s Firebase project. You need no key and no account: Quincena knows you by an anonymous user, only to count your questions.';

  @override
  String get geminiNoteSends =>
      'Gemini does not get your database. It asks tools that run on your phone or computer for the figures it needs, and what travels is their answers: your totals by category and by month, what you can spend until payday, your subscriptions, your savings goal, your accounts with their balances and, when the question calls for it, a month\'s largest payments with their merchants.';

  @override
  String get geminiNoteNot =>
      'Your other individual transactions, your notes, your bank\'s alerts and your location are never sent.';

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
  String get themeTitle => 'Theme';

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
  String get setAsideMonthly => 'If you set aside each month';

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
  String get cancelSaves => 'Cancel the ones you checked and you save';

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
      'Explore the whole app with Valentina\'s account, a designer in Medellín. She is made up and your data stays untouched; switch to your own accounts any time.';

  @override
  String get privacyNote =>
      'Your accounts and transactions are stored only on this device.';

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
      'Quincena uses this to calculate how much you can spend until your next payday.';

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
  String payTwiceMonthlyDetail(String first, String second) {
    return 'The $first and $second of each month';
  }

  @override
  String get payMonthly => 'Monthly';

  @override
  String payMonthlyDetail(String day) {
    return 'The $day of each month';
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
  String get tabMovements => 'Transactions';

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
  String get accountInFavorNow => 'How much is in your favor today?';

  @override
  String get accountOverdraftNow => 'How much is it overdrawn today?';

  @override
  String get accountOverdrawn => 'It\'s overdrawn';

  @override
  String cardPaymentTitle(String card) {
    return 'Are you paying your $card?';
  }

  @override
  String cardPaymentBody(String from, String card, String amount) {
    return '$from → $card · $amount. This moves money between your accounts: it won\'t count as a new expense, since what you bought with the card is already counted.';
  }

  @override
  String get cardPaymentYes => 'Yes, record the payment';

  @override
  String get cardPaymentNo => 'No, it\'s an expense';

  @override
  String get accountSpendable => 'Everyday account';

  @override
  String get accountSpendableHelp =>
      'Its balance counts toward what you can spend until payday. Turn this off for savings, investments and crypto.';

  @override
  String get accountAssetLocked =>
      'The currency can\'t change because the account already has transactions in it.';

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
      other: 'Its $count transactions are deleted too. This can\'t be undone.',
      one: 'Its transaction is deleted too. This can\'t be undone.',
      zero: 'It has no transactions.',
    );
    return '$_temp0';
  }

  @override
  String get archive => 'Archive';

  @override
  String get restore => 'Restore';

  @override
  String archiveAccountTitle(String names) {
    return 'Archive $names?';
  }

  @override
  String archiveAccountKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions stay in your history.',
      one: 'One transaction stays in your history.',
    );
    return '$_temp0';
  }

  @override
  String archiveAccountHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'They stop showing in Accounts and when you pick an account. You can restore them any time from \"Archived accounts\", in Accounts.',
      one:
          'It stops showing in Accounts and when you pick an account. You can restore it any time from \"Archived accounts\", in Accounts.',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountPreferArchive =>
      'If you closed it, archive it instead: its history stays and it stops showing in Accounts.';

  @override
  String accountLeavingTransfers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count transfers with other accounts stay in those accounts as income or spending.',
      one:
          'A transfer with another account stays in that account as income or spending.',
    );
    return '$_temp0';
  }

  @override
  String accountLeavingCharges(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names are paid from here.',
      one: '$names is paid from here.',
    );
    return '$_temp0';
  }

  @override
  String get accountLeavingMoveTo => 'To be paid from';

  @override
  String get accountLeavingNoAccount => 'No account';

  @override
  String accountLeavingHeld(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'What they hold, $amount, stops counting in your net worth.',
      one: 'What it holds, $amount, stops counting in your net worth.',
    );
    return '$_temp0';
  }

  @override
  String accountLeavingOwed(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'What is owed on them, $amount, is no longer taken off your net worth.',
      one:
          'What is owed on it, $amount, is no longer taken off your net worth.',
    );
    return '$_temp0';
  }

  @override
  String accountLeavingHeldSpendable(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'What they hold, $amount, stops counting in your net worth and in what you can spend until payday.',
      one:
          'What it holds, $amount, stops counting in your net worth and in what you can spend until payday.',
    );
    return '$_temp0';
  }

  @override
  String accountLeavingOwedSpendable(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'What is owed on them, $amount, is no longer taken off your net worth or what you can spend until payday.',
      one:
          'What is owed on it, $amount, is no longer taken off your net worth or what you can spend until payday.',
    );
    return '$_temp0';
  }

  @override
  String accountLeavingInstalmentsApart(String amount) {
    return 'What is left of the installments, $amount, is no longer in a card\'s debt: it comes off your net worth on its own, and upcoming installments are counted as payments due.';
  }

  @override
  String accountLeavingInstalmentsCard(String amount) {
    return 'What is left of the installments, $amount, goes into the card\'s debt.';
  }

  @override
  String accountLeavingWorthSame(String total) {
    return 'Your net worth stays at $total.';
  }

  @override
  String accountLeavingWorth(String before, String after) {
    return 'Your net worth goes from $before to $after.';
  }

  @override
  String get archivedAccountsTitle => 'Archived accounts';

  @override
  String archivedAccountsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts, out of your totals',
      one: 'One account, out of your totals',
    );
    return '$_temp0';
  }

  @override
  String get archivedAccountsBody =>
      'Their transactions stay in your history, but they don\'t count in your totals or show up when you pick an account. Restore one and it goes back to Accounts and your totals.';

  @override
  String get archivedAccountsNone => 'You have no archived accounts.';

  @override
  String get accountArchivedNote =>
      'Archived: it doesn\'t count in your totals or show up when you pick an account.';

  @override
  String get groupSpendable => 'Everyday accounts';

  @override
  String get groupSaved => 'Savings and investments';

  @override
  String get netWorth => 'Net worth';

  @override
  String get noAccounts =>
      'No accounts yet. Add your bank\'s, your wallet or cash with \"Add account\".';

  @override
  String get yourAccounts => 'Your accounts';

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
    return '$asset counts as US\$1';
  }

  @override
  String get addMovement => 'Add transaction';

  @override
  String get editMovement => 'Edit transaction';

  @override
  String get kindExpense => 'Expense';

  @override
  String get kindIncome => 'Income';

  @override
  String get kindTransfer => 'Transfer';

  @override
  String get kindAdjustment => 'Adjustment';

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
  String get searchMovements => 'Search transactions';

  @override
  String get searchClear => 'Clear the search';

  @override
  String get filterOpen => 'Filter';

  @override
  String get filterTitle => 'Filter transactions';

  @override
  String get filterType => 'Type';

  @override
  String get filterAnyType => 'All';

  @override
  String get filterExpenses => 'Expenses';

  @override
  String get filterIncomes => 'Income';

  @override
  String get filterTransfers => 'Transfers';

  @override
  String get filterDates => 'Dates';

  @override
  String get filterAnyDate => 'Any date';

  @override
  String get filterThisPeriod => 'This pay period';

  @override
  String get filterSincePayday => 'Since last payday';

  @override
  String get filterThisMonth => 'This month';

  @override
  String get filterLastMonth => 'Last month';

  @override
  String get filterPickDays => 'Pick dates';

  @override
  String get filterAccounts => 'Accounts';

  @override
  String get filterCategories => 'Categories';

  @override
  String get filterAmount => 'Amount';

  @override
  String filterAmountHelp(String currency) {
    return 'What went out or came in, in $currency.';
  }

  @override
  String get filterAmountMin => 'From';

  @override
  String get filterAmountMax => 'Up to';

  @override
  String filterAmountBetween(String min, String max) {
    return '$min to $max';
  }

  @override
  String filterAmountAtLeast(String amount) {
    return 'From $amount';
  }

  @override
  String filterAmountAtMost(String amount) {
    return 'Up to $amount';
  }

  @override
  String filterShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count transactions',
      one: 'Show 1 transaction',
    );
    return '$_temp0';
  }

  @override
  String filterRemove(String name) {
    return 'Remove the $name filter';
  }

  @override
  String get filterClear => 'Clear filters';

  @override
  String foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get foundLeavesTransfers =>
      'The total leaves out transfers between your accounts.';

  @override
  String get noMovements =>
      'Your money coming in and going out will show up here.';

  @override
  String get noMovementsBody =>
      'Record an expense, an income or a transfer with \"Transaction\".';

  @override
  String get noResults => 'Nothing matches the search.';

  @override
  String get noResultsFilters => 'Nothing matches the filters.';

  @override
  String get noResultsBoth => 'Nothing matches the search and the filters.';

  @override
  String get deleteMovementTitle => 'Delete this transaction?';

  @override
  String get deleteTransferBody => 'Both sides of the transfer are deleted.';

  @override
  String get deleteSplitBody =>
      'Its split goes too: what you\'re owed for it stops counting.';

  @override
  String get invalidAmount => 'Enter an amount';

  @override
  String get sameAccount => 'Pick two different accounts';

  @override
  String get needAccountFirst => 'Add an account first.';

  @override
  String get recentMovements => 'Recent transactions';

  @override
  String get seeAll => 'See all';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get settingsProfile => 'Your profile';

  @override
  String get settingsAutomation => 'Automation';

  @override
  String get settingsConnected => 'Connected accounts';

  @override
  String transferArrived(String amount) {
    return '$amount arrived';
  }

  @override
  String transferSent(String amount) {
    return '$amount sent';
  }

  @override
  String get repeatMark => 'Duplicate?';

  @override
  String get repeatTitle => 'The same payment twice?';

  @override
  String repeatBody(String account) {
    return 'Both are in $account, for the same amount, on close dates.';
  }

  @override
  String get repeatNewer => 'The newer one';

  @override
  String get repeatRemove => 'Remove duplicate';

  @override
  String get repeatRemoveWhich => 'The newer one goes and the other stays.';

  @override
  String get repeatKeep => 'Not a duplicate';

  @override
  String get repeatRemoved => 'Duplicate removed.';

  @override
  String get settingsName => 'Name';

  @override
  String get settingsNameEmpty => 'Type your name.';

  @override
  String get settingsBase => 'Currency for totals';

  @override
  String settingsBaseNoRateTitle(String asset, String quote) {
    return 'What is 1 $asset worth in $quote?';
  }

  @override
  String settingsBaseNoRateBody(String from, String to) {
    return 'We don\'t have the rate between $from and $to. Without it, your totals would keep the same numbers in another currency. Type it, or keep $from.';
  }

  @override
  String settingsBaseRate(String asset) {
    return '1 $asset in';
  }

  @override
  String get settingsBaseRateMissing => 'Type the rate to switch currency.';

  @override
  String settingsBaseKeep(String code) {
    return 'Keep $code';
  }

  @override
  String settingsBaseChange(String code) {
    return 'Switch to $code';
  }

  @override
  String settingsBaseConverted(String code, String asset, String rate) {
    return 'Your totals are now in $code: converted at 1 $asset = $rate.';
  }

  @override
  String get settingsPay => 'How you get paid';

  @override
  String get settingsData => 'Your data';

  @override
  String get exportData => 'Export my data';

  @override
  String get exportDataSubtitle => 'Saves a backup of everything to a file';

  @override
  String get exportCsv => 'Export transactions as CSV';

  @override
  String get exportCsvSubtitle =>
      'To open them in Excel or another spreadsheet';

  @override
  String get exportCsvEmpty => 'There are no transactions to export yet.';

  @override
  String get csvDate => 'Date';

  @override
  String get csvAccount => 'Account';

  @override
  String get csvKind => 'Type';

  @override
  String get csvCategory => 'Category';

  @override
  String get csvPayee => 'Merchant';

  @override
  String get csvNote => 'Note';

  @override
  String get csvAmount => 'Amount';

  @override
  String get csvCurrency => 'Currency';

  @override
  String get exportDone => 'File saved.';

  @override
  String get settingsPayAmount => 'What you get paid';

  @override
  String get settingsPayAmountBody =>
      'What arrives each payday. It\'s used to project the coming days; it doesn\'t count as money until it arrives.';

  @override
  String get settingsCushion => 'Safety buffer';

  @override
  String get settingsCushionBody =>
      'Money you want to leave untouched. It isn\'t included in what you can spend until payday.';

  @override
  String get settingsNotSet => 'Not set';

  @override
  String get settingsRemove => 'Remove';

  @override
  String get settingsAmountAboveZero => 'Enter an amount above zero.';

  @override
  String get freeExplainCushion => 'Safety buffer';

  @override
  String get freeExplainAssumptions => 'What it assumes';

  @override
  String freeExplainAssumeToday(String payday) {
    return 'It counts what your everyday accounts hold today and takes away what\'s due by $payday.';
  }

  @override
  String freeExplainAssumePay(String pay, String payday) {
    return 'Your pay of $pay on $payday doesn\'t count until it arrives.';
  }

  @override
  String get freeExplainAssumeNoPay =>
      'It doesn\'t know what you get paid. Tell it in Settings and the projection takes it into account.';

  @override
  String freeExplainAssumeCushion(String cushion) {
    return 'It keeps $cushion aside as your safety buffer.';
  }

  @override
  String get freeExplainAssumeNoCushion =>
      'You haven\'t set a safety buffer. You can add one in Settings.';

  @override
  String payLate(String date) {
    return 'Your pay from $date hasn\'t shown up yet. If it arrived, record it.';
  }

  @override
  String get accountExplainTitle => 'How the balance adds up';

  @override
  String get accountExplainOpening => 'What it started with';

  @override
  String get accountExplainBalance => 'Balance today';

  @override
  String accountExplainAhead(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count future-dated transactions ($amount) don\'t count yet.',
      one: 'One future-dated transaction ($amount) doesn\'t count yet.',
    );
    return '$_temp0';
  }

  @override
  String traceIncome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count incomes',
      one: 'One income',
    );
    return '$_temp0';
  }

  @override
  String traceExpense(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: 'One expense',
    );
    return '$_temp0';
  }

  @override
  String traceTransferIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers in',
      one: 'One transfer in',
    );
    return '$_temp0';
  }

  @override
  String traceTransferOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers out',
      one: 'One transfer out',
    );
    return '$_temp0';
  }

  @override
  String traceBought(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count purchases',
      one: 'One purchase',
    );
    return '$_temp0';
  }

  @override
  String traceSold(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sales',
      one: 'One sale',
    );
    return '$_temp0';
  }

  @override
  String traceAdjustment(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count adjustments',
      one: 'One adjustment',
    );
    return '$_temp0';
  }

  @override
  String get totalExplainTitle => 'How your net worth is calculated';

  @override
  String totalExplainUnpriced(String names) {
    return 'No rate yet, not added: $names.';
  }

  @override
  String get computedOnPhone => 'Calculated on your phone';

  @override
  String get computedTitle => 'How this was calculated';

  @override
  String computedFooter(String time) {
    return 'Every figure in the answer came from these calculations, done on your phone with your data as of $time. Gemini only explains them.';
  }

  @override
  String get computedOverview =>
      'Your balances, upcoming payments, your safety buffer and what you can spend until payday';

  @override
  String computedMonth(String month) {
    return 'Spending in $month by category, compared with the month before';
  }

  @override
  String computedCategory(String category, String month) {
    return '$category payments in $month';
  }

  @override
  String get computedTotals => 'Income and spending over the last months';

  @override
  String get computedSubscriptions =>
      'Your subscriptions and what they cost a month';

  @override
  String get computedGoal => 'Your savings goal and what\'s left';

  @override
  String get computedRecord => 'The expense that was recorded';

  @override
  String get computedExpenseAccounts => 'The accounts an expense can come from';

  @override
  String get computedPlan => 'The plan that was saved';

  @override
  String get computedAccounts => 'Your accounts, each in its currency';

  @override
  String get computedPortfolio => 'Your crypto portfolio at market prices';

  @override
  String get computedSeeFree => 'See how \"You can spend\" is calculated';

  @override
  String get comingTitle => 'Next 30 days';

  @override
  String comingFreeLowest(String amount, String when) {
    return 'The least free before payday: $amount $when';
  }

  @override
  String comingFreeLowestWithout(String amount, String when) {
    return 'Without what you\'re trying out, the least free before payday: $amount $when';
  }

  @override
  String comingShortLowest(String amount, String when) {
    return 'Before payday you\'d be $amount short $when';
  }

  @override
  String comingShortLowestWithout(String amount, String when) {
    return 'Without what you\'re trying out, you\'d be $amount short before payday $when';
  }

  @override
  String comingTight(String when) {
    return '$when you\'d dip below your safety buffer.';
  }

  @override
  String comingTouchesKept(String when) {
    return '$when you\'d have to dip into what you keep apart.';
  }

  @override
  String comingRunsOut(String when) {
    return '$when you\'d run out of money.';
  }

  @override
  String get comingRunsOutBadge => 'Out of money';

  @override
  String get comingNoTight =>
      'You stay above your safety buffer for the next 30 days.';

  @override
  String get comingNoTightZero =>
      'You don\'t run out of money in the next 30 days.';

  @override
  String get comingNoTouchKept =>
      'You don\'t touch what you keep apart in the next 30 days.';

  @override
  String get comingLegendSure => 'What\'s sure';

  @override
  String get comingLegendLikely => 'With your pay and what you try';

  @override
  String comingLegendCushion(String amount) {
    return '$amount buffer';
  }

  @override
  String comingLegendKept(String amount) {
    return 'Kept apart: $amount';
  }

  @override
  String comingLeft(String amount) {
    return '$amount left';
  }

  @override
  String comingLeftFree(String amount) {
    return '$amount free';
  }

  @override
  String comingLeftTrying(String amount) {
    return 'with what you try, $amount';
  }

  @override
  String comingLeftExpected(String amount) {
    return 'if what you expect arrives, $amount';
  }

  @override
  String get comingUnderCushion => 'Below your buffer';

  @override
  String get comingUnderKept => 'Dips into what you keep apart';

  @override
  String get comingPay => 'Your pay';

  @override
  String get comingLatePay => 'Your late pay';

  @override
  String get comingTryOut => 'What you\'re trying';

  @override
  String get comingMove => 'Move in the simulation';

  @override
  String get comingSimulation =>
      'You\'re trying things out: none of this is saved or changes your payments.';

  @override
  String get comingClearSimulation => 'Clear what you\'re trying';

  @override
  String get comingNoEvents => 'Nothing scheduled in these days.';

  @override
  String get comingClose => 'Pay-period summary';

  @override
  String get buyTitle => 'Can I afford it?';

  @override
  String get buyPrice => 'How much is it?';

  @override
  String get buyWhat => 'What is it? (optional)';

  @override
  String get buyToday => 'Today';

  @override
  String get buyAfterPay => 'After payday';

  @override
  String get buyOther => 'Another day';

  @override
  String get buyFits => 'It fits, from what the app knows';

  @override
  String buyFitsFree(String amount, String when) {
    return 'You\'d have at least $amount free $when.';
  }

  @override
  String buyLowestInAccounts(String amount, String when) {
    return 'Your accounts would hold at least $amount $when.';
  }

  @override
  String get buyBelow => 'You\'d dip below your safety buffer';

  @override
  String buyBelowBody(String when, String amount, String cushion) {
    return '$when you\'d have $amount; your buffer is $cushion.';
  }

  @override
  String get buyShort => 'It doesn\'t stretch to payday';

  @override
  String buyShortBody(String when, String amount) {
    return '$when you\'d be $amount short.';
  }

  @override
  String buyReliesOnPay(String amount, String date) {
    return 'It counts on your pay of $amount on $date, which hasn\'t arrived yet.';
  }

  @override
  String get buyPayUnknown =>
      'I don\'t know what you get paid, so I don\'t count it. You can say it in Settings.';

  @override
  String get buyEstimate =>
      'It\'s an estimate from what\'s scheduled, not a guarantee.';

  @override
  String get buyCompareToday => 'If you buy today';

  @override
  String buyCompareAfter(String date) {
    return 'If you wait until $date';
  }

  @override
  String buyLowestFree(String amount) {
    return 'least free: $amount';
  }

  @override
  String buyLowestShort(String amount) {
    return '$amount short';
  }

  @override
  String get closeTitle => 'Pay-period summary';

  @override
  String closeRange(String from, String to) {
    return 'From $from to $to';
  }

  @override
  String get closeChanged => 'What changed';

  @override
  String get closeMonthly =>
      'Monthly payments, over the last 30 days against the 30 before:';

  @override
  String get closeComing => 'Coming up';

  @override
  String get closeAction => 'One thing you could do';

  @override
  String closeSpentMore(String spent, String difference) {
    return 'Day to day you spent $spent, $difference more than the previous pay period.';
  }

  @override
  String closeSpentLess(String spent, String difference) {
    return 'Day to day you spent $spent, $difference less than the previous pay period.';
  }

  @override
  String closeSpentSame(String spent) {
    return 'Day to day you spent $spent, the same as the previous pay period.';
  }

  @override
  String closeSpentFirst(String spent) {
    return 'Day to day you spent $spent. This is your first full pay period on record, so there\'s nothing to compare it with yet.';
  }

  @override
  String get closeNone =>
      'There\'s no full pay period on record yet. The summary appears once there is one, from one payday to the next.';

  @override
  String closeComingTotal(String date, String amount) {
    return '$amount is due by $date.';
  }

  @override
  String closeComingNone(String date) {
    return 'Nothing is due by $date.';
  }

  @override
  String closeComingMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'And $count more.',
      one: 'And one more.',
    );
    return '$_temp0';
  }

  @override
  String closeFree(String amount) {
    return 'You can spend until payday: $amount';
  }

  @override
  String closeShort(String amount) {
    return 'You\'re $amount short of payday';
  }

  @override
  String get closeSeeDays => 'See the next 30 days';

  @override
  String closeActionRunsOut(String date) {
    return 'On $date you\'d run out of money. See whether a charge could move to another day.';
  }

  @override
  String closeActionTight(String date) {
    return 'On $date you\'d dip below your buffer. See whether a charge could move to another day.';
  }

  @override
  String closeActionCategory(String category, String before, String now) {
    return '$category went from $before to $now compared with the previous pay period. Take a look at those payments.';
  }

  @override
  String closeActionGoal(String amount) {
    return 'You can spend $amount until payday. If you like, part of it can go to your goal.';
  }

  @override
  String closeContributeTo(String goal) {
    return 'Add to $goal';
  }

  @override
  String get closeGoalsTitle => 'What you set aside for your goals';

  @override
  String closeGoalEnvelope(String goal, String amount) {
    return '$goal: $amount in the envelope';
  }

  @override
  String get closeGoalMove => 'Move to savings';

  @override
  String closeGoalMoved(String goal, String amount) {
    return '$goal: $amount already moved to savings';
  }

  @override
  String get closeActionNone => 'Nothing to adjust this time.';

  @override
  String closePaymentsNone(String category) {
    return 'No payments in $category this pay period. Here are the ones from the period before:';
  }

  @override
  String get closeSeePayments => 'See the payments';

  @override
  String closePaymentsTitle(String category, String from, String to) {
    return '$category, $from to $to';
  }

  @override
  String get homeComing => 'Coming days';

  @override
  String get homeSeeDays => 'See 30 days';

  @override
  String get buyWithoutPay => 'without counting your pay';

  @override
  String get closeSpentNone =>
      'You recorded no day-to-day spending this pay period.';

  @override
  String get computedBuy =>
      'How your money would look with that purchase until payday, today and after payday';

  @override
  String get computedComing => 'Your money over the next 30 days, day by day';

  @override
  String get computedClose =>
      'Your last pay period, compared with the one before';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersClose => 'Remind me on payday';

  @override
  String get remindersCloseHelp =>
      'A reminder with no amounts, to see your pay-period summary. Nothing about your money shows on the lock screen.';

  @override
  String get remindersDenied =>
      'For reminders, allow Quincena\'s notifications in your phone\'s settings.';

  @override
  String get reminderTitle => 'Your pay-period summary is ready';

  @override
  String get reminderBody =>
      'Open it to see what changed and what\'s coming up.';

  @override
  String get tabPlan => 'Plan';

  @override
  String get goalIncomplete => 'Give it a name and how much you want to save.';

  @override
  String goalDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get goalDeleteBody =>
      'The goal is deleted. Your accounts and transactions don\'t change.';

  @override
  String get goalDelete => 'Delete goal';

  @override
  String get goalAdd => 'Add goal';

  @override
  String get goalEdit => 'Edit goal';

  @override
  String get goalName => 'What is it for?';

  @override
  String get goalTarget => 'How much do you want to save?';

  @override
  String get goalSaved => 'How much do you have?';

  @override
  String get goalMonthly => 'How much do you put in a month?';

  @override
  String get goalNoDeadline => 'No deadline';

  @override
  String goalBy(String date) {
    return 'By $date';
  }

  @override
  String goalSavedOf(String saved, String target) {
    return '$saved of $target';
  }

  @override
  String goalArrives(String date) {
    return 'arrives in $date';
  }

  @override
  String goalOnTime(String date) {
    return 'on time for $date';
  }

  @override
  String goalLate(String date, String amount) {
    return 'Your date is $date: to get there on time you need $amount a month.';
  }

  @override
  String goalLatePassed(String date) {
    return 'The date, $date, has passed: change it in the goal.';
  }

  @override
  String goalUseMonthly(String amount) {
    return 'Use $amount a month';
  }

  @override
  String get goalContribute => 'Add money';

  @override
  String goalContributeTitle(String goal) {
    return 'Add to $goal';
  }

  @override
  String get goalContributeFrom => 'From';

  @override
  String get goalContributeTo => 'Where does it go?';

  @override
  String get goalContributeKept => 'It\'s already saved: just add it';

  @override
  String get goalContributeNoSavings =>
      'For it to leave what you can spend, keep it in a savings account, a pocket or a CD.';

  @override
  String get goalContributeAddSavings => 'Add a savings account';

  @override
  String goalSavingsName(String goal) {
    return 'Savings for $goal';
  }

  @override
  String goalContributeAfter(String saved, String target) {
    return 'The goal will be at $saved of $target.';
  }

  @override
  String goalContributeMoves(String from, String amount, String to) {
    return '$from goes down by $amount and $to goes up as much: it leaves what you can spend.';
  }

  @override
  String get goalContributeOnlyCounts =>
      'It\'s only added to the goal: no money moves.';

  @override
  String get goalContributeInvalid => 'Write how much you add.';

  @override
  String get goalNoMonthly => 'with nothing a month, it has no date';

  @override
  String get envelopeAside => 'Set aside for something';

  @override
  String get envelopeAsideHint => 'A gift, tuition, a trip…';

  @override
  String get envelopesOverTitle => 'You\'re assigning more than there is';

  @override
  String envelopesShortGoals(String list) {
    return 'This period there isn\'t enough for everything: day to day comes first. $list. What\'s missing can wait for the next period.';
  }

  @override
  String envelopesShortItem(String name, String asked, String got) {
    return '$name gets $got of $asked';
  }

  @override
  String envelopesAdjusted(String list) {
    return 'Last period\'s split doesn\'t fit what there is now, and day to day comes first: $list.';
  }

  @override
  String envelopesAdjustedItem(String name, String asked, String got) {
    return '$name goes from $asked to $got';
  }

  @override
  String envelopesOver(String amount) {
    return 'The envelopes add up to $amount more than you have to split. You can save them like this, but that money isn\'t there yet.';
  }

  @override
  String get envelopesFix => 'Adjust';

  @override
  String get envelopesSaveAnyway => 'Save anyway';

  @override
  String get envelopesTitle => 'Split your paycheck';

  @override
  String envelopesPeriod(String from, String to) {
    return 'From $from to $to.';
  }

  @override
  String get envelopesToSplit => 'To split';

  @override
  String get envelopeDaily => 'Day to day';

  @override
  String get envelopeDailyHelp =>
      'Groceries, transport, going out: what\'s spent until payday.';

  @override
  String get envelopeGoalHelp =>
      'Set aside for your goal: no longer included in what you can spend.';

  @override
  String get envelopeAsideHelp =>
      'Set aside: no longer included in what you can spend.';

  @override
  String get envelopeRemove => 'Remove envelope';

  @override
  String get envelopesOverShort => 'Over by';

  @override
  String get envelopesFree => 'Not assigned yet';

  @override
  String get envelopesOnPaper =>
      'Envelopes don\'t move money, and your bank doesn\'t see them. They only say what each part of your money is for, and what you set aside comes out of what you can spend until payday.';

  @override
  String get envelopesSave => 'Save the split';

  @override
  String get cushionDaysTitle => 'Emergency fund in days';

  @override
  String cushionDaysCovers(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'It covers about $days days of essentials',
      one: 'It covers one day of essentials',
    );
    return '$_temp0';
  }

  @override
  String get cushionDaysNoReserve =>
      'Choose below the accounts that hold your emergency fund.';

  @override
  String get cushionDaysShortHistory =>
      'With less than a month of transactions, there\'s no reliable average yet. Check back in a few weeks.';

  @override
  String get cushionDaysNoEssential =>
      'There\'s no spending in the essential categories you chose, so it can\'t be counted in days. Check the categories.';

  @override
  String cushionDaysHow(String reserve, String daily, String from, String to) {
    return '$reserve at $daily a day, what your essentials averaged from $from to $to.';
  }

  @override
  String cushionDaysReached(int days) {
    return 'You reached the $days days you set.';
  }

  @override
  String cushionDaysToGo(int days, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days to go: $amount.',
      one: 'One day to go: $amount.',
    );
    return '$_temp0';
  }

  @override
  String get cushionDaysEstimate =>
      'It\'s an average: a month that spends differently changes it.';

  @override
  String get cushionDaysAccounts => 'Where your emergency fund is';

  @override
  String get cushionDaysEssentials => 'What\'s essential to you';

  @override
  String get cushionDaysTarget => 'How many days you want to cover';

  @override
  String get cushionDaysNoTarget => 'No goal';

  @override
  String cushionDaysOption(int days) {
    return '$days days';
  }

  @override
  String get cushionDaysTargetNote =>
      'There\'s no right number for everyone: choose the one that gives you peace of mind.';

  @override
  String get wishesTitle => 'I want it, but later';

  @override
  String get wishAdd => 'Add a wish';

  @override
  String get wishesBody =>
      'What you want to buy later, at the price you set. Nothing is bought, and no shop is watched.';

  @override
  String get wishesEmpty => 'No wishes yet.';

  @override
  String get wishPriorityHigh => 'Wanted a lot';

  @override
  String get wishPriorityMedium => 'Wanted';

  @override
  String get wishPriorityLow => 'If there\'s some left';

  @override
  String get wishRemove => 'Remove wish';

  @override
  String get wishBought => 'I bought it';

  @override
  String wishWaiting(String date) {
    return 'You\'re waiting until $date to decide.';
  }

  @override
  String wishAgainstGoal(String goal, String after, String before) {
    return 'If you buy it, $goal would arrive in $after instead of $before.';
  }

  @override
  String get wishIncomplete => 'Give it a name and a price.';

  @override
  String get wishName => 'What do you want?';

  @override
  String get wishPrice => 'How much is it?';

  @override
  String get wishWait => 'Wait 30 days before deciding';

  @override
  String get wishWaitHelp =>
      'If you still want it in a month, you decide calmly.';

  @override
  String get whatIfTitle => 'What if…?';

  @override
  String get whatIfSaveMore => 'I save more';

  @override
  String get whatIfChargeUp => 'A charge goes up';

  @override
  String get whatIfPayLate => 'Late pay';

  @override
  String whatIfSaveMoreSaid(String amount) {
    return 'Setting aside $amount more each payday';
  }

  @override
  String whatIfChargeUpSaid(String charge, String amount) {
    return '$charge goes up $amount';
  }

  @override
  String whatIfPayLateSaid(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'The pay arrives $days days late',
      one: 'The pay arrives a day late',
    );
    return '$_temp0';
  }

  @override
  String get whatIfApplyTitle => 'Apply the change?';

  @override
  String whatIfApplyCharge(String charge, String amount) {
    return '$charge will be $amount from its next charge. What\'s recorded doesn\'t change.';
  }

  @override
  String get whatIfApplySave => 'This changes your plan from now on.';

  @override
  String get whatIfApply => 'Apply';

  @override
  String get whatIfNoCharges =>
      'You have no charges scheduled in the coming weeks.';

  @override
  String get whatIfSaveMoreAmount => 'How much more each payday?';

  @override
  String get whatIfChargeUpAmount => 'How much does it go up?';

  @override
  String get whatIfNeedsPay =>
      'To try a late pay, say in Settings what you get paid.';

  @override
  String whatIfPayLateDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days late',
      one: 'One day late',
    );
    return '$_temp0';
  }

  @override
  String get whatIfFewerDays => 'Fewer days';

  @override
  String get whatIfMoreDays => 'More days';

  @override
  String get whatIfLowest => 'Lowest balance in 45 days';

  @override
  String get whatIfTight => 'First day below your buffer';

  @override
  String get whatIfNoTight => 'none';

  @override
  String whatIfEnd(String date) {
    return 'On $date';
  }

  @override
  String whatIfGoal(String goal) {
    return '$goal arrives in';
  }

  @override
  String get whatIfGoalNever => 'no date';

  @override
  String get whatIfDaily => 'Count everyday spending';

  @override
  String whatIfDailyAbout(String amount) {
    return 'What you usually spend: about $amount a day, leaving out your fixed payments.';
  }

  @override
  String whatIfAssumesDaily(String amount) {
    return 'It counts your expected pay, what is scheduled and about $amount a day of everyday spending. None of this changes your accounts.';
  }

  @override
  String get whatIfAssumesNoDaily =>
      'It counts your expected pay and what is scheduled, without everyday spending: your real balance will be lower. None of this changes your accounts.';

  @override
  String get whatIfNoDailyYet =>
      'It counts your expected pay and what is scheduled. It leaves out everyday spending: there is no full pay period with spending on record to estimate it yet, so your real balance will be lower.';

  @override
  String get whatIfSave => 'Save the scenario';

  @override
  String get whatIfSaved => 'Saved scenarios';

  @override
  String whatIfSavedOutcome(String amount, String date) {
    return 'Lowest balance: $amount on $date';
  }

  @override
  String get whatIfRemove => 'Remove scenario';

  @override
  String get whatIfToday => 'Today';

  @override
  String get whatIfWith => 'With the change';

  @override
  String get planOrganize => 'Organize my money';

  @override
  String planUntil(String date) {
    return 'Until $date';
  }

  @override
  String get planAchieve => 'What I want to achieve';

  @override
  String get planPaying => 'What I\'m paying off';

  @override
  String get planNoGoals =>
      'You don\'t have goals yet. A goal with something each month tells you when you\'ll get there.';

  @override
  String get planTools => 'Tools';

  @override
  String get planCushionChoose => 'Choose where your emergency fund is';

  @override
  String get planCushionSoon => 'It can\'t be counted in days yet';

  @override
  String get planWishesNone => 'Keep what you want for later';

  @override
  String planWishes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wishes',
      one: 'One wish',
    );
    return '$_temp0';
  }

  @override
  String get planWhatIf => 'Try a change without applying it';

  @override
  String get planComing => 'The days ahead, with the tight ones marked';

  @override
  String get planSplitTitle => 'Split this paycheck';

  @override
  String planSplitBody(String amount) {
    return 'You have $amount to split between the day to day, your goals and whatever you want to set aside.';
  }

  @override
  String get planSplit => 'Split into envelopes';

  @override
  String planDailySpent(String spent, String daily) {
    return '$spent of $daily so far';
  }

  @override
  String planDailyOver(String amount) {
    return 'Over by $amount';
  }

  @override
  String get planAdjust => 'Adjust the split';

  @override
  String get freeExplainSetAside => 'Set aside in envelopes';

  @override
  String get paydayArrived => 'Your pay arrived';

  @override
  String get freeExplainAction => 'Where does it come from?';

  @override
  String get freeExplainTitle => 'How \"You can spend\" is calculated';

  @override
  String get freeExplainSpendable => 'In your everyday accounts';

  @override
  String freeExplainCommitted(String date) {
    return 'Payments until $date';
  }

  @override
  String freeExplainNothingCommitted(String date) {
    return 'Nothing scheduled until $date.';
  }

  @override
  String get freeExplainLeftOut => 'Left out';

  @override
  String freeExplainLeftOutBody(String names) {
    return '$names: you marked them as savings or investments, not money to spend. You can change that in each account.';
  }

  @override
  String freeExplainUnpriced(String codes) {
    return 'No rate yet, counted as zero: $codes.';
  }

  @override
  String get freeExplainEstimate =>
      'It\'s an estimate: it counts what already happened and what\'s scheduled until payday. Anything you spend or receive without scheduling it changes it.';

  @override
  String freeExplainHeldAt(String held, String rate) {
    return '$held at $rate';
  }

  @override
  String get importData => 'Restore a backup';

  @override
  String get importDataSubtitle =>
      'Replaces everything here with the backup\'s data';

  @override
  String get restoreTitle => 'Restore this backup?';

  @override
  String restoreFrom(String date) {
    return 'Backup from $date:';
  }

  @override
  String get restoreHolds => 'This backup has:';

  @override
  String restoreAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: 'One account',
      zero: 'No accounts',
    );
    return '$_temp0';
  }

  @override
  String restoreMovements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: 'One transaction',
      zero: 'No transactions',
    );
    return '$_temp0';
  }

  @override
  String restoreGoals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count goals',
      one: 'One goal',
      zero: 'No goals',
    );
    return '$_temp0';
  }

  @override
  String restorePlan(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more things in the Plan',
      one: 'One more thing in the Plan',
      zero: 'Nothing else in the Plan',
    );
    return '$_temp0';
  }

  @override
  String get restoreReplaces =>
      'What you have in Quincena now is deleted and replaced with the backup.';

  @override
  String get restoreSaveFirst => 'Save what\'s here first';

  @override
  String get importDone => 'Backup restored.';

  @override
  String get importNotQuincena =>
      'That file wasn\'t exported by Quincena. Nothing was changed.';

  @override
  String get importNewer =>
      'That file comes from a newer version of Quincena. Update the app and try again; nothing was changed.';

  @override
  String get importDamaged =>
      'That file is damaged or incomplete. Nothing was changed.';

  @override
  String get deleteAll => 'Delete everything';

  @override
  String get deleteAllTitle => 'Delete all your data?';

  @override
  String get deleteAllBody =>
      'Accounts, transactions and settings are deleted from this device. This can\'t be undone.';

  @override
  String get deleteAllRecover =>
      'To get them back later you\'ll need a backup kept off this phone and, if it\'s encrypted, its backup code.';

  @override
  String get deleteAllForgetsCode =>
      'Deleting makes this phone forget your backup code: keep it first.';

  @override
  String get deleteAllBackupFirst => 'Save a backup first';

  @override
  String get useDemo => 'See the sample data';

  @override
  String get useOwn => 'Use with my accounts';

  @override
  String get backToOwn => 'Back to my accounts';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get settingsHelp => 'Help and privacy';

  @override
  String get privacyBody =>
      'Your accounts and transactions are kept only on this device. Quincena has no server holding your finances, shows no ads and does not sell your data. The policy says what goes to Gemini, to Binance or to the price sources, and when.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get inboxTitle => 'Needs review';

  @override
  String inboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Review $count transactions to update your balance',
      one: 'Review 1 transaction to update your balance',
    );
    return '$_temp0';
  }

  @override
  String inboxBannerBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They aren\'t counted in what you can spend yet.',
      one: 'It isn\'t counted in what you can spend yet.',
    );
    return '$_temp0';
  }

  @override
  String get inboxEmpty => 'All caught up.';

  @override
  String get inboxEmptyBody =>
      'Nothing waiting. When a payment arrives from your bank, it shows up here for you to record.';

  @override
  String get edit => 'Edit';

  @override
  String get dismiss => 'Dismiss';

  @override
  String dismissAndMute(String app) {
    return 'Dismiss and stop reading $app';
  }

  @override
  String get chooseAccount => 'Choose account';

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
    return 'Nearby: $name, $metres m away · © OpenStreetMap contributors';
  }

  @override
  String get possibleDuplicates => 'Possible repeats';

  @override
  String get duplicateLine => 'The same payment already arrived another way.';

  @override
  String get notDuplicate => 'Not a repeat';

  @override
  String whyLabel(String reasons) {
    return 'Suggested because $reasons.';
  }

  @override
  String whyCard(String digits, String account) {
    return 'card *$digits belongs to $account';
  }

  @override
  String whyInstitution(String institution, String account) {
    return '$institution alerts go to $account';
  }

  @override
  String whyInstitutionSame(String institution) {
    return 'it came from your $institution account';
  }

  @override
  String whyCurrency(String asset) {
    return 'it\'s your only account in $asset';
  }

  @override
  String whyOnly(String asset) {
    return 'it\'s your only everyday account in $asset; check it';
  }

  @override
  String whyLearned(String merchant) {
    return 'that\'s how you recorded $merchant before';
  }

  @override
  String whyMerchant(String merchant) {
    return 'we recognized $merchant';
  }

  @override
  String get whyWords => 'the message says what it is';

  @override
  String ruleLearned(String rules) {
    return 'From now on, $rules.';
  }

  @override
  String ruleGoesMerchant(String merchant, String category) {
    return '\"$merchant\" goes to $category';
  }

  @override
  String ruleGoesCard(String digits, String account) {
    return 'card *$digits goes to $account';
  }

  @override
  String ruleGoesAccount(String digits, String account) {
    return 'account *$digits goes to $account';
  }

  @override
  String ruleGoesInstitution(String institution, String account) {
    return '$institution alerts go to $account';
  }

  @override
  String ruleResolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more transactions are ready too.',
      one: '1 more transaction is ready too.',
    );
    return '$_temp0';
  }

  @override
  String get ruleMissingAccount => 'an account that\'s gone';

  @override
  String ruleCardKey(String digits) {
    return 'Card *$digits';
  }

  @override
  String get rulesTitle => 'Learned rules';

  @override
  String get rulesBody =>
      'They\'re created when you record something in Needs review. A rule affects what comes in later and what still waits there; nothing already recorded changes.';

  @override
  String get rulesEmpty =>
      'No rules yet. They show up when you record your first transactions.';

  @override
  String get rulesMerchants => 'Shops';

  @override
  String get rulesCards => 'Cards';

  @override
  String get rulesInstitutions => 'Banks and wallets';

  @override
  String rulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: 'One rule',
      zero: 'None yet',
    );
    return '$_temp0';
  }

  @override
  String get ruleDelete => 'Delete rule';

  @override
  String get ruleOn => 'Use this rule';

  @override
  String get ruleChooseCategory => 'Which category does it go to?';

  @override
  String get ruleChooseAccount => 'Which account does it go to?';

  @override
  String get autoRecordedBody =>
      'What the app recorded on its own in the last two weeks. If something\'s wrong, undo it and it goes back to Needs review.';

  @override
  String get fixMovement => 'Fix';

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
  String get pasteAdded => 'It\'s in Needs review.';

  @override
  String get pasteRecorded => 'It was recorded.';

  @override
  String get pasteNothing => 'I could not find a payment in that text.';

  @override
  String get pasteDuplicate => 'That payment was already there.';

  @override
  String get pasteJoined =>
      'That notice belongs to a transfer you already recorded.';

  @override
  String get readScreenshot => 'Read a screenshot or PDF';

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
      other: 'Found $count payments. They\'re in Needs review.',
      one: 'Found a payment. It\'s in Needs review.',
    );
    return '$_temp0';
  }

  @override
  String get readNothing =>
      'No amount with its currency was found. Try a screenshot where the amount shows.';

  @override
  String get captureTitle => 'Automatic capture';

  @override
  String get captureSubtitle =>
      'Payments that arrive by themselves from your notifications and messages';

  @override
  String get captureAuto => 'Record what is clear on its own';

  @override
  String get captureAutoHelp =>
      'When the account, category and amount are certain and it isn\'t a duplicate, it\'s recorded without asking. Everything else waits in Needs review.';

  @override
  String get captureLocation => 'Use where the payment happened';

  @override
  String get captureLocationHelp =>
      'When the alert doesn\'t say where, Quincena looks up the shops a few meters from where the phone was. The location stays here; only the coordinates go to OpenStreetMap, through Photon, to find the shops. Shop data is © OpenStreetMap contributors, under the ODbL.';

  @override
  String get captureLocationDenied =>
      'Quincena can\'t use the location. You can allow it in the phone\'s settings.';

  @override
  String get openPhoneSettings => 'Open settings';

  @override
  String get captureAlwaysTitle => 'Location while Quincena is closed';

  @override
  String get captureAlwaysBody =>
      'Quincena collects location data to suggest the shop of a payment, even when the app is closed or not in use. It only looks at the location when a payment notification arrives, keeps it on this phone, and sends just the coordinates to OpenStreetMap, through Photon, to find the shop. Android will ask you to choose \"Allow all the time\".';

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
  String get acceptLabel => 'Accept';

  @override
  String get disclosureUses => 'What it uses';

  @override
  String get disclosureReads => 'What it reads';

  @override
  String get disclosureWhen => 'When';

  @override
  String get disclosureWhere => 'Where it stays';

  @override
  String get captureLocationAskTitle => 'Location of your payments';

  @override
  String get captureLocationAskLead =>
      'Quincena collects location data to suggest the shop of a payment, even when the app is closed or not in use.';

  @override
  String get captureLocationAskWhat => 'Your phone\'s precise location.';

  @override
  String get captureLocationAskWhen =>
      'Only when a payment notification arrives, also while the app is closed or not in use.';

  @override
  String get captureLocationAskWhere =>
      'On this phone. To find the shop, only the coordinates go to OpenStreetMap, through Photon: nothing else, and to no one else.';

  @override
  String get captureLocationAskNextAndroid =>
      'If you accept, Android will ask you for permission to use your location.';

  @override
  String get captureLocationAskNextIos =>
      'If you accept, Quincena will use the location your shortcut hands over with each payment.';

  @override
  String get captureNotificationsAskTitle =>
      'Reading your payment notifications';

  @override
  String get captureNotificationsAskLead =>
      'Quincena reads this phone\'s notifications to note your payments without you having to type them.';

  @override
  String get captureNotificationsAskWhat =>
      'The text of incoming notifications, such as those from your bank and wallet apps and your texts. It keeps only the ones with an amount and its currency, along with the app that showed it and the time; the rest pass by without being kept, and verification codes are never kept.';

  @override
  String get captureNotificationsAskWhen =>
      'Every time a notification arrives, also while the app is closed or not in use.';

  @override
  String get captureNotificationsAskWhere =>
      'On this phone. Quincena doesn\'t send their text to any server or anyone.';

  @override
  String get captureNotificationsAskNext =>
      'If you accept, Android will open notification access so you can turn Quincena on.';

  @override
  String get captureImagesTitle => 'Screenshots and receipts';

  @override
  String get captureImagesIos =>
      'In Needs review, you can pick a screenshot, a photo or a PDF of a payment, and Quincena reads it on the phone.\nTo send them from other apps, make a shortcut with Quincena\'s \"Read a receipt\" action and turn on \"Show in Share Sheet\".\nWith \"Take Screenshot\" before it and Back Tap (Settings, Accessibility, Touch), double-tap the back of the iPhone to read what is on the screen.';

  @override
  String get captureImagesAndroid =>
      'Share a screenshot, a photo, a PDF or a text with Quincena from any app, or pick them in Needs review. They\'re read on the phone and wait there for you to record them.';

  @override
  String get captureImagesDesktop =>
      'Pick a screenshot, a photo or a PDF of a payment in Needs review, and Quincena reads it on this computer.';

  @override
  String get captureIosTitle => 'On iPhone, with Shortcuts';

  @override
  String get captureIosSteps =>
      '1. Open Shortcuts and go to Automation.\n2. Create a new one with Wallet and pick your cards.\n3. If you want to use the location, add \"Get Current Location\". Then add Quincena\'s \"Record a transaction\" action, choose Apple Pay as the source and give it the amount, the merchant and the card.\n4. Choose \"Run Immediately\".\nFor your bank\'s text messages, create a Message automation for the bank\'s sender, use the same action with Message as the source and give it the message as text. From iOS 27, the Notification automation does the same with your banks\' apps.';

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

  @override
  String get portfolioTitle => 'Crypto';

  @override
  String get portfolioWorth => 'Your crypto is worth';

  @override
  String get portfolioToday => 'In 24 hours';

  @override
  String get portfolioGain => 'Unrealized gain';

  @override
  String get portfolioLoss => 'Unrealized loss';

  @override
  String get portfolioSinceBought => 'on what you paid';

  @override
  String portfolioPricedAt(String when) {
    return 'Binance prices from $when';
  }

  @override
  String get portfolioPricing => 'Reading prices…';

  @override
  String get portfolioPricingFailed =>
      'Prices could not be read: the last ones saved are shown.';

  @override
  String get portfolioNeverPriced =>
      'No prices yet: they are read once online.';

  @override
  String get rangeDay => '24 h';

  @override
  String get rangeWeek => '7 d';

  @override
  String get rangeMonth => '30 d';

  @override
  String get rangeYear => '1 y';

  @override
  String get rangeDayLong => 'in 24 hours';

  @override
  String get rangeWeekLong => 'in 7 days';

  @override
  String get rangeMonthLong => 'in 30 days';

  @override
  String get rangeYearLong => 'in a year';

  @override
  String get chartEmpty => 'No prices to draw yet.';

  @override
  String get chartWithHoldings =>
      'The value with what you held at each moment: a purchase lifts it at once.';

  @override
  String get portfolioAllocation => 'Allocation';

  @override
  String get portfolioOtherPlace => 'Other';

  @override
  String get portfolioOtherAssets => 'Other';

  @override
  String portfolioRealized(String amount) {
    return 'Already gained in sales and conversions: $amount';
  }

  @override
  String portfolioRealizedLoss(String amount) {
    return 'Already lost in sales and conversions: $amount';
  }

  @override
  String portfolioUncosted(String amount) {
    return '$amount came in with no purchase price and are left out of the gain. You can add what they cost in their account.';
  }

  @override
  String portfolioUnpriced(String assets) {
    return 'Binance has no price for $assets: they are left out of the total.';
  }

  @override
  String get portfolioDisclaimer =>
      'Market prices from Binance, which change by the moment. Quincena does not give investment advice.';

  @override
  String get portfolioEmpty =>
      'No crypto yet. Add a wallet or connect Binance.';

  @override
  String get holdingPrice => 'Price';

  @override
  String get holdingWorth => 'Worth';

  @override
  String get holdingCost => 'It cost you';

  @override
  String get holdingAverage => 'Average cost';

  @override
  String get holdingNoCost => 'No cost';

  @override
  String get holdingNoCostHelp =>
      'Add what it cost when editing the account, or record your purchases.';

  @override
  String get tradeBuy => 'Record a purchase';

  @override
  String get tradeSell => 'Record a sale';

  @override
  String get tradeBought => 'Purchase';

  @override
  String get tradeSold => 'Sale';

  @override
  String tradeQuantity(String code) {
    return 'Amount of $code';
  }

  @override
  String get tradePaid => 'Total paid';

  @override
  String get tradeReceived => 'Total received';

  @override
  String get tradePaidFrom => 'Paid from';

  @override
  String get tradeReceivedIn => 'Received in';

  @override
  String get tradeOutside => 'Outside Quincena';

  @override
  String get tradeOutsideHelp =>
      'On Binance P2P, another exchange or in cash. If it comes out of one of your accounts, pick it and its balance changes too.';

  @override
  String tradePriceEach(String price) {
    return 'Price per unit: $price';
  }

  @override
  String tradeNotEnough(String amount) {
    return 'That account holds $amount.';
  }

  @override
  String get accountOpeningCost => 'What did it cost you?';

  @override
  String get accountOpeningCostHelp =>
      'Optional. What you paid for that balance; with it, Quincena calculates your gain.';

  @override
  String get binanceTitle => 'Binance';

  @override
  String get binanceCardTitle => 'Connect Binance';

  @override
  String get binanceCardBody =>
      'Quincena can only look at your account: it can never move your funds.';

  @override
  String get binanceConnectTitle => 'Your Binance account, on its own';

  @override
  String get binanceConnectBody =>
      'Quincena brings in your spot, funding and Earn balances, your P2P purchases and sales, your conversions, market trades, deposits and withdrawals, and calculates what each coin cost you.';

  @override
  String get binanceReadOnlyTitle => 'Read only';

  @override
  String get binanceReadOnlyBody =>
      'The key can only read: it cannot buy, sell, move or withdraw anything. If it can do anything more, Quincena does not take it.';

  @override
  String get binanceKeyStoredTitle => 'Only on this device';

  @override
  String get binanceKeyStoredBody =>
      'The key is kept in the device\'s keychain and only used to talk to Binance. It does not go to Gemini, into the copy you export, or to any Quincena server.';

  @override
  String get binanceStepsTitle => 'How to create the key';

  @override
  String get binanceSteps =>
      '1. In the Binance app, open your profile and go to API Management.\n2. Create a system-generated API and name it Quincena.\n3. Leave only \"Enable Reading\" checked. Since a phone has no fixed IP, choose no IP restriction: with read-only access nobody can move your money.\n4. Copy the API Key and the Secret Key and paste them here.';

  @override
  String get binanceApiKey => 'API Key';

  @override
  String get binanceSecretKey => 'Secret Key';

  @override
  String get binanceNeedKey => 'Type your API Key';

  @override
  String get binanceNeedSecret => 'Type your Secret Key';

  @override
  String get binanceConnect => 'Connect';

  @override
  String get binanceConnecting => 'Checking the key with Binance…';

  @override
  String binanceNotReadOnly(String what) {
    return 'This key can do more than read ($what). Create one with only \"Enable Reading\"; this one was not kept.';
  }

  @override
  String get binanceBadKey =>
      'Binance does not recognize that key. Check that you copied both in full, or that it was not deleted.';

  @override
  String get binanceOffline =>
      'Binance could not be reached. Check your connection and try again.';

  @override
  String get binanceLimited =>
      'Binance asked to wait a moment. Try again in a minute.';

  @override
  String get binanceFailed =>
      'Something went wrong reading Binance. Try again.';

  @override
  String get binanceConnected => 'Connected with a read-only key';

  @override
  String binanceSyncedAt(String when) {
    return 'Read $when';
  }

  @override
  String get binanceNeverSynced => 'Not read yet';

  @override
  String binanceReadFailedAt(String when) {
    return 'Couldn\'t read it. Last read: $when';
  }

  @override
  String get binanceReadFailedNever => 'Couldn\'t read it yet';

  @override
  String get binanceSyncNow => 'Read now';

  @override
  String get binanceSyncing => 'Reading your Binance account…';

  @override
  String binanceReport(int movements) {
    String _temp0 = intl.Intl.pluralLogic(
      movements,
      locale: localeName,
      other: '$movements new transactions',
      one: 'one new transaction',
      zero: 'nothing new',
    );
    return 'Done: $_temp0.';
  }

  @override
  String get binanceDisconnect => 'Disconnect';

  @override
  String get binanceDisconnectTitle => 'Disconnect Binance?';

  @override
  String get binanceDisconnectBody =>
      'The key is erased from this device. The accounts and transactions it brought stay as yours.';

  @override
  String get binanceWebOnly =>
      'On the web, Binance does not let a page connect to your account. Connect it from the phone or computer app.';

  @override
  String binanceManualAccounts(String names) {
    return 'You also have Binance accounts you kept by hand: $names. Archive them so the same money is not counted twice.';
  }

  @override
  String get binanceArchive => 'Archive them';

  @override
  String get binanceArchiveWhy =>
      'Binance already brings these balances: archiving them keeps them from counting twice.';

  @override
  String get binanceLabelP2p => 'Binance P2P';

  @override
  String get binanceLabelConversion => 'Binance conversion';

  @override
  String get binanceLabelDeposit => 'Deposit to Binance';

  @override
  String get binanceLabelWithdrawal => 'Withdrawal from Binance';

  @override
  String get binanceLabelFee => 'Binance fee';

  @override
  String get binanceLabelAdjustment => 'Adjustment with Binance';

  @override
  String get statementTitle => 'Import a statement';

  @override
  String get statementSubtitle => 'Your bank\'s CSV, Excel or PDF';

  @override
  String get statementIntro =>
      'Bring in the transactions from a bank or card statement: CSV, Excel (.xlsx) or PDF. It is read on this device, and you review every transaction before it is saved.';

  @override
  String get statementPick => 'Choose a file';

  @override
  String get statementReading => 'Reading the statement…';

  @override
  String get statementNothing => 'No transactions were found in this file.';

  @override
  String get statementFailed =>
      'The file could not be read. Try a CSV, an Excel (.xlsx) or a PDF.';

  @override
  String get statementGemini => 'Read it with Gemini';

  @override
  String get statementGeminiNote =>
      'The statement\'s text, with its dates, descriptions and amounts, goes to Gemini to sort it out. It counts as one of the day\'s questions.';

  @override
  String get statementGeminiPdf =>
      'On the web the PDF cannot be read here: the file goes to Gemini to read it. It counts as one of the day\'s questions.';

  @override
  String statementSummary(int count, String range) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: 'One transaction',
    );
    return '$_temp0 · $range';
  }

  @override
  String get statementRecorded => 'Already recorded';

  @override
  String get statementImportedBefore => 'Already imported';

  @override
  String get statementFlip => 'Swap money in and out';

  @override
  String statementImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count transactions',
      one: 'Import one transaction',
      zero: 'Nothing to import',
    );
    return '$_temp0';
  }

  @override
  String statementDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions were imported.',
      one: 'One transaction was imported.',
    );
    return '$_temp0';
  }

  @override
  String get statementByGemini =>
      'Read by Gemini: check it well before importing.';

  @override
  String get walletsTitle => 'Your own wallets';

  @override
  String get walletsCardBody =>
      'Ledger, MetaMask, Trust Wallet: by their public address.';

  @override
  String get walletsBody =>
      'Follow what you hold in Ledger, MetaMask, Trust Wallet or any wallet, by its public address. It is only read: nobody can move anything with an address.';

  @override
  String get walletsChains =>
      'Bitcoin, Ethereum (ETH, USDT and USDC) and TRON (TRX, USDT and USDC).';

  @override
  String get walletsPrivacy =>
      'The address is looked up on public services: mempool.space, a public Ethereum node and TronGrid. They see the address, not who you are.';

  @override
  String get walletsAdd => 'Add a wallet';

  @override
  String get walletsAddress => 'Public address';

  @override
  String get walletsLabel => 'Name: Ledger, MetaMask…';

  @override
  String walletsBadAddress(String chain) {
    return 'That does not look like a $chain address.';
  }

  @override
  String get walletsUnreadable =>
      'That address could not be read. Check your connection and try again.';

  @override
  String get walletsRemove => 'Stop following';

  @override
  String get walletsRemoveBody =>
      'It is no longer read. The accounts it brought stay as yours.';

  @override
  String walletsSyncedAt(String when) {
    return 'Read $when';
  }

  @override
  String get walletsEmpty => 'You do not follow any wallet yet.';

  @override
  String get walletsAdjustment => 'Wallet adjustment';

  @override
  String get walletsFailed =>
      'A wallet could not be read; its last balances are shown.';

  @override
  String get chartWithoutTrades =>
      'From prices, not counting what you bought or sold in those days.';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get supportTitle => 'Support';

  @override
  String get cadencePerMonth => 'a month';

  @override
  String get cadencePerTwoWeeks => 'every two weeks';

  @override
  String get cadencePerWeek => 'a week';

  @override
  String get cadencePerYear => 'a year';

  @override
  String get cadenceMonthly => 'Every month';

  @override
  String get cadenceBiweekly => 'Every two weeks';

  @override
  String get cadenceWeekly => 'Every week';

  @override
  String get cadenceYearly => 'Every year';

  @override
  String get chargeAdd => 'Add a recurring payment';

  @override
  String get chargeEdit => 'Recurring payment';

  @override
  String get chargePausedNote => 'Paused: not counted in upcoming payments.';

  @override
  String get chargeName => 'What is it?';

  @override
  String get chargeAmount => 'How much is it?';

  @override
  String chargeUseLast(String amount, String date) {
    return 'The last charge was $amount, on $date: use that';
  }

  @override
  String get chargeCadence => 'How often';

  @override
  String chargeNext(String date) {
    return 'Next charge: $date';
  }

  @override
  String get chargeAccount => 'Paid from';

  @override
  String get chargeNoAccount => 'No particular account';

  @override
  String get chargeRemind => 'Remind me before each charge';

  @override
  String get remindNever => 'Don\'t remind me';

  @override
  String get remindSameDay => 'On the day';

  @override
  String get remindDayBefore => 'A day before';

  @override
  String remindDaysBefore(int days) {
    return '$days days before';
  }

  @override
  String get remindWeekBefore => 'A week before';

  @override
  String get chargeSubscription => 'Subscription';

  @override
  String get chargeTrialAsk => 'On a free trial?';

  @override
  String chargeTrialUntil(String date) {
    return 'Free trial until $date';
  }

  @override
  String get chargeTrialClear => 'Remove the free trial';

  @override
  String get chargeTrialNote =>
      'You\'ll get a reminder the day before it starts charging.';

  @override
  String get chargeInUseAsk => 'Do you still use it?';

  @override
  String get chargeInUseYes => 'Yes, I use it';

  @override
  String get chargeInUseNo => 'Not anymore';

  @override
  String get chargeInUseNote =>
      'A charge that repeats doesn\'t say whether you use it: only you know that.';

  @override
  String chargeYearly(String amount) {
    return 'That\'s $amount a year.';
  }

  @override
  String chargeSaving(String amount) {
    return 'Pausing it saves you $amount a year. Quincena doesn\'t cancel it: do that in the service\'s app or website.';
  }

  @override
  String get chargeIncomplete => 'The name or the amount is missing.';

  @override
  String get chargeRemindDenied =>
      'No permission to remind you. If you want the reminder, turn on Quincena\'s notifications in your phone\'s settings.';

  @override
  String get chargePause => 'Pause';

  @override
  String get chargeResume => 'Resume';

  @override
  String get chargePauseNote =>
      'Pausing here only stops counting it in upcoming payments. To stop the charges, cancel with the service.';

  @override
  String get chargeDelete => 'Delete recurring payment';

  @override
  String chargeDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get chargeDeleteBody =>
      'It\'s no longer counted in upcoming payments. Charges you already recorded stay.';

  @override
  String get fixedTitle => 'Recurring payments';

  @override
  String get fixedBody =>
      'Charges that repeat every month or year: subscriptions, rent, utilities. Quincena takes them out of what you can spend before they\'re due.';

  @override
  String get fixedEmpty =>
      'No recurring payments yet. Add rent, internet or a subscription to see them coming.';

  @override
  String get fixedNext30 => 'In the next 30 days';

  @override
  String get fixedSubscriptionsYear => 'Subscriptions a year';

  @override
  String get guessTitle => 'These look like recurring payments';

  @override
  String guessEvidence(int count, String amount, String dates) {
    return '$count similar charges, the last one $amount: $dates';
  }

  @override
  String get guessAdd => 'Add as a recurring payment';

  @override
  String get guessNot => 'Not recurring';

  @override
  String get fixedSubscriptions => 'Subscriptions';

  @override
  String get fixedOthers => 'Other recurring payments';

  @override
  String get fixedPausedTitle => 'Paused';

  @override
  String get fixedNote =>
      'Quincena never pays or cancels anything: that is done with your bank or each service.';

  @override
  String fixedNextOn(String date) {
    return 'next on $date';
  }

  @override
  String get fixedPaused => 'paused';

  @override
  String fixedTrial(String date) {
    return 'Free trial until $date';
  }

  @override
  String fixedNotUsed(String amount) {
    return 'You said you no longer use it: pausing it saves $amount a year';
  }

  @override
  String fixedPriceUp(String from, String to, String date) {
    return 'Went up from $from to $to on $date';
  }

  @override
  String fixedPriceDown(String from, String to, String date) {
    return 'Went down from $from to $to on $date';
  }

  @override
  String fixedFollowLast(String amount) {
    return 'Update to $amount, like the last charge';
  }

  @override
  String get fixedReminds => 'With a reminder';

  @override
  String get instalTitle => 'Installment purchases';

  @override
  String get instalAdd => 'Add an installment purchase';

  @override
  String get instalEdit => 'Edit installment purchase';

  @override
  String get instalBody =>
      'What you bought in installments, with the figures the bank or the store gave you. What you don\'t know stays an estimate, never a final figure.';

  @override
  String get instalEmpty => 'No installment purchases yet.';

  @override
  String get instalCardNote =>
      'If you paid with a card you have in Quincena, the purchase counts once, on the day you made it. Paying the card moves money between your accounts; it is not a new expense.';

  @override
  String get instalOwed => 'Left to pay';

  @override
  String get instalOwedKnown => 'From the figures you gave.';

  @override
  String get instalOwedEstimated =>
      'Estimated: a figure from the bank is missing.';

  @override
  String instalOwedUnknown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count purchases have no figures to work from.',
      one: 'One purchase has no figures to work from.',
    );
    return '$_temp0';
  }

  @override
  String get instalList => 'Your purchases';

  @override
  String get instalNoData => 'The rate or the installment amount is missing';

  @override
  String get instalPaidOff => 'Paid off';

  @override
  String instalNextRow(int number, int count, String date) {
    return 'Installment $number of $count: $date';
  }

  @override
  String get instalEstimated => 'estimated';

  @override
  String get instalUnknown => 'Unknown';

  @override
  String get instalTotalUnknown =>
      'Without the rate or the installment amount, the total can\'t be calculated.';

  @override
  String instalTotalKnown(String amount) {
    return 'In total you\'ll pay $amount, from the figures you gave.';
  }

  @override
  String instalTotalEstimated(String amount) {
    return 'In total you\'ll pay about $amount: an estimate, since the fee or insurance is missing.';
  }

  @override
  String instalVsCash(String cash, String extra) {
    return 'Paying up front cost $cash; in installments you pay $extra more.';
  }

  @override
  String instalVsCashAtLeast(String cash, String extra) {
    return 'Paying up front cost $cash; in installments you pay at least $extra more.';
  }

  @override
  String instalVsCashSame(String cash) {
    return 'Paying up front cost $cash; installments cost you nothing extra.';
  }

  @override
  String instalProgress(int covered, int count) {
    return '$covered of $count installments paid';
  }

  @override
  String instalOwing(int number, String amount) {
    return 'Installment $number still needs $amount.';
  }

  @override
  String instalLate(int number, String date) {
    return 'Installment $number was due on $date. If you paid it, record it to keep count.';
  }

  @override
  String get instalPay => 'Record a payment';

  @override
  String get instalFacts => 'What the bank said';

  @override
  String get instalFinanced => 'Amount financed';

  @override
  String get instalCount => 'Installments';

  @override
  String get instalRate => 'Rate';

  @override
  String instalRateValue(String rate, String kind, String monthly) {
    return '$rate $kind ($monthly a month)';
  }

  @override
  String get instalNotKnown => 'Unknown';

  @override
  String get instalPayment => 'Installment';

  @override
  String instalPaymentStated(String amount) {
    return '$amount, as the bank said';
  }

  @override
  String instalPaymentWorked(String amount) {
    return '$amount, calculated from the rate';
  }

  @override
  String get instalFee => 'Fee or insurance';

  @override
  String get instalNoFee => 'None';

  @override
  String get instalPaysFrom => 'Paid with';

  @override
  String get instalOutside => 'Outside Quincena: a store or a loan';

  @override
  String get instalCountedOnce =>
      'The purchase is already in that account, so its installments aren\'t counted again.';

  @override
  String get instalCountedAsComing =>
      'Upcoming installments are counted as payments due.';

  @override
  String get instalPayments => 'Payments';

  @override
  String get instalNoPayments => 'No payments recorded yet.';

  @override
  String get instalPaymentRemove => 'Remove this payment';

  @override
  String get instalPaymentRemoveTitle => 'Remove this payment?';

  @override
  String instalPaymentRemoveBody(String amount) {
    return 'What\'s left to pay goes back up by $amount.';
  }

  @override
  String instalPaymentRemoveEntry(String amount, String account) {
    return 'Its $amount transaction in $account is deleted too.';
  }

  @override
  String get instalPaymentRemoveGo => 'Remove payment';

  @override
  String get instalSchedule => 'Installment schedule';

  @override
  String get instalNoSchedule =>
      'The schedule needs the rate or the installment amount.';

  @override
  String instalRow(int number, String date) {
    return 'Installment $number · $date';
  }

  @override
  String instalRowSplit(String interest, String principal, String balance) {
    return 'Interest $interest · principal $principal · $balance left';
  }

  @override
  String instalRowLeft(String balance) {
    return '$balance left';
  }

  @override
  String get instalRowPaid => 'Paid';

  @override
  String get instalPaymentAmount => 'Amount paid';

  @override
  String get instalPaymentInvalid => 'Type how much you paid.';

  @override
  String get instalPaymentPartial =>
      'It can be less than the installment: what\'s missing stays owed.';

  @override
  String get instalPaymentFrom => 'Where did it come from?';

  @override
  String get instalPaymentNoAccount => 'Don\'t record it in an account';

  @override
  String instalPaidWithCard(String card) {
    return 'This purchase is on $card: the installment comes out when you pay the card.';
  }

  @override
  String instalOnCardTitle(String card) {
    return 'Is the purchase on $card yet?';
  }

  @override
  String instalOnCardBody(String amount, String card) {
    return 'We didn\'t find a purchase of $amount on $card. What you owe on the card includes it only once it is written down, and its installments are not counted apart.';
  }

  @override
  String get instalOnCardAlready => 'It\'s there';

  @override
  String get instalOnCardWrite => 'Write it down';

  @override
  String instalPaymentAfter(String left) {
    return 'After it, $left will be left to pay.';
  }

  @override
  String instalPaymentAccountDown(String account, String amount) {
    return '$account goes down by $amount.';
  }

  @override
  String get instalDelete => 'Delete purchase';

  @override
  String instalDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get instalDeleteBody =>
      'Its figures and payments here are deleted. Your transactions stay as they are.';

  @override
  String get instalSheetBody =>
      'Copy the figures from the statement or the contract. Leave empty what you don\'t know.';

  @override
  String get instalName => 'What did you buy?';

  @override
  String get instalPrincipal => 'Amount financed';

  @override
  String get instalCountField => 'Number of installments';

  @override
  String instalFirstDue(String date) {
    return 'First installment: $date';
  }

  @override
  String get instalRateField => 'Interest rate';

  @override
  String get instalRateKind => 'Stated as';

  @override
  String get instalRateHelp =>
      'As the statement says: effective annual (EAR), nominal annual paid monthly (APR) or monthly. A rate of 0 is a figure too: no interest.';

  @override
  String get rateEffectiveAnnual => 'EAR';

  @override
  String get rateNominalMonthly => 'APR';

  @override
  String get rateMonthly => 'monthly';

  @override
  String get instalStated => 'Installment amount, if you were told';

  @override
  String get instalStatedHelp =>
      'Without the fee. If you don\'t know it, it\'s calculated from the rate.';

  @override
  String get instalFeeField => 'Fee or insurance, per installment';

  @override
  String get instalFeeHelp =>
      'Type 0 if there is none. If you don\'t know, leave it empty: the total will be an estimate.';

  @override
  String get instalCash => 'Price if paid up front';

  @override
  String get instalCashHelp => 'To compare what installments cost.';

  @override
  String get instalIncomplete =>
      'The name, the amount financed or the number of installments is missing.';

  @override
  String get detectiveTitle => 'Charges to check';

  @override
  String get detectiveBody =>
      'Quincena looks at your last 60 days of transactions, here on the phone, and shows what\'s worth a look, with the evidence. It never deletes a transaction or calls anything fraud.';

  @override
  String get detectiveEmpty => 'Nothing to check for now.';

  @override
  String get detectiveOpen => 'To check';

  @override
  String get detectiveReviewing => 'You\'ll look into these';

  @override
  String detectiveShowPutAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show the $count you put away',
      one: 'Show the one you put away',
    );
    return '$_temp0';
  }

  @override
  String get detectiveHidePutAway => 'Hide the ones you put away';

  @override
  String get detectiveWhat => 'What to check';

  @override
  String get detectiveKindTwice => 'Repeated payments';

  @override
  String get detectiveKindPriceUp => 'Price increases';

  @override
  String get detectiveKindUnusual => 'Unusual charges';

  @override
  String get detectiveRuleTwice =>
      'Same amount, merchant and account, less than a day and a half apart.';

  @override
  String get detectiveRulePriceUp =>
      'A merchant that charged the same on at least two different days and went up 5% or more the last time.';

  @override
  String get detectiveRuleUnusual =>
      'A charge three times or more what you usually spend in that category and account.';

  @override
  String get detectiveTwiceSeenTitle => 'It may be one payment seen twice';

  @override
  String detectiveTwiceSeenWhy(String first, String second) {
    return 'Same amount, merchant and account, close together, but they came two ways: $first and $second. Most likely it\'s one payment recorded twice. If one is extra, open it and delete it yourself.';
  }

  @override
  String get detectiveTwiceTitle => 'Two identical charges, close together';

  @override
  String get detectiveTwiceWhy =>
      'Same amount, merchant and account, and they came the same way: they may be two real charges. If you made one purchase, check with your bank.';

  @override
  String detectivePriceUpTitle(String merchant) {
    return '$merchant charges more than before';
  }

  @override
  String detectivePriceUpWhy(String before, String now, String percent) {
    return 'It used to charge $before and the last charge was $now, $percent more. Going up doesn\'t mean it\'s wrong: it may be a new plan or rate.';
  }

  @override
  String detectiveUnusualTitle(String category) {
    return 'Far more than usual in $category';
  }

  @override
  String detectiveUnusualWhy(String times, String category) {
    return 'It\'s about $times times what you usually spend per purchase in $category in this account. It may be a big purchase you planned.';
  }

  @override
  String get detectiveExpected => 'Expected';

  @override
  String get detectiveReview => 'I\'ll look into it';

  @override
  String get detectiveDismiss => 'Dismiss';

  @override
  String get detectiveShowAgain => 'Show again';

  @override
  String get sourceManual => 'By hand';

  @override
  String get sourceStatement => 'Statement';

  @override
  String get sourceGemini => 'Conversation with Gemini';

  @override
  String get sourceOther => 'Another source';

  @override
  String get originManual => 'Entered by hand';

  @override
  String get originApplePay => 'From Apple Pay';

  @override
  String get originNotification => 'From a notification';

  @override
  String originNotificationOf(String name) {
    return 'From a $name notification';
  }

  @override
  String get originSms => 'From a text message';

  @override
  String originSmsOf(String name) {
    return 'From a $name text message';
  }

  @override
  String get originEmail => 'From an email';

  @override
  String originEmailOf(String name) {
    return 'From a $name email';
  }

  @override
  String get originScreenshot => 'From a screenshot';

  @override
  String get originPaste => 'From a message you pasted';

  @override
  String get originStatement => 'From a statement';

  @override
  String get originBinance => 'From Binance';

  @override
  String get originWallet => 'From a wallet you follow';

  @override
  String get originGemini => 'From a conversation with Gemini';

  @override
  String get originExample => 'From the example\'s conversation';

  @override
  String planFixedNext30(String amount) {
    return '$amount in the next 30 days';
  }

  @override
  String planFixedGuesses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count look like recurring payments',
      one: 'One looks like a recurring payment',
    );
    return '$_temp0';
  }

  @override
  String get planFixedNone => 'Rent, utilities, subscriptions';

  @override
  String get planInstalNone => 'None recorded';

  @override
  String planInstalOwed(String amount) {
    return '$amount left to pay';
  }

  @override
  String planInstalOwedEstimated(String amount) {
    return 'About $amount left to pay';
  }

  @override
  String planDetective(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count charges to check',
      one: 'One charge to check',
    );
    return '$_temp0';
  }

  @override
  String get planDetectiveNone => 'Nothing odd for now';

  @override
  String get computedCommitments => 'What\'s already due in the next 30 days';

  @override
  String comingIncome(String client) {
    return 'Expected payment: $client';
  }

  @override
  String get computedOwed =>
      'What you\'re owed, your clients\' payments and your trips';

  @override
  String get freeExplainReserved => 'Kept from variable income';

  @override
  String get messageCopied =>
      'Message copied: paste it wherever you want to send it.';

  @override
  String get rateSourceManual => 'your rate';

  @override
  String get planSharedNone => 'Split a bill or note what you lent';

  @override
  String planShared(String owed, String owing) {
    return 'You\'re owed $owed · you owe $owing';
  }

  @override
  String get planFreelanceNone =>
      'Pending and estimated payments, and a reserve';

  @override
  String planFreelance(String amount) {
    return '$amount to collect';
  }

  @override
  String planFreelanceLate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count late payments',
      one: 'One late payment',
    );
    return '$_temp0';
  }

  @override
  String get planTripsNone => 'A budget in the trip\'s currency';

  @override
  String planTripLeft(String trip, String amount) {
    return '$trip: $amount left';
  }

  @override
  String get splitTitle => 'Split an expense';

  @override
  String get splitBody =>
      'Nobody else needs the app: type their names. What you\'re owed doesn\'t count as money to spend until it\'s paid.';

  @override
  String get splitGroup => 'Group';

  @override
  String get splitNewGroup => 'A new group';

  @override
  String get splitWithWhom => 'Who are you splitting with?';

  @override
  String get splitWithWhomHelp => 'Names separated by commas: Ana, Juan';

  @override
  String get splitGroupName => 'Group name';

  @override
  String get splitWhat => 'What was it?';

  @override
  String get splitAmount => 'Total amount';

  @override
  String get splitFromEntry => 'From the transaction; it doesn\'t change here.';

  @override
  String get splitPaidBy => 'Who paid?';

  @override
  String get splitEven => 'Evenly';

  @override
  String get splitCustom => 'By amounts';

  @override
  String splitPartOf(String name) {
    return '$name\'s part';
  }

  @override
  String splitRest(String amount, String name) {
    return 'So the total adds up, the $amount left by rounding goes to $name\'s part.';
  }

  @override
  String splitRestYou(String amount) {
    return 'So the total adds up, the $amount left by rounding goes to your part.';
  }

  @override
  String get splitPartYou => 'Your part';

  @override
  String splitMissing(String amount) {
    return '$amount short of the total';
  }

  @override
  String splitOver(String amount) {
    return '$amount over the total';
  }

  @override
  String splitYourPart(String mine, String others) {
    return 'Your part is $mine; you\'re owed $others.';
  }

  @override
  String get splitIncomplete => 'The amount or who to split with is missing.';

  @override
  String get splitDoesNotAddUp => 'The parts don\'t add up to the total.';

  @override
  String get splitNeedsSomeone => 'Add at least one more person.';

  @override
  String get splitNeedsShare => 'Tick at least one other person with a share.';

  @override
  String get splitRemove => 'Remove the split';

  @override
  String get splitThis => 'Split this expense';

  @override
  String get splitChange => 'Change the split';

  @override
  String splitYours(String amount) {
    return 'Your part $amount';
  }

  @override
  String get sharedTitle => 'Shared expenses';

  @override
  String get sharedBody =>
      'Split expenses with anyone, no app needed on their side. What you\'re owed isn\'t money to spend: it is again once they pay you.';

  @override
  String get sharedEmpty =>
      'No shared expenses yet. Create a group, or open an expense in Transactions and tap \"Split this expense\".';

  @override
  String get sharedNewGroup => 'New group';

  @override
  String get sharedEditGroup => 'Edit group';

  @override
  String get sharedGroupName => 'Group name';

  @override
  String get sharedAddPeople => 'Add people';

  @override
  String get sharedGroupIncomplete =>
      'The name or someone else in the group is missing.';

  @override
  String get sharedOwedToYou => 'You\'re owed';

  @override
  String get sharedYouOwe => 'You owe';

  @override
  String get sharedNotCash =>
      'What you\'re owed isn\'t counted as money to spend until it\'s paid back.';

  @override
  String get sharedGroups => 'Groups';

  @override
  String sharedOwesYouShort(String amount) {
    return 'You\'re owed $amount';
  }

  @override
  String sharedYouOweShort(String amount) {
    return 'You owe $amount';
  }

  @override
  String get sharedEven => 'All even';

  @override
  String get sharedYou => 'You';

  @override
  String get sharedDelete => 'Delete group';

  @override
  String sharedDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get sharedDeleteBody =>
      'The group, its expenses and its payments are deleted here. Your transactions stay as they are.';

  @override
  String get sharedAddExpense => 'Add expense';

  @override
  String sharedOwedToYouIn(String amount) {
    return 'In this group you\'re owed $amount';
  }

  @override
  String sharedYouOweIn(String amount) {
    return 'In this group you owe $amount';
  }

  @override
  String get sharedAllEven => 'Everyone is even';

  @override
  String get sharedToSettle => 'To settle up';

  @override
  String sharedPaysYou(String name, String amount) {
    return '$name pays you $amount';
  }

  @override
  String sharedYouPay(String name, String amount) {
    return 'You pay $name $amount';
  }

  @override
  String sharedPays(String from, String to, String amount) {
    return '$from pays $to $amount';
  }

  @override
  String get sharedRemind => 'Remind';

  @override
  String sharedReminderMessage(String name, String amount, String group) {
    return 'Hi $name, about the $amount for $group. Whenever you can, send it my way. Thanks!';
  }

  @override
  String get sharedRecordPayment => 'Record payment';

  @override
  String get sharedExpenses => 'Expenses';

  @override
  String get sharedNoExpenses => 'No expenses in this group yet.';

  @override
  String sharedPaidBy(String name) {
    return 'paid by $name';
  }

  @override
  String get sharedPaidByYou => 'paid by you';

  @override
  String sharedYourShare(String amount) {
    return 'your part $amount';
  }

  @override
  String get sharedPayments => 'Payments';

  @override
  String sharedPaid(String from, String to) {
    return '$from paid $to';
  }

  @override
  String sharedPaidYou(String from) {
    return '$from paid you';
  }

  @override
  String sharedYouPaid(String to) {
    return 'You paid $to';
  }

  @override
  String get sharedLinked => 'came into your account';

  @override
  String sharedLeftFrom(String account) {
    return 'left $account';
  }

  @override
  String sharedArrivedIn(String account) {
    return 'came into $account';
  }

  @override
  String get sharedRemovePayment => 'Remove this payment';

  @override
  String get sharedLedgerNote =>
      'Of an expense you paid for others, only your part counts as spending; the rest is money lent. When it comes back it isn\'t income: it\'s money returning.';

  @override
  String get sharedArrivedAs => 'Did it reach one of your accounts?';

  @override
  String get sharedNotRecorded => 'No, or it isn\'t in Quincena';

  @override
  String sharedRecordIn(String account) {
    return 'Record it in $account';
  }

  @override
  String sharedOweLeft(String amount, String name) {
    return 'You\'ll still owe $name $amount.';
  }

  @override
  String sharedEvenWith(String name) {
    return 'You\'ll be even with $name.';
  }

  @override
  String sharedOwesYouLeft(String name, String amount) {
    return '$name will still owe you $amount.';
  }

  @override
  String sharedEvenFrom(String name) {
    return '$name will be even with you.';
  }

  @override
  String sharedAccountUp(String account, String amount) {
    return '$account goes up by $amount.';
  }

  @override
  String get sharedArrivedAsHelp =>
      'If you pick the transaction, it counts as money returning, not as income.';

  @override
  String get freelanceTitle => 'Variable income';

  @override
  String get freelanceBody =>
      'For when your income changes from month to month. It keeps collected, pending and estimated apart. Quincena doesn\'t calculate taxes: you choose the reserve.';

  @override
  String get freelanceAdd => 'Add payment';

  @override
  String get freelanceEdit => 'Payment';

  @override
  String get freelancePending => 'To collect';

  @override
  String get freelanceEstimated => 'Estimated';

  @override
  String get freelanceReserve => 'Reserve';

  @override
  String freelanceOverdueNote(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count late payments of $amount.',
      one: 'One late payment of $amount.',
    );
    return '$_temp0';
  }

  @override
  String get freelanceOverdue => 'Late';

  @override
  String get freelancePendingList => 'Pending';

  @override
  String get freelanceEstimatedList => 'Estimated';

  @override
  String get freelanceCollectedList => 'Collected';

  @override
  String get freelanceScenario => 'What to count in the days ahead';

  @override
  String get scenarioCollected => 'Collected';

  @override
  String get scenarioPending => 'Billed';

  @override
  String get scenarioEstimated => 'All';

  @override
  String get scenarioCollectedBody =>
      'Only the money you already have. The most careful choice for a hard month.';

  @override
  String get scenarioPendingBody =>
      'Also what you\'ve billed, on the day you expect it. If it\'s late, it moves to the next day, and it never counts as money to spend until it arrives.';

  @override
  String get scenarioEstimatedBody =>
      'Also what you think will come without billing it yet. The least careful choice: use it with care.';

  @override
  String get freelanceReservePercent => 'Keep from each payment';

  @override
  String get freelanceNoReserve => 'Nothing';

  @override
  String freelanceReserveNow(String amount, String date) {
    return 'You\'ve set aside $amount since $date. It stays in your accounts but isn\'t counted as money to spend.';
  }

  @override
  String get freelanceReserveOff =>
      'No reserve: everything you collect counts as money to spend.';

  @override
  String get freelanceNoTax =>
      'Quincena doesn\'t calculate taxes or know what you owe: the percentage is up to you.';

  @override
  String get freelanceUse => 'I used some of the reserve';

  @override
  String get freelanceUseAmount => 'How much did you use?';

  @override
  String get freelanceUseHelp =>
      'For example, what you paid in taxes or social security.';

  @override
  String freelanceExpectedOn(String date) {
    return 'Expected on $date';
  }

  @override
  String freelanceCollectedOn(String date) {
    return 'Collected on $date';
  }

  @override
  String freelanceLate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days late: due on $date',
      one: 'One day late: due on $date',
    );
    return '$_temp0';
  }

  @override
  String get freelanceClient => 'Who pays you?';

  @override
  String get freelanceAmount => 'Amount';

  @override
  String get incomeEstimated => 'Estimated';

  @override
  String get incomePending => 'Billed';

  @override
  String get incomeCollected => 'Collected';

  @override
  String get incomeEstimatedHelp =>
      'You think it will come, but you haven\'t billed it yet.';

  @override
  String get incomePendingHelp => 'You\'ve billed it and expect the payment.';

  @override
  String get incomeCollectedHelp => 'The money arrived.';

  @override
  String get freelanceArrivedAs => 'Which transaction was it?';

  @override
  String get freelanceNote => 'Note';

  @override
  String get freelanceIncomplete => 'Who pays you or the amount is missing.';

  @override
  String get freelanceRemind => 'Remind the client';

  @override
  String freelanceReminderMessage(String client, String amount, String date) {
    return 'Hi $client, about the $amount payment I expected on $date. Could you confirm when you can make it? Thanks!';
  }

  @override
  String get freelanceDelete => 'Delete payment';

  @override
  String get tripsTitle => 'Trips';

  @override
  String get tripsBody =>
      'A budget in the trip\'s currency, counted from your own transactions: nothing is copied.';

  @override
  String get tripsEmpty => 'No trips yet.';

  @override
  String get tripsNew => 'New trip';

  @override
  String get tripEdit => 'Edit trip';

  @override
  String get tripDelete => 'Delete trip';

  @override
  String tripDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get tripDeleteBody =>
      'The trip is deleted here. Its expenses stay in your accounts.';

  @override
  String tripLeftShort(String amount) {
    return '$amount left';
  }

  @override
  String tripSpentShort(String amount) {
    return 'Spent $amount';
  }

  @override
  String get tripSpent => 'You spent';

  @override
  String get tripLeft => 'You have left';

  @override
  String tripOf(String amount) {
    return 'of $amount';
  }

  @override
  String tripPerDay(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'You can spend $amount a day for the $days days left.',
      one: 'You can spend $amount today, the last day.',
    );
    return '$_temp0';
  }

  @override
  String tripAverage(String amount) {
    return 'You\'re spending $amount a day on average.';
  }

  @override
  String get tripOver => 'The trip is over.';

  @override
  String tripUnconverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count expenses have no rate to convert them and aren\'t counted.',
      one: 'One expense has no rate to convert it and isn\'t counted.',
    );
    return '$_temp0';
  }

  @override
  String get tripShared => 'The trip\'s shared expenses';

  @override
  String get tripShare => 'Split the trip\'s expenses with someone';

  @override
  String get tripExpenses => 'The trip\'s expenses';

  @override
  String get tripNoExpenses =>
      'Expenses on the trip\'s dates show up here on their own. Add the ones you paid there in its currency.';

  @override
  String get tripIncludeEarlier => 'Include an expense from before';

  @override
  String get tripIncludeEarlierBody =>
      'The flight or the hotel you paid before leaving.';

  @override
  String get tripNothingEarlier =>
      'No expenses in the 120 days before the trip.';

  @override
  String get tripSameMovements =>
      'A trip uses your own transactions: changing one here changes it in your account.';

  @override
  String get tripNoRate => 'No rate';

  @override
  String get tripExclude => 'Not part of the trip';

  @override
  String tripForeign(
    String amount,
    String rate,
    String date,
    String fee,
    String estimate,
  ) {
    return '$amount at $rate ($date) plus $fee from the card: $estimate estimated';
  }

  @override
  String tripForeignNoFee(
    String amount,
    String rate,
    String date,
    String estimate,
  ) {
    return '$amount at $rate ($date): $estimate estimated';
  }

  @override
  String tripConverted(String amount, String source, String date) {
    return '$amount, converted with $source of $date';
  }

  @override
  String tripChargedMore(String charged, String difference) {
    return 'The bank charged $charged: $difference more than estimated';
  }

  @override
  String tripChargedLess(String charged, String difference) {
    return 'The bank charged $charged: $difference less than estimated';
  }

  @override
  String get tripAdjust => 'Set to the real charge';

  @override
  String get tripSplit => 'Split';

  @override
  String tripSplitWith(String names) {
    return 'Split with $names';
  }

  @override
  String get tripCharged => 'How much did the bank charge?';

  @override
  String get tripAdjustHelp =>
      'The transaction changes to what the statement says, and the difference from the estimate is kept.';

  @override
  String get tripName => 'Where are you going?';

  @override
  String get tripCurrency => 'The trip\'s currency';

  @override
  String get tripBudget => 'Budget';

  @override
  String get tripFee => 'Your card\'s fee abroad';

  @override
  String get tripFeeHelp =>
      'If you know it: it\'s added when estimating what you\'ll be charged.';

  @override
  String get tripFeeShort => 'Fee';

  @override
  String get tripIncomplete => 'Where you are going is missing.';

  @override
  String get tripAddExpense => 'Add trip expense';

  @override
  String get tripWhat => 'What for?';

  @override
  String get tripAmount => 'Amount';

  @override
  String get tripPaidWith => 'Paid with';

  @override
  String tripRate(String from, String to) {
    return '1 $from in $to';
  }

  @override
  String get tripRateNone => 'No saved rate: type the one you saw.';

  @override
  String tripRateFrom(String source, String date) {
    return '$source of $date';
  }

  @override
  String tripWillRecord(String amount, String account) {
    return '$amount is recorded in $account, estimated until the real charge arrives.';
  }

  @override
  String get tripExpenseIncomplete => 'The amount or the rate is missing.';

  @override
  String get syncTitle => 'More than one device';

  @override
  String get syncRow => 'Your data on another phone or computer, encrypted';

  @override
  String get syncBody =>
      'Use Quincena on more than one device with the same data. Changes travel in an encrypted file you move yourself, by AirDrop, Files or a chat with yourself: only your devices can open it, and Quincena never receives it.';

  @override
  String get syncNotBackup =>
      'Syncing isn\'t a backup: it brings your devices\' changes together. To keep a copy of everything, use Export in Settings.';

  @override
  String get syncNotOnWeb => 'Syncing is in the phone and computer apps.';

  @override
  String get syncStart => 'Start on this device';

  @override
  String get syncJoin => 'Join this device';

  @override
  String get syncHow =>
      'Start on the device that already has your data and share or copy the code. On the other, tap \"Join this device\" and paste it.';

  @override
  String get syncYourCode => 'Your sync code';

  @override
  String get syncNewCode => 'Your new sync code';

  @override
  String get syncCodeKeep =>
      'With this code you join your other devices. Keep it where you keep your passwords: if you lose every device and the code, no one can open the files, not even Quincena.';

  @override
  String get syncCopyCode => 'Copy the code';

  @override
  String get syncShareCode => 'Share the code';

  @override
  String syncCodeShareText(String code) {
    return 'Quincena code to join your devices: $code';
  }

  @override
  String get syncCodeCopied => 'Code copied.';

  @override
  String get syncDone => 'Done';

  @override
  String get syncJoinBody =>
      'Paste the code you copied or shared from your other device, in Settings, More than one device, or type it. Dashes do not matter.';

  @override
  String get syncCodeField => 'Code';

  @override
  String get codePaste => 'Paste';

  @override
  String get codeNothingCopied =>
      'There\'s nothing copied. Copy the code from where you kept it, or type it.';

  @override
  String get syncJoinAction => 'Join';

  @override
  String get syncCodeLength =>
      'The code has too many or too few characters: it has 54.';

  @override
  String get syncCodeCharacter =>
      'There is a character the code doesn\'t use. Check it isn\'t a U.';

  @override
  String get syncCodeCheck =>
      'The code doesn\'t check out: look for a mistyped character.';

  @override
  String get syncCodeIsBackup =>
      'That\'s your backup code, not your sync code. To join this device, use the code your other device shows in More than one device.';

  @override
  String get syncJoined =>
      'Done. Now open a file from your other device to bring your data.';

  @override
  String get syncSend => 'Save my changes in a file';

  @override
  String get syncOpen => 'Open a file from another device';

  @override
  String get syncSendHow =>
      'Save the file where your other device can find it, or send it to yourself, and open it there. Each file carries everything, so the latest is enough.';

  @override
  String get syncSaved => 'File saved. Open it on your other device.';

  @override
  String get syncUpToDate => 'Everything was already up to date.';

  @override
  String syncArrivedOne(String items) {
    return 'Received $items.';
  }

  @override
  String syncArrivedMany(String items) {
    return 'Received $items.';
  }

  @override
  String syncGoneOne(String items) {
    return 'Deleted $items.';
  }

  @override
  String syncGoneMany(String items) {
    return 'Deleted $items.';
  }

  @override
  String syncItemMovements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: 'one transaction',
    );
    return '$_temp0';
  }

  @override
  String syncItemAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: 'one account',
    );
    return '$_temp0';
  }

  @override
  String syncItemPlan(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Plan changes',
      one: 'one Plan change',
    );
    return '$_temp0';
  }

  @override
  String syncItemSettings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count settings',
      one: 'one setting',
    );
    return '$_temp0';
  }

  @override
  String syncWaitingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count are waiting in \"Changes to review\".',
      one: 'One is waiting in \"Changes to review\".',
    );
    return '$_temp0';
  }

  @override
  String get syncNotSync => 'That isn\'t a Quincena sync file.';

  @override
  String get syncIsBackup =>
      'That\'s a backup, not a sync file: it opens in Settings, \"Restore a backup\". Nothing changed.';

  @override
  String get syncOtherVault =>
      'That file was made with another code. Open one from a device joined with this code.';

  @override
  String get syncNewer => 'That file is from a newer Quincena: update the app.';

  @override
  String get syncDamaged =>
      'The file is damaged or cut: save it again on the other device. Nothing changed.';

  @override
  String get syncWaiting => 'Changes to review';

  @override
  String get syncWaitingBody =>
      'Changes that didn\'t stay because another device changed the same thing. Nothing was lost: you can bring them back.';

  @override
  String get syncWhyEditedBoth =>
      'Changed here and on another device; the latest stayed.';

  @override
  String get syncWhyDeletedElsewhere =>
      'You changed it here, but it was deleted on another device.';

  @override
  String get syncWhyDeletedHere =>
      'You deleted it here; this is how another device had changed it.';

  @override
  String get syncWhyWithAccount => 'Its account was deleted on a device.';

  @override
  String get syncWhatProfile => 'Your profile';

  @override
  String get syncWhatSetting => 'A setting';

  @override
  String get syncRestore => 'Bring back';

  @override
  String get syncDismiss => 'Dismiss';

  @override
  String get syncDismissed => 'Dismissed.';

  @override
  String get syncKept => 'What stayed';

  @override
  String get syncWaitingVersion => 'What\'s waiting';

  @override
  String get syncSameFields => 'Both versions read the same in what shows.';

  @override
  String get syncCombine => 'Combine';

  @override
  String get syncCombineTitle => 'Combine both changes';

  @override
  String get syncCombineBody =>
      'Choose what stays in each detail that changed.';

  @override
  String get syncCombined =>
      'Combined. Your other devices get it with the next file.';

  @override
  String get syncFieldName => 'Name';

  @override
  String get syncFieldNote => 'Note';

  @override
  String get syncFieldInstitution => 'Bank';

  @override
  String get syncFieldOpening => 'Opening balance';

  @override
  String get syncFieldLimit => 'Credit limit';

  @override
  String get syncFieldCadence => 'How often';

  @override
  String get syncFieldNext => 'Next charge';

  @override
  String get syncFieldState => 'Status';

  @override
  String get syncActive => 'Active';

  @override
  String get syncPaused => 'Paused';

  @override
  String get syncFieldTarget => 'Target';

  @override
  String get syncFieldSaved => 'Saved';

  @override
  String get syncFieldMonthly => 'Each month';

  @override
  String get syncRestored =>
      'Back. Your other devices get it with the next file.';

  @override
  String get syncThisDevice => 'This device';

  @override
  String get syncShowCode => 'Show the code';

  @override
  String get syncChange => 'Change the code';

  @override
  String get syncChangeTitle => 'Change the code?';

  @override
  String get syncChangeBody =>
      'Files you save from now on open only with the new code; join the devices you want to keep with it. Files you already sent still open with the old one.';

  @override
  String get syncStop => 'Stop syncing';

  @override
  String get syncStopTitle => 'Stop syncing here?';

  @override
  String get syncStopBody =>
      'This device forgets the code. Your data stays here.';

  @override
  String get syncWhyReplaced =>
      'What was there before you brought another version back.';

  @override
  String get syncWhyDuplicate =>
      'It arrived twice from the same statement or from Binance; one stayed.';

  @override
  String get reportAnswer => 'Report';

  @override
  String get reportSent => 'Reported';

  @override
  String get reportTitle => 'Report this answer';

  @override
  String get reportWhy => 'What\'s wrong with it?';

  @override
  String get reportOffensive => 'It\'s offensive or inappropriate';

  @override
  String get reportWrong => 'It\'s wrong or misleading';

  @override
  String get reportOther => 'Something else';

  @override
  String get reportComment => 'Tell us more (optional)';

  @override
  String get reportWhat =>
      'DL SOFT receives your question, this answer with its figures, and what you write here; nothing else from your account, and no identifier of yours. Reports are deleted after 90 days.';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportSending => 'Sending…';

  @override
  String get reportFailed =>
      'It couldn\'t be sent. Check your connection and try again.';

  @override
  String get reportThanks => 'Thanks. We\'ll look into this answer.';

  @override
  String get standingCanSpend => 'You can spend';

  @override
  String get standingShort => 'You\'re short';

  @override
  String standingUntil(String date) {
    return 'until $date';
  }

  @override
  String standingShortUntil(String date) {
    return 'to reach $date';
  }

  @override
  String standingNextFortnight(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'your pay arrives in $days days',
      one: 'your pay arrives tomorrow',
      zero: 'your pay arrives today',
    );
    return '$_temp0';
  }

  @override
  String standingNextPay(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'your next pay arrives in $days days',
      one: 'your next pay arrives tomorrow',
      zero: 'your pay arrives today',
    );
    return '$_temp0';
  }

  @override
  String get standingAvailable => 'In your everyday accounts';

  @override
  String standingPaymentsBefore(String date) {
    return 'Payments until $date';
  }

  @override
  String get standingCushionLine => 'Safety buffer';

  @override
  String get standingEnvelopesLine => 'Set aside in envelopes';

  @override
  String get standingReserveLine => 'Kept from variable income';

  @override
  String standingShortSemantics(String free, String date, String when) {
    return 'You\'re $free short of $date; $when.';
  }

  @override
  String get homeTodo => 'To do';

  @override
  String get todoReview => 'Review';

  @override
  String get todoSplit => 'Split it';

  @override
  String get paydayArrivedPay => 'Your pay arrived';

  @override
  String get netWorthDetail => 'What you have minus what you owe';

  @override
  String get netWorthSavedLine => 'In savings and investments';

  @override
  String get netWorthCryptoLine => 'In crypto';

  @override
  String get groupCards => 'Credit cards';

  @override
  String cardOwed(String amount) {
    return 'You owe $amount';
  }

  @override
  String cardInFavor(String amount) {
    return '$amount in your favor';
  }

  @override
  String get cardClear => 'Paid off';

  @override
  String get totalExplainHave => 'What you have';

  @override
  String get totalExplainOwe => 'What you owe';

  @override
  String get ratesSeeAll => 'See the rates used';

  @override
  String get cardOwedLabel => 'You owe';

  @override
  String get cardInFavorLabel => 'In your favor';

  @override
  String get whichAccountIn => 'We don\'t know which account it reached.';

  @override
  String get whichAccountOut => 'We don\'t know which account it left.';

  @override
  String get fromOwnAccount => 'Is it from another account of yours?';

  @override
  String get fromOwnAccountOut => 'Did it go to another of your accounts?';

  @override
  String get moveBetween => 'Between your accounts';

  @override
  String moveWhyOwnOut(String account) {
    return 'You moved money to your $account: it isn\'t spending.';
  }

  @override
  String moveWhyOwnIn(String account) {
    return 'It came from your $account: it isn\'t income.';
  }

  @override
  String get moveWhySelf => 'You sent it yourself: it isn\'t income.';

  @override
  String moveWhyBank(String bank, String account) {
    return 'It comes from $bank, where you have $account: it isn\'t income.';
  }

  @override
  String moveWhyCash(String account) {
    return 'An ATM withdrawal moves the money to $account: it isn\'t spending.';
  }

  @override
  String moveWhyCard(String account) {
    return 'It\'s your $account payment: what you bought with it already counted as spending.';
  }

  @override
  String get notMove => 'That\'s not it';

  @override
  String joinedArrival(String to, String from) {
    return 'It arrived in $to: it was the transfer from $from.';
  }

  @override
  String joinedDeparture(String from, String to) {
    return 'It left $from: it was the transfer to $to.';
  }

  @override
  String get transferJoined =>
      'The other notice for the same money was recorded too.';

  @override
  String get moreActions => 'More actions';

  @override
  String statementNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '1 new',
      zero: 'None new',
    );
    return '$_temp0';
  }

  @override
  String statementAlready(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count already there',
      one: '1 already there',
      zero: 'no repeats',
    );
    return '$_temp0';
  }

  @override
  String statementUnsorted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count without a category',
      one: '1 without a category',
    );
    return '$_temp0';
  }

  @override
  String get statementAlreadyUnchecked =>
      'What was already there is unchecked, so it isn\'t counted twice.';

  @override
  String get statementSelectAll => 'Select all';

  @override
  String get statementSelectNone => 'Clear all';

  @override
  String get statementDoneSorted => 'Each one got its category.';

  @override
  String statementDoneUnsorted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count came without a category: tap them to give them one.',
      one: 'One came without a category: tap it to give it one.',
    );
    return '$_temp0';
  }

  @override
  String get statementGiveCategory => 'Without a category';

  @override
  String get statementFinish => 'Done';

  @override
  String get licensesTitle => 'Licenses and credits';

  @override
  String get licensesLegalese =>
      '© 2026 DL SOFT TECHNOLOGIES SAS. Nearby shops come from © OpenStreetMap contributors (ODbL).';

  @override
  String comingFreeLine(String amount, String date) {
    return 'The least you\'ll have free will be $amount on $date.';
  }

  @override
  String comingFreeLineSure(String amount, String date) {
    return 'The least you\'ll have free will be $amount on $date, not counting money you\'re still expecting.';
  }

  @override
  String comingFreeLineToday(String amount) {
    return 'The least you\'ll have free before payday is today\'s: $amount.';
  }

  @override
  String comingShortLine(String amount, String date) {
    return 'On $date you\'d be $amount short.';
  }

  @override
  String comingShortLineSure(String amount, String date) {
    return 'On $date you\'d be $amount short, not counting money you\'re still expecting.';
  }

  @override
  String comingShortLineToday(String amount) {
    return 'You\'re already $amount short today.';
  }

  @override
  String comingKept(String parts) {
    return 'Still kept apart: $parts.';
  }

  @override
  String comingKeptReserve(String amount) {
    return '$amount in your reserve';
  }

  @override
  String comingKeptEnvelopes(String amount) {
    return '$amount in your envelopes';
  }

  @override
  String comingKeptCushion(String amount) {
    return '$amount in your buffer';
  }

  @override
  String get timelineFortnight => 'Your pay';

  @override
  String get timelineCharge => 'A scheduled charge';

  @override
  String get timelineExpected => 'expected';

  @override
  String timelineMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'And $count more before payday.',
      one: 'And one more before payday.',
    );
    return '$_temp0';
  }

  @override
  String get buyAsk => 'Can I afford…?';

  @override
  String get buyAskBody =>
      'Enter a price to see if you can afford it without touching money that\'s already due.';

  @override
  String get buyAskHint => 'Price';

  @override
  String get buyAskGo => 'Check';

  @override
  String get fabMovement => 'Transaction';

  @override
  String goalSoFar(String saved) {
    return '$saved saved';
  }

  @override
  String goalMissing(String missing) {
    return '$missing to go';
  }

  @override
  String get goalReached => 'Goal reached';

  @override
  String goalNeedMark(String amount) {
    return '$amount needed';
  }

  @override
  String askExample(String question) {
    return 'For example: $question';
  }

  @override
  String get askExampleBuy => 'Can I afford headphones for \$350,000?';

  @override
  String askExampleGoal(String name) {
    return 'Will I reach my $name goal?';
  }

  @override
  String get askExampleWeekend => 'How much can I spend this weekend?';

  @override
  String get askExampleCard => 'How much do I owe on the card?';

  @override
  String get askExampleCrypto => 'How is my crypto doing this week?';

  @override
  String get askExampleMost => 'What did I spend the most on this month?';

  @override
  String get chartPerformance => 'Performance';

  @override
  String get chartValue => 'Value';

  @override
  String get chartPerformanceNote =>
      'Only what your coins\' prices did, at today\'s dollar: buying or selling doesn\'t move this line.';

  @override
  String get binancePromiseRead => 'Read only';

  @override
  String get binancePromiseNoWithdraw => 'No withdrawals';

  @override
  String get binancePromiseNoTrade => 'No buy or sell orders';

  @override
  String get binancePromiseDisconnect => 'Disconnect it whenever you want';

  @override
  String ratesFailedAt(String when) {
    return 'Couldn\'t update. Using the ones from $when.';
  }

  @override
  String portfolioPricingFailedAt(String when) {
    return 'Couldn\'t read prices. Showing the ones from $when.';
  }

  @override
  String get chartLoading => 'Updating the chart…';

  @override
  String get loanLentAction => 'I lent';

  @override
  String get loanBorrowedAction => 'I borrowed';

  @override
  String get loanLentTitle => 'I lent someone money';

  @override
  String get loanBorrowedTitle => 'Someone lent me money';

  @override
  String get loanLentWho => 'To whom?';

  @override
  String get loanBorrowedWho => 'Who lent it?';

  @override
  String get loanWhat => 'What for? (optional)';

  @override
  String get loanLabel => 'Loan';

  @override
  String get loanFromAccount => 'Which account did it leave?';

  @override
  String get loanNoAccount => 'Not from my accounts';

  @override
  String get loanToAccount => 'Which account did it come into?';

  @override
  String get loanNoAccountIn => 'It didn\'t come into my accounts';

  @override
  String get loanLentNote =>
      'It counts as money owed to you, not as spending. When they pay it back, record it in the group.';

  @override
  String get loanBorrowedNote =>
      'It counts as money you owe. When you pay it, record it in the group.';

  @override
  String get loanIncomplete => 'Who, or the amount, is missing.';

  @override
  String get statementImporting => 'Importing…';

  @override
  String get exportBody =>
      'One file with everything you have in Quincena: accounts, transactions, plans and settings. Use it to move to another phone or keep a copy.';

  @override
  String get exportSealed => 'Encrypted (recommended)';

  @override
  String get exportSealedBody =>
      'Opens only in Quincena with your backup code. You can keep it in the cloud or send it to yourself and no one else can read it.';

  @override
  String get exportPlain => 'Unencrypted (JSON)';

  @override
  String get exportPlainBody =>
      'Anyone who has the file can read your finances. Use it to take them to another tool.';

  @override
  String get exportAction => 'Export';

  @override
  String get backupShowCode => 'Show my backup code';

  @override
  String get backupYourCode => 'Your backup code';

  @override
  String get backupCodeKeep =>
      'This code opens your encrypted backups, on this phone or another. Keep it where you keep your passwords: without it no one can open them, not even Quincena.';

  @override
  String get backupCodeKept => 'I saved it';

  @override
  String backupCodeShareText(String code) {
    return 'Quincena backup code: $code';
  }

  @override
  String get backupCodeTitle => 'Encrypted backup';

  @override
  String get backupCodeBody =>
      'Paste or type the backup code Quincena showed you the first time you exported encrypted.';

  @override
  String get backupOpen => 'Open';

  @override
  String get backupWrongCode =>
      'That code doesn\'t open this backup. If it\'s your sync code, the backup code is a different one.';

  @override
  String get backupCodeIsSync =>
      'That\'s your sync code, not your backup code. This backup opens with the backup code Quincena showed you when you exported encrypted.';

  @override
  String get backupCodeIsNewer =>
      'That\'s your current backup code, but this backup was made with another one: the one you had before changing it.';

  @override
  String get backupIsSync =>
      'That\'s a sync file: it opens in Settings, More than one device. Nothing was changed.';

  @override
  String get backupChangeCode => 'Change the code';

  @override
  String get backupChangeTitle => 'Change the backup code?';

  @override
  String get backupChangeBody =>
      'Backups you already made still open with the old code; new ones use the new one. Keep both while you have old backups.';

  @override
  String get backupChange => 'Change';

  @override
  String get backupNewCode => 'Your new backup code';

  @override
  String widgetUpdated(String when) {
    return 'Updated $when';
  }

  @override
  String get widgetStale => 'Open Quincena for today\'s figure.';

  @override
  String get widgetSection => 'Home screen widget';

  @override
  String get widgetHow =>
      'To add it, touch and hold an empty spot on your home screen and look for Quincena. It shows what you can spend until your next pay, as of the last time you opened the app.';

  @override
  String get widgetHide => 'Hide amounts in the widget';

  @override
  String get widgetHideHelp => 'It says until when, without the figure.';

  @override
  String get widgetAdd => 'Add to home screen';

  @override
  String get widgetAddFailed =>
      'Your home screen doesn\'t allow adding it from here. Touch and hold an empty spot and look for Quincena.';

  @override
  String get rateManualTag => 'Manual';

  @override
  String rateManualOn(String date) {
    return 'Typed by hand on $date';
  }

  @override
  String rateAutomaticNow(String value) {
    return 'Automatic today: $value';
  }

  @override
  String get rateUseFetchedShort => 'Use automatic rate';

  @override
  String get rateRestoreFailed =>
      'Couldn\'t get the automatic rate. Yours stays; try again when you\'re online.';

  @override
  String rateStepPrice(String asset, String value, String source, String when) {
    return 'Market price: 1 $asset = $value · $source, $when';
  }

  @override
  String rateStepConvert(
    String base,
    String asset,
    String value,
    String source,
    String date,
  ) {
    return 'Conversion to $base: 1 $asset = $value · $source, $date';
  }

  @override
  String rateStepManual(String asset, String value) {
    return '1 $asset = $value · typed by hand';
  }

  @override
  String ratesIntro(String base) {
    return 'This is how we turn what you hold in other currencies into $base. Only totals change, never your account balances.';
  }

  @override
  String ratesManualCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rates typed by hand',
      one: '1 rate typed by hand',
    );
    return '$_temp0';
  }

  @override
  String get portfolioNoData => 'No data';

  @override
  String get portfolioNoData24h => 'No price from 24 hours ago yet.';

  @override
  String get portfolioNoPrice => 'No price';

  @override
  String portfolioDayDetail(String percent) {
    return '$percent from prices';
  }

  @override
  String get portfolioGainMeaning =>
      'What you still hold is worth today minus what you paid for it, in pesos. It includes the dollar\'s move against the peso and Binance fees; what you already sold is shown separately.';

  @override
  String portfolioGainUncosted(String amount) {
    return 'Not counting $amount that came in with no purchase price.';
  }

  @override
  String portfolioConvertedWith(String day) {
    return 'Converted to pesos at the official rate (TRM) of $day';
  }

  @override
  String get portfolioRefresh => 'Refresh';

  @override
  String get portfolioRefreshLabel => 'Refresh prices';

  @override
  String get chartPerformanceNoteFx =>
      'What prices and the dollar against the peso did: buying or selling doesn\'t move this line.';

  @override
  String get portfolioGainMeaningPlain =>
      'What you still hold is worth today minus what you paid for it. It includes Binance fees; what you already sold is shown separately.';

  @override
  String get chartPerformanceNoteFxPlain =>
      'What prices and the dollar against your currency did: buying or selling doesn\'t move this line.';

  @override
  String get freeExplainSpendableSection => 'Your everyday accounts';

  @override
  String get standingCardDebtLine => 'What you owe on cards';

  @override
  String get cardSpendableHelp =>
      'When it\'s on, what you owe on this card comes off what you can spend, since you pay it from your everyday accounts.';

  @override
  String freeExplainAssumePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'It leaves out $count transactions waiting for review. Once you record them, the figure may change.',
      one:
          'It leaves out 1 transaction waiting for review. Once you record it, the figure may change.',
    );
    return '$_temp0';
  }

  @override
  String paydayArrivedAmount(String amount) {
    return 'Your paycheck arrived: $amount';
  }

  @override
  String paydayArrivedPayAmount(String amount) {
    return 'Your pay arrived: $amount';
  }

  @override
  String paydayArrivedDetail(String date, String account) {
    return 'On $date, in $account. Give each part its envelope before you spend.';
  }

  @override
  String listAnd(String a, String b, String sound) {
    return '$a and $b';
  }

  @override
  String get totalExplainOwedToYou => 'Owed to you';

  @override
  String get totalExplainYouOwe => 'You owe other people';

  @override
  String get totalExplainShared => 'Shared expenses and loans';

  @override
  String get totalExplainInstallments => 'Installment purchases';

  @override
  String get totalExplainInstallmentsLeft => 'Left to pay, outside your cards';

  @override
  String paydayArrivedDetailRange(String from, String to, String account) {
    return 'From $from to $to, in $account. Give each part its envelope before you spend.';
  }

  @override
  String get statementSelectNew => 'Check the new ones';

  @override
  String statementRepeatsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You checked $count that were already there: they would count twice.',
      one: 'You checked 1 that was already there: it would count twice.',
    );
    return '$_temp0';
  }

  @override
  String statementSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'Nothing selected',
    );
    return '$_temp0';
  }

  @override
  String statementIn(String amount) {
    return '$amount in';
  }

  @override
  String statementOut(String amount) {
    return '$amount out';
  }

  @override
  String get statementReviewLine => 'Review transaction';

  @override
  String get statementOriginal => 'As the statement shows it';

  @override
  String statementCardPayment(String card) {
    return 'Payment to your $card card';
  }

  @override
  String statementOwnTransferTo(String account) {
    return 'Moves to $account';
  }

  @override
  String statementOwnTransferFrom(String account) {
    return 'Comes from $account';
  }

  @override
  String statementBetweenAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count between your accounts',
      one: '1 between your accounts',
    );
    return '$_temp0';
  }

  @override
  String get statementTransferNote =>
      'A card payment moves money between your own accounts: it doesn\'t count as spending, because the purchases are already on the card.';

  @override
  String get statementIsCardPayment =>
      'Is this a payment to one of your cards?';

  @override
  String get statementAddCard =>
      'This looks like a card payment. Add the card in Accounts so Quincena doesn\'t count what you bought with it twice.';

  @override
  String statementDoneTransfers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count were saved as transfers between your accounts: they don\'t count as spending.',
      one:
          'One was saved as a transfer between your accounts: it doesn\'t count as spending.',
    );
    return '$_temp0';
  }

  @override
  String statementOlder(int count, String date, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions are from before $date',
      one: 'One transaction is from before $date',
    );
    return '$_temp0, when you entered the $account balance.';
  }

  @override
  String get statementOlderKeep =>
      'My balance already includes them (recommended)';

  @override
  String get statementOlderAdd => 'Add them to my balance';

  @override
  String get statementOlderNote =>
      'They\'re saved to show where the money went, without changing what you have today.';

  @override
  String statementEndsAt(String date, String amount) {
    return 'The statement says you had $amount on $date.';
  }

  @override
  String statementMismatch(String amount) {
    return 'Quincena would show $amount that day.';
  }

  @override
  String get statementUseBalance => 'Match the statement\'s balance';

  @override
  String statementBalanceEffect(String account, String before, String after) {
    return '$account balance: $before → $after';
  }

  @override
  String statementFreeChange(String before, String after) {
    return 'You can spend until payday: $before → $after';
  }

  @override
  String statementFreeSame(String amount) {
    return 'You can spend until payday: $amount, the same as before';
  }

  @override
  String statementFreeShort(String amount) {
    return '$amount short';
  }

  @override
  String statementDebtEffect(String account, String before, String after) {
    return 'What you owe on $account: $before → $after';
  }

  @override
  String statementBalanceSame(String account, String amount) {
    return 'The $account balance stays at $amount: it already included these transactions.';
  }

  @override
  String get statementPaidFrom =>
      'Which of your accounts did this payment come from?';

  @override
  String get statementSaveFailed =>
      'The import didn\'t finish. What was saved shows as \"Already imported\".';

  @override
  String get goalTypeAmount => 'Type an amount';

  @override
  String get goalAmountTitle => 'How much do you want to set aside each month?';

  @override
  String get goalAmountUse => 'Use this amount';

  @override
  String get goalAmountInvalid => 'Enter an amount above zero.';

  @override
  String goalUseNeeded(String amount) {
    return 'Use $amount a month';
  }

  @override
  String goalSimulating(String current) {
    return 'Simulation · you set aside $current now';
  }

  @override
  String goalBackToCurrent(String amount) {
    return 'Back to $amount';
  }

  @override
  String goalPlanContributions(
    int count,
    String amount,
    String first,
    String last,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'That\'s $count contributions of $amount, from $first to $last.',
      one: 'That\'s 1 contribution, on $first.',
    );
    return '$_temp0';
  }

  @override
  String get goalEffectTitle => 'How it changes what you can spend';

  @override
  String goalEffectUntilPayday(String payday, String free, String day) {
    return 'You can spend $free until $payday: the contribution goes out on $day, so it doesn\'t touch that.';
  }

  @override
  String goalEffectBeforePay(String day, String payday, String left) {
    return 'The contribution on $day goes out before payday: you could spend $left until $payday.';
  }

  @override
  String goalEffectMore(String payday, String amount) {
    return 'From the pay period starting $payday, you\'d have $amount less a month to spend than now.';
  }

  @override
  String goalEffectLess(String payday, String amount) {
    return 'From the pay period starting $payday, you\'d have $amount more a month to spend than now.';
  }

  @override
  String get goalEffectSame =>
      'It\'s what you already set aside: what you can spend stays the same.';

  @override
  String get goalNeverArrives =>
      'With nothing set aside each month, you don\'t reach the goal.';

  @override
  String goalEffectUntilPaydayShort(String short, String payday, String day) {
    return 'You\'re $short short of $payday. The contribution goes out on $day, after payday.';
  }

  @override
  String goalEffectBeforePayShort(String day, String short, String payday) {
    return 'The contribution on $day goes out before payday: you\'d be $short short of $payday.';
  }

  @override
  String get newConversationShort => 'New';

  @override
  String get conversationCleared => 'You started a new conversation.';

  @override
  String get seeResult => 'See result';

  @override
  String get newAnswerBelow => 'There\'s a new answer below';

  @override
  String get settledExpense => 'Expense saved';

  @override
  String get settledPlan => 'Plan saved';

  @override
  String get settledCancelled => 'Marked as canceled';

  @override
  String settledAt(String what, String time) {
    return '$what · $time';
  }

  @override
  String get cancelPickHint =>
      'Check the ones you want to cancel to see how much you\'d save';

  @override
  String subscriptionSelect(String name) {
    return 'Select $name to cancel';
  }

  @override
  String get subscriptionToCancel => 'To cancel';

  @override
  String get subscriptionCancelled => 'Canceled';

  @override
  String get cardLimitField => 'Credit limit (optional)';

  @override
  String get cardLimitHelp =>
      'With your limit, we show how much credit you have left. It never counts toward what you can spend: it\'s borrowed money.';

  @override
  String cardCreditLeft(String amount) {
    return '$amount credit left';
  }

  @override
  String cardCreditLeftOf(String left, String limit) {
    return '$left of $limit credit left';
  }

  @override
  String get groupCrypto => 'Crypto';

  @override
  String get cryptoPerformanceRow => 'Performance and gains';

  @override
  String get portfolioSources => 'Manage sources';

  @override
  String get binanceRowOff => 'Not connected · read only, never moves funds';

  @override
  String get binanceCardManualBody =>
      'Your Binance balances are entered by hand. Connect it so they update by themselves.';

  @override
  String get portfolioSourceManual =>
      'Entered by hand: doesn\'t update by itself';

  @override
  String portfolioSourceBinance(String when) {
    return 'Connected to Binance · read $when';
  }

  @override
  String get portfolioSourceBinanceNever =>
      'Connected to Binance: updates by itself';

  @override
  String portfolioSourceWallet(String when) {
    return 'By public address · read $when';
  }

  @override
  String get portfolioSourceWalletNever =>
      'By public address: updates by itself';

  @override
  String get chartNow => 'Now';

  @override
  String get chartZero => '0 = where the period started';

  @override
  String chartPointGain(String when, String amount) {
    return '$when: $amount since the start';
  }

  @override
  String chartPointValue(String when, String amount) {
    return '$when: worth $amount';
  }

  @override
  String get chartTouchHint =>
      'Touch the line and slide your finger to see each moment.';

  @override
  String chartSemanticsGain(String range, String amount, String percent) {
    return 'Gain from prices $range: $amount, $percent';
  }

  @override
  String get portfolioSourceBinanceOff => 'Read from Binance · not connected';

  @override
  String get portfolioSourceWalletOff =>
      'Read by public address · no longer followed';

  @override
  String demoBannerTitle(String name) {
    return 'You\'re looking at $name\'s sample account';
  }

  @override
  String get demoBannerBody =>
      'With your own accounts, Quincena tells you what you can spend. They stay on this device only.';

  @override
  String standingNextCharge(String name, String amount, String date) {
    return 'Next: $name, $amount on $date';
  }

  @override
  String todoLatePay(String date) {
    return 'Record your pay from $date';
  }

  @override
  String get todoLatePayBody =>
      'It hasn\'t shown up yet. If it arrived, record it so it counts.';

  @override
  String get todoRecord => 'Record';

  @override
  String todoRates(int count, String codes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No rates yet for $codes',
      one: 'No rate yet for $codes',
    );
    return '$_temp0';
  }

  @override
  String todoRatesBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Until then they count as zero in your totals.',
      one: 'Until then it counts as zero in your totals.',
    );
    return '$_temp0';
  }

  @override
  String get todoSeeRates => 'See rates';

  @override
  String get standingProvisional =>
      'Provisional: your recurring payments aren\'t in yet';

  @override
  String get todoFixedTitle => 'Add your recurring payments';

  @override
  String todoFixedBody(String date) {
    return 'Anything you pay until $date comes out of what you can spend.';
  }

  @override
  String get todoAdd => 'Add';

  @override
  String get noFixedPayments => 'I don\'t have recurring payments';

  @override
  String get fixedNoneDone =>
      'Done. What you can spend is no longer provisional.';

  @override
  String get freeExplainAssumeNoFixed =>
      'It has no recurring payments: if you pay rent, bills or subscriptions, add them in Plan › Recurring payments and they\'ll come out of this figure before they\'re due.';

  @override
  String onboardingPayAmount(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'fortnight': 'How much do you get each payday?',
      'other': 'How much do you get each payday?',
    });
    return '$_temp0';
  }

  @override
  String get onboardingPayAmountHelp =>
      'Optional. It doesn\'t count as money until it arrives; it\'s used to show the days ahead.';

  @override
  String get onboardingFixedTitle => 'What do you pay regularly?';

  @override
  String get onboardingFixedBody =>
      'Rent, bills, phone, subscriptions. Quincena takes them out of what you can spend before they\'re due.';

  @override
  String get fixedSuggestRent => 'Rent';

  @override
  String get fixedSuggestAdmin => 'Building fee';

  @override
  String get fixedSuggestUtilities => 'Utilities';

  @override
  String get fixedSuggestInternet => 'Internet';

  @override
  String get fixedSuggestPhone => 'Phone plan';

  @override
  String get fixedSuggestSubscription => 'A subscription';

  @override
  String get inboxReadySection => 'Ready to record';

  @override
  String get inboxNeedsInfoSection => 'Need more information';

  @override
  String inboxReadyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ready',
      one: '1 ready',
    );
    return '$_temp0';
  }

  @override
  String inboxNeedsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need information',
      one: '1 needs information',
    );
    return '$_temp0';
  }

  @override
  String inboxRecordReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Record all $count ready',
      one: 'Record the ready one',
    );
    return '$_temp0';
  }

  @override
  String inboxRecordedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions recorded.',
      one: 'One transaction recorded.',
    );
    return '$_temp0';
  }

  @override
  String get recordExpense => 'Record expense';

  @override
  String get recordIncome => 'Record income';

  @override
  String get recordTransfer => 'Record transfer';

  @override
  String get reviewMovement => 'Review transaction';

  @override
  String recordedExpenseIn(String account) {
    return 'Expense recorded in $account.';
  }

  @override
  String recordedIncomeIn(String account) {
    return 'Income recorded in $account.';
  }

  @override
  String get recordedTransfer => 'Transfer recorded.';

  @override
  String recordedTransferBetween(String from, String to) {
    return 'Transfer recorded from $from to $to.';
  }

  @override
  String get accountMissingShort => 'Account missing';

  @override
  String get kindMissing =>
      'We can\'t tell whether it\'s an expense or income.';

  @override
  String accountGuessed(String asset) {
    return 'Check the account: we picked it because it\'s your only everyday account in $asset.';
  }

  @override
  String whichAccountCard(String institution, String digits) {
    return 'We detected $institution and card *$digits, but it isn\'t linked to one of your accounts yet.';
  }

  @override
  String whichAccountBankMany(int count, String institution) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'We detected $institution, but you have $count accounts there: choose which one.',
      two:
          'We detected $institution, but you have two accounts there: choose which one.',
    );
    return '$_temp0';
  }

  @override
  String whichAccountBankNone(String institution) {
    return 'We detected $institution, but you don\'t have an account from that bank in Quincena.';
  }

  @override
  String get pickAccountOut => 'Which account did it come from?';

  @override
  String get pickAccountIn => 'Which account did it go into?';

  @override
  String get pickAccountOthers => 'Other accounts';

  @override
  String addAccountAt(String institution) {
    return 'Add my $institution account';
  }

  @override
  String pickAccountCardNote(String digits) {
    return 'Next time, payments with card *$digits will go straight to that account.';
  }

  @override
  String pickAccountBankNote(String institution) {
    return 'Next time, alerts from $institution will go straight to that account.';
  }

  @override
  String get accountRequired => 'Choose the account.';

  @override
  String get detectionDetails => 'Detection details';

  @override
  String get hideDetectionDetails => 'Hide details';

  @override
  String get detectionHow => 'How it arrived';

  @override
  String get detectionWhy => 'Why we suggested it';

  @override
  String get detectionMessage => 'The message';

  @override
  String get placeShort => 'From your location · © OpenStreetMap';

  @override
  String get inboxAddFrom => 'Read a payment';

  @override
  String get inboxAddTitle => 'Where is the payment?';

  @override
  String get inboxAddImage => 'A screenshot, photo or PDF';

  @override
  String get inboxAddImageBody =>
      'It\'s read on this device and waits here for review.';

  @override
  String get inboxAddPaste => 'A message you copied';

  @override
  String get inboxAddPasteBody =>
      'Paste the bank\'s notification, text or email.';

  @override
  String inboxWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions to review',
      one: '1 transaction to review',
    );
    return '$_temp0';
  }

  @override
  String inboxRecordSome(int count, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Record $count of the $total ready',
      one: 'Record 1 of the $total ready',
    );
    return '$_temp0';
  }

  @override
  String exampleBarTitle(String name) {
    return '$name\'s example account';
  }

  @override
  String get exampleUseOwn => 'Use my accounts';

  @override
  String exampleAboutBody(String name) {
    return '$name is made up, and so is every figure. Nothing you do here touches your own accounts or your data, and it is all erased when you leave the example.';
  }

  @override
  String get exampleBackToStart => 'Back to the first screen';

  @override
  String get exampleStay => 'Keep exploring';

  @override
  String exampleOnlyBody(String name) {
    return 'This is $name\'s example account, and it is made up. Here this does nothing: it connects to nothing, asks your phone for no permissions and leaves your data alone. To use it, switch to your own accounts.';
  }

  @override
  String get exampleNoReminders => 'The example account sets no reminders.';

  @override
  String get exampleSection => 'Example account';

  @override
  String examplePricedAt(String when) {
    return 'The example\'s fixed prices, from $when';
  }

  @override
  String get sourceScript => 'Example conversation';

  @override
  String get exampleNotConnected => 'Connects to nothing in the example';

  @override
  String get examplePricesNote =>
      'In the example, prices are fixed and asked of no one, Binance included. Quincena doesn\'t give investment advice.';

  @override
  String exampleStatementBody(String name) {
    return 'Try a made-up statement of $name\'s payroll account: it has a payment that\'s already recorded, a card payment, and a purchase from before she wrote down her balance.';
  }

  @override
  String get exampleStatementUse => 'Use the example statement';

  @override
  String get examplePasteNote =>
      'A sample message, like the ones banks send. You can change it before reading it.';

  @override
  String dayWhen(String date) {
    return 'on $date';
  }

  @override
  String get todayWhen => 'today';

  @override
  String get buyTakesApart => 'It fits, but only with money you keep apart';

  @override
  String buyWithinFree(String free, String payday) {
    return 'It fits in the $free you can spend until $payday.';
  }

  @override
  String buyOverFree(String free, String payday, String used) {
    return 'That\'s more than the $free you can spend until $payday: you\'d use $used.';
  }

  @override
  String buyUses(String used) {
    return 'You\'d use $used.';
  }

  @override
  String buyAlsoUses(String used) {
    return 'You\'d also use $used.';
  }

  @override
  String buyUsesSetAside(String amount) {
    return '$amount set aside in envelopes';
  }

  @override
  String buyUsesReserve(String amount) {
    return '$amount of what you keep from variable income';
  }

  @override
  String buyUsesCushion(String amount) {
    return '$amount of your safety buffer';
  }

  @override
  String buyNothingFree(String payday, String used) {
    return 'Until $payday you have nothing left to spend: you\'d use $used.';
  }

  @override
  String get envelopesSpentLine => 'Spent from the day to day';

  @override
  String freelanceReserveOutside(String amount) {
    return 'What you were paid into accounts that aren\'t for everyday use ($amount) isn\'t kept apart: it never counted in what you can spend.';
  }

  @override
  String whyAccount(String digits, String account) {
    return 'account *$digits is $account';
  }

  @override
  String ruleAccountKey(String digits) {
    return 'Account *$digits';
  }

  @override
  String get rulesAccounts => 'Account numbers';

  @override
  String whichAccountNumber(String institution, String digits) {
    return 'We detected $institution and account *$digits, but we don\'t know yet which of your accounts it is.';
  }

  @override
  String pickAccountNumberNote(String digits) {
    return 'Next time, transactions on account *$digits will go straight to the one you choose.';
  }

  @override
  String statementPaymentWaits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count card payments stay unchecked until you say which of your accounts they came from: check them and choose the account.',
      one:
          'The card payment stays unchecked until you say which of your accounts it came from: check it and choose the account.',
    );
    return '$_temp0';
  }

  @override
  String statementPaymentNoSource(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count card payments stay unchecked: none of your other accounts is in $currency, and checked they would count as income. Record them as transfers between your accounts from the one that paid them.',
      one:
          'The card payment stays unchecked: none of your other accounts is in $currency, and checked it would count as income. Record it as a transfer between your accounts from the one that paid it.',
    );
    return '$_temp0';
  }

  @override
  String get replacedBySelection => 'Replaced by your new selection';

  @override
  String get seeNewSelection => 'See the new one';

  @override
  String get rulesEmptyWithMovements =>
      'You don\'t have any rules right now. When you record something in Needs review, one is created for its shop, card or bank. Your transactions stay as they are.';

  @override
  String get badgeExample => 'SAMPLE';

  @override
  String get aboutExample =>
      'The account, the person and the shops in the sample are made up.';
}
