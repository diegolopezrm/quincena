import '../capture/inbox.dart';
import '../capture/merchants.dart';
import '../domain/commitments.dart';
import '../domain/freelance.dart';
import '../domain/plan.dart';
import '../domain/records.dart';
import '../domain/shared.dart';
import '../domain/trips.dart';
import '../exchanges/wallets.dart';
import '../money/asset.dart';
import '../store/store.dart';
import 'own_controller.dart';

/// Puts back what an action took, as it was: what every deletion, discard
/// and archive hands the screen, for the way back it offers for a few
/// seconds.
typedef Undo = Future<void> Function();

/// The actions that take something away, each with its way back. What they
/// take is kept as it was, ids included, so whatever pointed at it points
/// at it again: a payment at its movement, a split at its expense, a goal
/// at its envelope.
extension TakeBack on OwnController {
  /// Deletes [entry], both legs of a transfer, and its split, which no one
  /// owes for once it is gone.
  Future<Undo> deleteMovement(Entry entry) async {
    final Removal kept = await store.keepEntry(entry);
    final (Group, SharedExpense)? split = splitOf(entry.id);
    await store.deleteEntry(entry);
    if (split case (final Group group, final SharedExpense expense)) {
      await saveGroup(group.withoutExpense(expense.id));
    }
    return () async {
      await store.putBack(kept);
      if (split case (final Group group, _)) await saveGroup(group);
    };
  }

  /// Takes [expense] out of [group]. With [dropEntry], the movement the Plan
  /// wrote down for it goes too; one the person wrote down stays theirs.
  Future<Undo> removeSplit(
    Group group,
    SharedExpense expense, {
    bool dropEntry = false,
  }) async {
    final Removal kept = await _keepPlanEntry(
      dropEntry ? expense.entryId : null,
    );
    if (dropEntry) await dropPlanEntry(expense.entryId);
    await saveGroup(group.withoutExpense(expense.id));
    return () async {
      await store.putBack(kept);
      await saveGroup(group);
    };
  }

  /// Sets [item] aside as no movement; with [muteApp], the app that posted
  /// it is not read again. The way back puts it where it waited, as it was
  /// stored, and reads the app again.
  Future<Undo> discard(InboxItem item, {bool muteApp = false}) async {
    final InboxItem stored = await store.inboxItem(item.id) ?? item;
    final CaptureSettings before = await store.captureSettings();
    await capture.dismiss(item, muteApp: muteApp);
    final String? app = item.event.app;
    return () async {
      await store.saveInboxItem(stored);
      if (!muteApp || app == null || before.mutedApps.contains(app)) return;
      final CaptureSettings now = await store.captureSettings();
      await store.saveCaptureSettings(
        now.copyWith(
          mutedApps: <String>{
            for (final String a in now.mutedApps)
              if (a != app) a,
          },
          appNames: <String, String>{
            for (final MapEntry<String, String> e in now.appNames.entries)
              if (e.key != app) e.key: e.value,
            if (before.appNames[app] case final String name) app: name,
          },
        ),
      );
    };
  }

  /// Brings a capture discarded earlier back to Por revisar: as a possible
  /// repeat when it was one, waiting otherwise.
  Future<void> bringBack(InboxItem item) => store.saveInboxItem(
    item.copyWith(
      status: item.duplicateOf == null
          ? InboxStatus.pending
          : InboxStatus.duplicate,
    ),
  );

  /// Reads [app]'s notifications again.
  Future<void> readAgain(String app) async {
    final CaptureSettings s = await store.captureSettings();
    await store.saveCaptureSettings(
      s.copyWith(
        mutedApps: <String>{
          for (final String a in s.mutedApps)
            if (a != app) a,
        },
        appNames: <String, String>{
          for (final MapEntry<String, String> e in s.appNames.entries)
            if (e.key != app) e.key: e.value,
        },
      ),
    );
  }

  /// Deletes [rule]; the way back puts it back as it was, turned off if it
  /// was.
  Future<Undo> deleteRule(CaptureRule rule) async {
    await store.saveCaptureSettings(
      (await store.captureSettings()).withoutRule(rule),
    );
    return () async => store.saveCaptureSettings(
      (await store.captureSettings()).withRule(rule),
    );
  }

  Future<Undo> removeWish(Wish wish) async {
    final int at = wishes.indexWhere((Wish w) => w.id == wish.id);
    await saveWishes(<Wish>[
      for (final Wish w in wishes)
        if (w.id != wish.id) w,
    ]);
    return () => saveWishes(_back(wishes, wish, at, (Wish w) => w.id));
  }

