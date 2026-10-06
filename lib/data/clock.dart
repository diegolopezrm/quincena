/// The day Quincena treats as today.
///
/// The demo account is a story told up to the morning of October 1st, 2026,
/// the day after a payday. Fixing the date keeps "this month", "since your
/// last payday" and "how long until December" true whenever it is opened.
DateTime appToday = DateTime(2026, 10, 1);

/// The moment Valentina's example account believes it is: ten in the
/// morning of that same October 1st, whatever the device's clock says, so
/// the whole app tells the story the conversation tells.
final DateTime exampleNow = DateTime(2026, 10, 1, 10);
