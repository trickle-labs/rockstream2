// A finite abstraction: two publication attempts, two owner generations and one GC object.
module protocol {
  type State = {
    head: int, generation: int, prepared: bool, parent: int, owner: int,
    receipts: Set[int], duplicate: bool, foreignAttempt: bool, op: int, done1: bool, done2: bool, effects1: int,
    response1: bool, outcome1: int, reply1: int, pinned: bool, root: bool, retired: bool, deleted: bool, age: int,
    badPublication: bool, badParent: bool, badFence: bool, badGc: bool
  }
  var s: State

  action init = s' = {
    head: 0, generation: 0, prepared: false, parent: 0, owner: 0,
    receipts: Set(), duplicate: false, foreignAttempt: false, op: 1, done1: false, done2: false, effects1: 0,
    response1: false, outcome1: 0, reply1: 0, pinned: false, root: true, retired: false, deleted: false, age: 0,
    badPublication: false, badParent: false, badFence: false, badGc: false
  }

  action prepare = {
    nondet n = Set(Set(), Set(1), Set(1, 2), Set(1, 3)).oneOf()
    nondet operation = Set(1, 2).oneOf()
    nondet duplicate = Set(true, false).oneOf()
    nondet foreignAttempt = Set(true, false).oneOf()
    all {
      not(s.prepared),
      s' = s.with("prepared", true).with("parent", s.head)
        .with("owner", s.generation).with("receipts", n).with("duplicate", duplicate).with("foreignAttempt", foreignAttempt).with("op", operation)
    }
  }

  // The two expected partition receipts are bound to this prepared attempt.
  action publish(badReceipts, badOwner, badRetry, ignoreParent) = all {
    s.prepared,
    s.parent == s.head or ignoreParent,
    (s.receipts == Set(1, 2) and not(s.duplicate) and not(s.foreignAttempt)) or badReceipts,
    s.owner == s.generation or badOwner,
    (s.op == 1 and (not(s.done1) or badRetry)) or (s.op == 2 and not(s.done2)),
    s.head < 3,
    s' = s.with("head", s.head + 1).with("prepared", false)
      .with("done1", s.done1 or s.op == 1).with("done2", s.done2 or s.op == 2)
      .with("effects1", s.effects1 + if (s.op == 1) 1 else 0)
      .with("outcome1", if (s.op == 1 and not(s.done1)) s.head + 1 else s.outcome1)
      .with("badParent", s.badParent or s.parent != s.head)
      .with("badPublication", s.badPublication or s.receipts != Set(1, 2) or s.duplicate or s.foreignAttempt)
      .with("badFence", s.badFence or s.owner != s.generation)
  }
  action abandon = all { s.prepared, s' = s.with("prepared", false) }
  action reassign = all { s.generation == 0, s' = s.with("generation", 1) }
  // A committed response may be lost; retry consults durable outcome, even after head advances.
  action reconcile(wrongHead) = all { s.done1, not(s.response1), s' = s.with("response1", true).with("reply1", if (wrongHead) s.head else s.outcome1) }
  // An unrelated metadata operation advances the root, not a publication.
  action advance = all { not(s.done2), s.head < 3, s' = s.with("head", s.head + 1).with("done2", true) }
  action tick = all { s.age < 2, s' = s.with("age", s.age + 1) }
  action pin(bad) = all {
    not(s.pinned), not(s.retired) or bad,
    s' = s.with("pinned", true).with("badGc", s.badGc or s.retired)
  }
  action unpin = all { s.pinned, s' = s.with("pinned", false) }
  action releaseRoot = all { s.root, s' = s.with("root", false) }
  action reference(bad) = all { not(s.root), not(s.retired) or bad, s' = s.with("root", true).with("badGc", s.badGc or s.retired) }
  action retire = all { not(s.retired), not(s.pinned), not(s.root), s' = s.with("retired", true) }
  action collect = all {
    s.retired, not(s.pinned), not(s.root), not(s.deleted), s.age >= 2,
    s' = s.with("deleted", true)
  }

  action step = any { prepare, publish(false, false, false, false), abandon, reassign,
    reconcile(false), advance, tick, pin(false), unpin, releaseRoot, reference(false), retire, collect }
  action bad_publication_step = any { step, publish(true, false, false, false) }
  action bad_fencing_step = any { step, publish(false, true, false, false) }
  action bad_retry_step = any { step, publish(false, false, true, false) }
  action bad_foreign_step = any { step, all { s.receipts == Set(1, 2), not(s.duplicate), s.foreignAttempt, publish(true, false, false, false) } }
  action bad_parent_step = any { step, publish(false, false, false, true) }
  action bad_reply_step = any { step, reconcile(true) }
  action bad_gc_step = any { step, pin(true) }
  action bad_resurrection_step = any { step, reference(true) }

  val publication = not(s.badPublication) and not(s.badParent)
  val fencing_and_outcomes = not(s.badFence) and s.effects1 <= 1 and (not(s.response1) or s.reply1 == s.outcome1)
  val gc = not(s.badGc) and not(s.deleted and (s.pinned or s.root)) and not(s.retired and s.root) and (not(s.deleted) or s.age >= 2)
}
