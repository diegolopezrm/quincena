/// What an answer wants the person to feel about a number.
///
/// Not decoration: a tone is a claim. `good` says the number is fine as it
/// is, `caution` says it is worth a look, `alert` says it needs doing
/// something about, and `neutral` makes no claim at all.
enum Tone { neutral, good, caution, alert }

/// How much a button asks for attention.
enum Emphasis { primary, secondary }
