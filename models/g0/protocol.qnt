// A finite abstraction: two publication attempts, two owner generations and one GC object.
module protocol {
  type State = {
    head: int, generation: int, prepared: bool, parent: int, owner: int,
    receipts: Set[int], duplicate: bool, attempt: int, lastAttempt: int, abandonedAttempt: int, receiptAttempt: int, op: int, done1: bool, done2: bool, metadataDone: bool, effects1: int, publications: int, visible1: bool, visible2: bool,
    response1: bool, outcome1: int, reply1: int, pinned: bool, root: bool, retired: bool, deleted: bool, age: int,
    stalePublished: bool, badPublication: bool, badParent: bool, badFence: bool, badGc: bool
  }
  var s: State

  action init = s' = {
    head: 0, generation: 0, prepared: false, parent: 0, owner: 0,
    receipts: Set(), duplicate: false, attempt: 0, lastAttempt: 0, abandonedAttempt: 0, receiptAttempt: 0, op: 1, done1: false, done2: false, metadataDone: false, effects1: 0, publications: 0, visible1: false, visible2: false,
    response1: false, outcome1: 0, reply1: 0, pinned: false, root: true, retired: false, deleted: false, age: 0,
    stalePublished: false, badPublication: false, badParent: false, badFence: false, badGc: false
  }

  action prepare(reuse) = {
    nondet n = Set(Set(), Set(1), Set(1, 2), Set(1, 3)).oneOf()
    nondet operation = Set(1, 2).oneOf()
    nondet duplicate = Set(true, false).oneOf()
    all {
      not(s.prepared),
      if (reuse) s.lastAttempt > 0 else s.lastAttempt < 2,
      s' = s.with("prepared", true).with("parent", s.head)
        .with("owner", s.generation).with("receipts", n).with("duplicate", duplicate).with("attempt", if (reuse) s.lastAttempt else s.lastAttempt + 1)
        .with("lastAttempt", if (reuse) s.lastAttempt else s.lastAttempt + 1).with("receiptAttempt", 0).with("op", operation)
    }
  }

  // Receipt arrival may come from an abandoned attempt.
  action receive = {
    nondet receiptAttempt = Set(1, 2).oneOf()
    all { s.prepared, s.receiptAttempt == 0, s' = s.with("receiptAttempt", receiptAttempt) }
  }

  // The two expected partition receipts are bound to this prepared attempt.
  action publish(badReceipts, badOwner, badRetry, ignoreParent, ignoreRetirement, partial) = all {
    s.prepared,
    s.parent == s.head or ignoreParent,
    (s.receipts == Set(1, 2) and not(s.duplicate) and s.receiptAttempt == s.attempt) or badReceipts,
    s.owner == s.generation or badOwner,
    (s.op == 1 and (not(s.done1) or badRetry)) or (s.op == 2 and not(s.done2)),
    (not(s.retired) and not(s.deleted)) or ignoreRetirement,
    s.head < 3,
    s' = s.with("head", s.head + 1).with("prepared", false).with("root", true)
      .with("badGc", s.badGc or s.retired or s.deleted)
      .with("done1", s.done1 or s.op == 1).with("done2", s.done2 or s.op == 2)
      .with("effects1", s.effects1 + if (s.op == 1) 1 else 0)
      .with("publications", s.publications + 1).with("visible1", true).with("visible2", not(partial))
      .with("stalePublished", s.stalePublished or (s.abandonedAttempt != 0 and s.attempt == s.abandonedAttempt and s.receiptAttempt == s.abandonedAttempt))
      .with("outcome1", if (s.op == 1 and not(s.done1)) s.head + 1 else s.outcome1)
      .with("badParent", s.badParent or s.parent != s.head)
      .with("badPublication", s.badPublication or s.receipts != Set(1, 2) or s.duplicate or s.receiptAttempt != s.attempt)
      .with("badFence", s.badFence or s.owner != s.generation)
  }
  action abandon = all { s.prepared, s' = s.with("prepared", false).with("abandonedAttempt", s.attempt) }
  action reassign = all { s.generation == 0, s' = s.with("generation", 1) }
  // A committed response may be lost; retry consults durable outcome, even after head advances.
  action reconcile(wrongHead) = all { s.done1, not(s.response1), s' = s.with("response1", true).with("reply1", if (wrongHead) s.head else s.outcome1) }
  // An unrelated metadata operation advances the root, not a publication.
  action advance = all { not(s.metadataDone), s.head < 3, s' = s.with("head", s.head + 1).with("metadataDone", true) }
  action tick = all { s.age < 2, s' = s.with("age", s.age + 1) }
  action pin(bad) = all {
    not(s.pinned), not(s.retired) or bad,
    s' = s.with("pinned", true).with("badGc", s.badGc or s.retired)
  }
  action unpin = all { s.pinned, s' = s.with("pinned", false) }
  action releaseRoot = all { s.root, s' = s.with("root", false).with("visible1", false).with("visible2", false) }
  action reference(bad) = all { not(s.root), not(s.retired) or bad, s' = s.with("root", true).with("badGc", s.badGc or s.retired) }
  action retire = all { not(s.retired), not(s.pinned), not(s.root), s' = s.with("retired", true) }
  action collect = all {
    s.retired, not(s.pinned), not(s.root), not(s.deleted), s.age >= 2,
    s' = s.with("deleted", true)
  }

  action step = any { prepare(false), receive, publish(false, false, false, false, false, false), abandon, reassign,
    reconcile(false), advance, tick, pin(false), unpin, releaseRoot, reference(false), retire, collect }
  action bad_atomic_step = any { step, publish(false, false, false, false, false, true) }
  action bad_reuse_step = any { step, prepare(true) }
  action bad_publication_step = any { step, publish(true, false, false, false, false, false) }
  action bad_fencing_step = any { step, publish(false, true, false, false, false, false) }
  action bad_retry_step = any { step, publish(false, false, true, false, false, false) }
  action bad_foreign_step = any { step, all { s.receipts == Set(1, 2), not(s.duplicate), s.receiptAttempt != 0, s.receiptAttempt != s.attempt, publish(true, false, false, false, false, false) } }
  action bad_parent_step = any { step, publish(false, false, false, true, false, false) }
  action bad_reply_step = any { step, reconcile(true) }
  action bad_gc_step = any { step, pin(true) }
  action bad_publish_retired_step = any { step, publish(false, false, false, false, true, false) }
  action bad_resurrection_step = any { step, reference(true) }

  val publication = not(s.badPublication) and not(s.badParent) and
    s.visible1 == s.visible2 and (not(s.visible1) or s.publications > 0)
  val fencing_and_outcomes = not(s.stalePublished) and not(s.badFence) and s.effects1 <= 1 and (not(s.response1) or s.reply1 == s.outcome1)
  val gc = (not(s.visible1) or (s.root and not(s.retired) and not(s.deleted))) and not(s.badGc) and not(s.deleted and (s.pinned or s.root)) and not(s.retired and s.root) and (not(s.deleted) or s.age >= 2)
}
