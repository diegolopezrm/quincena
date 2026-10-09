# Sync between devices

How Quincena keeps two or more of the person's devices in step without
anyone else being able to read what passes between them. The roadmap's
phase 15 asks for a design and a security review before the code. This
page is the design as built, the review, and what is left out on purpose.

## Sync is not a backup

| | Backup (Ajustes, Exportar) | Sync (Ajustes, Varios dispositivos) |
| --- | --- | --- |
| What it is | Everything at one moment, in a file | Each device's changes, merged into the others |
| Readable by | Only with the backup's own code; anyone, if the person chooses JSON | Only devices that have the vault's code |
| Restoring | Replaces everything on the device | Adds and updates; never wipes what is there |
| Something edited on both sides | Not a question: one file wins whole | The later edit shows; the other waits in "Para revisar" |
| Deleted things | Gone from the file | Stay deleted on every device; an edit made meanwhile elsewhere waits to be brought back |

A backup is what to keep for the day a phone is lost and no other device
has the data. Sync is for using Quincena on more than one device. The
phone's own backups (iCloud, Google) are a third thing: they hold the
app's database, and on iOS the vault's key; end-to-end encryption covers
the sync files, not those backups.

## Choices

- **Optional.** Nothing changes for someone who never turns it on.
- **Files the person carries, no Quincena server.** A sync file goes where
  the person sends it: AirDrop, Files and iCloud Drive, Google Drive, a
  chat with themselves. DL SOFT receives nothing, so the privacy policy's
  first promise, that finances stay on the person's devices, still holds.
  A mailbox server can come later carrying the same files; what it would
  need is at the end.
- **Whole state in each file.** Every file carries every record with its
  version, so devices need not know what the others have seen, a file
  merged twice changes nothing, and any file brings a new device up to
  date.
- **Phones and Macs.** The web demo does not sync.

## Identity and linking

- **The vault** is the set of the person's devices that share one key. The
  first device makes a 256-bit key with the system's secure generator
  (`Random.secure`).
- **Linking** another device is entering the vault's code on it: the key in
  Crockford base32, 52 characters, then two of check, in groups of four.
  The first check character is Luhn mod 32, which catches any single
  character typed wrong; the second is five bits of a hash of the key. Only
  the code as written out is accepted, so a typo in the last character,
  which carries four bits of padding, is caught too.
- **Carrying the code.** Where it is shown, the code is copied or handed
  to the system's share sheet with a line that says which code it is, so a
  note to oneself tells it from the backup's; where it is asked for,
  «Pegar» reads it out of whatever was copied. Typing it is the last
  resort. Both codes have the same shape, so a device names the other one
  only when it keeps it: a backup's code typed to join, or the vault's
  code typed to open a backup. There is no QR: the app has no link of its
  own to open from a camera, and no scanner.
- **Devices** are told apart by a random identifier kept in the keychain
  with "this device only" access, so no backup carries it to another
  device. Every save of the versions also leaves a new mark in the
  keychain. If the database does not match its keychain, as after
  restoring a backup on a new phone or an older backup on the same one,
  the device starts again as one that just joined. Two devices never sign
  changes as one, and a device never signs two changes alike.

## Keys

- The key lives in the Keychain on iOS and macOS and in the Keystore on
  Android (`flutter_secure_storage`): never in the database, an export or
  a log.
- Keys derived with HKDF-SHA256 under separate labels: one encrypts files
  (`quincena/sync/encrypt/v1`), one tags them (`quincena/sync/file-tag/v1`).
- **Recovery** is the code. With every device lost and no code, no one can
  read the files, DL SOFT included; a backup is what helps then. The app
  says so when it shows the code.

## The file

```
"QSYNC" | format (1) | salt (16) | tag (16) | nonce (24) | ciphertext
```

- The body is its length, the changes as gzipped JSON, and zeros to a
  multiple of 16 KiB, sealed with XChaCha20-Poly1305 and a random 24-byte
  nonce.
- The tag is an HMAC of a salt new in every file. It lets a device tell a
  file of another vault from a damaged one, while no two files of a vault
  share anything that ties them together.
- The whole header is associated data: changing any of it, or any byte of
  the body, or cutting the file, makes it fail to open.