  Future<Undo> removeScenario(Scenario scenario) async {
    final int at = scenarios.indexWhere((Scenario s) => s.id == scenario.id);
    await saveScenarios(<Scenario>[
      for (final Scenario s in scenarios)
        if (s.id != scenario.id) s,
    ]);
    return () =>
        saveScenarios(_back(scenarios, scenario, at, (Scenario s) => s.id));
  }

  /// Deletes what a client owes, or paid; the movement it was paid with
  /// stays.
  Future<Undo> removeIncome(ExpectedIncome income) async {
    final int at = freelance.incomes.indexWhere(
      (ExpectedIncome i) => i.id == income.id,
    );
    await saveFreelance(freelance.withoutIncome(income.id));
    return () => saveFreelance(
      freelance.copyWith(
        incomes: _back(
          freelance.incomes,
          income,
          at,
          (ExpectedIncome i) => i.id,
        ),
      ),
    );
  }

  /// Says [entry] is not one of [trip]'s expenses.
  Future<Undo> leaveOutOfTrip(Trip trip, Entry entry) async {
    final bool included = trip.included.contains(entry.id);
    await saveTrip(
      trip.copyWith(
        excluded: <String>{...trip.excluded, entry.id},
        included: <String>{
          for (final String id in trip.included)
            if (id != entry.id) id,
        },
      ),
    );
    return () => _countInTrip(trip.id, entry, included: included);
  }

  /// Counts [entry] among [trip]'s expenses again, after the person said it
  /// was not one. One of its days counts again on its own; one from
  /// outside them, or one paid at home in a trip abroad, which the trip
  /// would ask about again, is kept as one of the trip's.
  Future<void> backInTrip(Trip trip, Entry entry) {
    final Trip out = trip.copyWith(
      excluded: trip.excluded.difference(<String>{entry.id}),
    );
    final bool alone = out.covers(
      entry,
      account: snapshot?.account(entry.accountId)?.asset,
      home: profile?.base ?? Asset.cop,
    );
    return _countInTrip(trip.id, entry, included: !alone);
  }

  /// Says of every one of [entries], expenses [trip] asked about, whether
  /// it [belongs] to it, at once.
  Future<Undo> answerTrip(
    Trip trip,
    Iterable<Entry> entries, {
    required bool belongs,
  }) async {
    final Set<String> ids = <String>{for (final Entry e in entries) e.id};
    await saveTrip(
      trip.copyWith(
        included: belongs ? <String>{...trip.included, ...ids} : null,
        excluded: belongs ? null : <String>{...trip.excluded, ...ids},
      ),
    );
    return () async {
      final Trip? now = this.trip(trip.id);
      if (now == null) return;
      await saveTrip(
        now.copyWith(
          included: now.included.difference(ids),
          excluded: now.excluded.difference(ids),
        ),
      );
    };
  }

  /// Counts in [trip] the ones of [entries] in [belong], and leaves the
  /// rest out, as the person picked them one by one.
  Future<void> sortTrip(
    Trip trip,
    Iterable<Entry> entries, {
    required Set<String> belong,
  }) => saveTrip(
    trip.copyWith(
      included: <String>{
        ...trip.included,
        for (final Entry e in entries)
          if (belong.contains(e.id)) e.id,
      },
      excluded: <String>{
        ...trip.excluded,
        for (final Entry e in entries)
          if (!belong.contains(e.id)) e.id,
      },
    ),
  );

  Future<void> _countInTrip(
    String id,
    Entry entry, {
    required bool included,
  }) async {
    final Trip? now = trip(id);
    if (now == null) return;
    await saveTrip(
      now.copyWith(
        excluded: <String>{
          for (final String x in now.excluded)
            if (x != entry.id) x,
        },
        included: included ? <String>{...now.included, entry.id} : null,
      ),
    );
  }

  /// Deletes [trip]; its expenses stay in the accounts.
  Future<Undo> removeTrip(Trip trip) async {
    await deleteTrip(trip.id);
    return () => saveTrip(trip);
  }

  /// Deletes [goal] with its envelope, as [OwnController.deleteGoal] does;
  /// the way back puts the envelope back where it was in the plan.
  Future<Undo> removeGoal(SavingsGoal goal) async {
    final Removal kept = await store.keepGoal(goal.id);
    final EnvelopePlan? plan = lastPlan;
    final int at =
        plan?.envelopes.indexWhere((Envelope e) => e.goalId == goal.id) ?? -1;
    await deleteGoal(goal.id);
    return () async {
      await store.putBack(kept);
      final EnvelopePlan? now = lastPlan;
      if (plan == null || at < 0 || now == null || now.period != plan.period) {
        return;
      }
      await savePlan(
        now.copyWith(
          envelopes: _back(
            now.envelopes,
            plan.envelopes[at],
            at,
            (Envelope e) => e.id,
          ),
        ),
      );
    };
  }

  /// Deletes the fixed payment [charge] and what the person told about it;
  /// what it already charged stays.
  Future<Undo> removeCharge(RecurringCharge charge) async {
    final Removal kept = await store.keepRecurring(charge.id);
    final ChargeMemory memory = memoryOf(charge.id);
    await store.deleteRecurring(charge.id);
    await forgetMemory(charge.id);
    return () async {
      await store.putBack(kept);
      if (memory.toJson().isNotEmpty) await saveMemory(charge.id, memory);
    };
  }

  /// Deletes the purchase [plan] with its payments; the movements they
  /// went out with stay.
  Future<Undo> removeInstalments(Instalments plan) async {
    await deleteInstalments(plan.id);
    return () => putBackInstalments(<Instalments>[plan]);
  }

  /// Takes the [index]th payment of [plan] back, with the movement the Plan
  /// made for it.
  Future<Undo> removePayment(Instalments plan, int index) async {
    final Removal kept = await _keepPlanEntry(plan.entryOf(index));
    await removeInstalmentPayment(plan, index);
    return () async {
      await store.putBack(kept);
      await putBackInstalments(<Instalments>[plan]);
    };
  }

  /// Takes [settlement] out of [group], with the movement the Plan made for
  /// it.
  Future<Undo> removeSettlement(Group group, Settlement settlement) async {
    final Removal kept = await _keepPlanEntry(settlement.entryId);
    await unsettle(group, settlement);
    return () async {
      await store.putBack(kept);
      await saveGroup(group);
    };
  }

  /// Deletes [group], its expenses and its payments; the movements stay.
  Future<Undo> removeGroup(Group group) async {
    await deleteGroup(group.id);
    return () => saveGroup(group);
  }

  /// Archives [accounts] or, with [delete], deletes the one with every
  /// movement in it, and moves what is paid from them to [movedTo]. The
  /// way back brings all of it back: the account, its movements, the other
  /// leg of each transfer, and where each payment came from.
  Future<Undo> leave(
    List<Account> accounts, {
    required bool delete,
    String? movedTo,
  }) async {
    final Set<String> ids = <String>{for (final Account a in accounts) a.id};
    final Removal kept = await store.keepAccounts(ids, movements: delete);
    final List<Instalments> moved = <Instalments>[
      for (final Instalments p in instalments)
        if (ids.contains(p.accountId)) p,
    ];
    if (delete) {
      await deleteAccount(accounts.single.id, movedTo: movedTo);
    } else {
      await archiveAccounts(ids, movedTo: movedTo);
    }
    return () async {
      await store.putBack(kept);
      if (moved.isNotEmpty) await putBackInstalments(moved);
    };
  }

  /// Answers the alert [id] in a way that puts it away: expected, or
  /// dismissed.
  Future<Undo> putAlertAway(String id, AlertAnswer answer) async {
    final AlertAnswer? before = detective.answers[id];
    await answerAlert(id, answer);
    return () => answerAlert(id, before);
  }

  /// Stops offering [name] as a fixed payment.
  Future<Undo> sayNotRecurring(String name) async {
    final String key = merchantKey(name);
    final bool said = detective.notRecurring.contains(key);
    await notRecurring(name);
    return () async {
      if (!said) await recurringAgain(key);
    };
  }

  /// Stops following [wallet]; its accounts stay.
  Future<Undo> stopFollowing(WalletAddress wallet) async {
    final int at = wallets.wallets.indexOf(wallet);
    await wallets.remove(wallet);
    return () => wallets.followAgain(wallet, at);
  }

  /// The movement [id] as stored, when the Plan made it: what
  /// [OwnController.dropPlanEntry] takes.
  Future<Removal> _keepPlanEntry(String? id) async {
    final Entry? e = id == null ? null : entryById(id);
    if (e == null || e.source != OwnController.planSource) {
      return const Removal();
    }
    return store.keepEntry(e);
  }
}

/// [list] with [item] back at [index], or at its end when the list got
/// shorter; as it is when something with its id is there already.
List<T> _back<T>(List<T> list, T item, int index, String Function(T) idOf) {
  if (list.any((T x) => idOf(x) == idOf(item))) return list;
  return <T>[...list]..insert(index.clamp(0, list.length), item);
}