- **Outside the encryption**: that it is a Quincena sync file (its first
  bytes and the `.qsync` name), the format version, and its size rounded
  up to 16 KiB. Whatever carries the file adds its own dates and names; the
  app names files `quincena-<date>.qsync`.

## Backups

Exportar in Ajustes offers two files. The first, chosen unless the person
picks the other, is sealed: it can sit in iCloud Drive or a chat with
themselves and no one reads it. The second is the export as JSON, readable
by anyone who has it, for taking the data to another tool.

- **Its own key.** The first sealed backup makes a 256-bit key with the
  system's secure generator and shows it as a code of the same form as the
  vault's, once, with the warning that without it no one can open the
  backups, DL SOFT included. Every later backup uses the same key, so one
  code opens them all; "Ver mi código de respaldo" shows it again. The key
  lives in the keychain like the vault's (`quincena.backup.key`), never in
  the database or an export.
- **The same file, another kind.** `"QBACK"` instead of `"QSYNC"`, the
  same format otherwise, with keys derived under labels of its own
  (`quincena/backup/encrypt/v1`, `quincena/backup/file-tag/v1`). A sync
  code never opens a backup nor a backup's code a sync file, even with the
  first bytes changed: the tag is made under the other label and fails.
  The body is the export, the same JSON the other choice writes.
- **Restoring.** On the phone that made it, the backup opens with nothing
  to type. On another, the app asks for the code; a code typed there stays
  as that phone's backup code if it had none, so its next backups open
  with the same one. The file is opened and checked whole before the
  person is asked whether to replace everything, and a sync file brought
  here is pointed to "Varios dispositivos". Restoring replaces everything
  in one transaction, as an import always has.
- **Deleting everything** forgets the key with the vault's. Backups made
  with it still open with its code.
- **No keychain.** Where the keychain fails, a sealed backup still goes
  out with a new key, and its code is shown every time.
- **Changing the code** makes a new key for the backups to come, and
  shows its code. Those made before still open with the old code, which
  the app says before changing it.

## What syncs

Accounts, movements, recurring charges, goals, budgets, categories, rates
typed by hand, the profile, and the settings an export carries: learned
capture rules, followed wallets, envelopes, the cushion, wishes, scenarios,
what was told about fixed payments, instalments, the charge detective's
answers, shared groups, variable income and trips. Settings that hold a
list (groups, trips, instalments, wishes, clients' payments, scenarios) or
a map (what was told about each fixed payment) sync item by item, so
changes to two items on two devices both stay.

It does not sync what belongs to one device: captures waiting in "Por
revisar", rates fetched from the network, reminders, the Binance key and
the app's mode.

## Versions and merging

Each record carries, per device, how many times that device changed it
(a version vector), and a stamp: a hybrid logical clock (the device's
milliseconds, never behind any stamp it has seen, a counter, and the
device), which orders any two versions the same way on every device.

- Before writing or reading a file, a device looks at its own records: one
  whose contents changed since the last look gets a new version; one that
  disappeared becomes a tombstone.
- Merging follows two rules, each a join, so the result does not depend
  on the order files arrive in and a file merged again changes nothing:
  - **Records with ids made at random** (accounts, movements, recurring
    charges, goals, and the items of groups, trips, instalments, wishes and
    clients' payments): once deleted on any device, a record stays deleted
    everywhere, and a deletion always travels as one. Otherwise the later
    version wins.
  - **Records known by name** (settings, categories, budgets, manual rates,
    scenarios, what was told about each fixed payment): the later version
    wins, a deletion included.
- Something written again under an id deleted for good moves, before the
  device writes or reads a file, to an id derived from the old one by a
  hash: the same on every device, so two devices that do it agree.
- A version that loses with something the winner never saw (its vector
  shows a change the winner's lacks) goes to "Para revisar" as it was.
  Bringing it back makes it the newest change. Something deleted for good
  comes back under the id derived from its own: bringing it back on two
  devices, or twice, makes one record, and several movements of one
  deleted account bring back one account. What it replaces goes to
  "Para revisar" in its turn.
- An account deleted on one device takes its movements on every device. A
  movement added to it meanwhile on another device goes to "Para revisar"
  with its account.
- A device that joins counts its own records as older than the vault's,
  so the vault's profile and settings win over a fresh install's, and its
  own records keep their order among themselves until it merges a file.
  Joining again with a new code keeps a device's versions.
- Copies of one thing from two devices become one: accounts that follow
  the same wallet or exchange asset merge into the one with the smaller
  id, with their movements; then the same line of a statement or of
  Binance in the same account stays once, again the smaller id. A copy
  that differs in amount, category, payee or note goes to "Para revisar".
  Balance adjustments of wallets and Binance are numbered, not timed, so
  two devices that see the same change make the same line.
- The merge, the new versions and "Para revisar" are written in one
  database transaction. Tombstones are kept for good.

## Whole records, not fields

A version is a version of the whole record. Two edits to different fields
of the same record, made on two devices before either saw the other's
file, are two concurrent versions, and only one of them can stay.

What happens today, with a movement «Almuerzo» on both devices:

1. On the phone its name becomes «Almuerzo con Juan». On the computer,
   before the phone's file arrives, it gets the note «Pagó la mitad».
2. When the files cross, each version has a change the other never saw.
   The later stamp wins whole, say the computer's: both devices show
   «Almuerzo» with the note. The phone's version waits in "Para revisar"
   as it was, «Almuerzo con Juan» with no note.
3. "Para revisar" names it by its payee and amount and says it was
   changed on both devices. It does not say which fields differ, so the
   person cannot tell that bringing it back takes the note away.
4. «Traer de vuelta» writes the waiting version whole, as the newest
   change: the name comes back, the note goes, and the version it
   replaced, with the note, waits in its turn. «Descartar» on that one
   lets the note go on every device. «Descartar» on the first instead
   keeps the note and loses the name. Either way one of two edits that
   never touched the same field is lost, unless the person types it
   again. Nothing is counted twice: amounts change only if one of the
   edits was to the amount.

`test/sync_test.dart` holds this: "a name changed on one and a note
added on the other are two versions".

### What a merge field by field would take

- **Versions per field, in the file.** Any merge has to end the same on
  every device whatever order files arrive in, as the two rules above do.
  A three-way merge against the last version each device saw does not:
  devices have seen different versions, so two of them merging the same
  pair can write different records. Each field that merges on its own
  needs its own version vector and stamp, and merges as records do now:
  the later wins, and a concurrent loser waits, as a field.
- **A new sync format.** Records would carry those per-field versions
  next to `c` and `s`, under `"format": 2` in the body. A device on the
  new format reads format 1 files by giving every field the record's
  vector and stamp. A device on the old format refuses format 2 as newer,
  so a device cannot start writing format 2 until every device of the
  vault reads it. Today a device does not know the others, so that needs
  either a record of each device and the format it reads, or the person
  updating every device first.
- **Hashes per field.** A device notices its own changes by a hash of the
  whole record. It would keep one per field in its sync metadata, which
  is stored in the device's settings, so no user table changes. Every
  device would version each field once, the first time it writes the new
  format.
- **Fields that move together.** Amount, kind and account are one field,
  since an amount means nothing without its account's currency, and a
  goal's target goes with its date. The two legs of a transfer are two
  records whose amounts must still merge as one, or each leg could keep a
  different amount. Settings known by name and the items of lists stay
  whole.
- **"Para revisar" by field.** It would show the field and both values,
  «Nombre: Almuerzo con Juan», and bringing it back would write that field
  only.
- **Tests and review.** The three-device test and the simulation of
  random histories run per field, the test above turns around, and the
  merge gets a review pass like the two before, since the format changes.

A cheaper step needs no new format: "Para revisar" could show what differs
between the waiting version and the one shown, and «Traer de vuelta» could
take only the fields the person picks. The result is a new whole version
that syncs as any edit does. The person does the merging, but nothing they
see is lost without them choosing it.

## Revoking, deleting and keeping

- **A lost device, or one that should stop syncing**: change the code. The
  devices to keep join again with the new code and keep their versions.
  Files made after that cannot be read with the old code. Files already
  sent cannot be taken back: whoever has one and the old code can read
  it, which the app says when changing the code.
- **Stop syncing** on a device: it forgets the key and the versions; its
  data stays, and so does "Para revisar".
- **Copies elsewhere**: the files are the person's, wherever they put
  them. The app cannot delete them and does not try.

## Threat model

What is protected: the person's financial records and settings in sync
files.

| Who | What they get | What stops more |
| --- | --- | --- |
| Whoever stores or carries a file (iCloud, a chat app, someone it was forwarded to) | That it is a Quincena sync file, and its size to 16 KiB | XChaCha20-Poly1305 with a key they never see |
| Someone holding several files | Nothing ties them to one vault | A new salt and tag in every file |
| Someone who changes or cuts a file | Nothing: it fails to open | The cipher's authentication tag covers the header and the body |
| A device removed by changing the code | What it had, and files made before the change | A new key: files after it cannot be read |

Out of scope: an unlocked device in someone else's hands, malware on the
device, the person giving the code away, and the phone's own backups. A
device whose clock runs ahead makes its edits win until the others' clocks
pass it, and moves the stamps of devices that see its files forward; it
changes which edit shows, and the other waits in "Para revisar". A file
needs the key to be made at all, so replaying an old one, sending one of
an older format, or crafting one that inflates too much are the person's
own doing; the app still refuses a newer format and anything that
inflates past 64 MiB by what gzip declares.

## Security review

Done in two passes by a reviewer apart from the code's author: on the
design, then on the code.

The first pass, on the design:

- High: the earlier rule, "a deletion wins over an edit", could leave two
  devices different for good when a record came back under the same id,
  and a history of the last eight versions could raise false conflicts or
  let an old file delete something. Fixed with version vectors and the two
  rules above, which a simulation of 20,000 random histories of three
  devices per kind of record found independent of the order of files.
- Medium: a backup could carry a device's identity to another device; a
  new code wiped versions; "Para revisar" could lose what it held and was
  written outside the merge's transaction; whole-list settings made edits
  to different items conflict; the same statement imported on two devices
  made duplicates. Fixed as described above.
- Low: a constant vault identifier tied files together and their size said
  how much was in them; the check character missed one typo in 1,024.
  Fixed with the per-file tag, the padding and Luhn mod 32.

The second pass, on the code, simulated the merge and the store's
deletions as written: 3,000 three-device histories and 1,500 sets of files
ended the same in every order and with every file merged again. It found:

- Medium: a row written again under an id deleted for good stayed on one
  device; bringing back the same version on two devices, or several
  movements of one deleted account, made copies; wallets and Binance
  followed on two devices doubled their adjustments. Fixed: such rows move
  to a derived id and deletions always travel as deletions; brought-back
  records take ids derived from their own; same-source accounts merge and
  adjustments are numbered. Scenarios, whose ids are not random, follow
  the rule for records known by name.
- Low: a brought-back duplicate was dropped again (it no longer keeps its
  statement reference); a joining device's second file could rank below
  its first (the count now persists); an id with a slash was cut in two
  (ids are split by the setting's known name); a device restored from an
  older backup of itself could sign two changes alike (the keychain mark).
  All fixed, with a test each in `test/sync_test.dart`.

After the second pass, a test that failed one run in eight found one more,
in a step the simulation did not model. When two copies of an account
became one, the movement moved to the kept account was hashed as if it had
arrived that way. It then travelled with its old version and new contents,
and the other device could keep it on the account that was gone, which
sent it to "Para revisar". Copies now become one after the merge's hashes
are saved, so the move is a change with its own version; the test now
draws ids until they fall that way, and fails every time without the fix.

The cryptography, the file format and the code check were found sound
for this threat model in both passes: a random 24-byte nonce, the whole
header authenticated, HKDF over a random key with a label per use, a salt
and tag per file, padding whose length is authenticated and bounds-checked,
and Luhn mod 32 implemented right. Key commitment and partitioning attacks
do not apply with one random key and no passwords; they would if codes
ever came from passwords.

Left as stated: the decompression cap trusts what gzip declares, which
only someone with the key can make lie; the screen that shows the code
does not block screenshots; and an independent review is still advised
before a server transport is turned on.

## A server later

A mailbox where devices drop and pick up the same files would make sync
automatic. It would need Firestore or Cloud Storage rules that let only a
vault's devices read and write its folder, keyed by another derived
identifier; deleting a vault's files when it is abandoned and after a
retention period; an update to the privacy policy and the stores' privacy
answers; and that review. The file format stays as it is.
