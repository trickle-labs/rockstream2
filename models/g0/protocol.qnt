// A finite abstraction: two publication attempts, two owner generations and one GC object.
// Depth-3 TLC: 11,746 depth-tagged configurations; separate Apalache symbolic bound: 11 steps.
module protocol {
  type State = {
    head: int, publicationHead: int, planRevision: int, preparedPlan: int, generation: int, prepared: bool, parent: int, revision: int, owner: int, preparedGeneration: int, refreshed: bool,
    receipts: Set[int], duplicate: bool, attempt: int, lastAttempt: int, abandonedAttempt: int, receipt1Attempt: int, receipt2Attempt: int, receipt1Id: int, receipt2Id: int, receipt1Object: int, receipt2Object: int, receipt1Scope: int, receipt2Scope: int, sealed: bool, sealedAttempt: int, sealedParent: int, sealedOwner: int, sealedPlan: int, sealedReceipt1: int, sealedReceipt2: int, sealedReceipts: Set[int], sealedDuplicate: bool, sealedReceipt1Attempt: int, sealedReceipt2Attempt: int, sealedReceipt1Scope: int, sealedReceipt2Scope: int, sealedReceipt1Object: int, sealedReceipt2Object: int, stageDurable: bool, stageProtected: bool, stageClosed: bool, stageDurabilityAdvanced: bool, publishedDataReady: bool, op: int, done1: bool, done2: bool, metadataDone: bool, effects1: int, publications: int, visible1: bool, visible2: bool,
    response1: bool, outcome1: int, reply1: int, pinned: bool, pinPending: bool, pinRevision: int, retirePending: bool, retireRevision: int, root: bool, retired: bool, deleted: bool, age: int,
    stalePublished: bool, badDataCommit: bool, badPlanCommit: bool, badSealCommit: bool, badPublication: bool, badParent: bool, badFence: bool, badGc: bool
  }
  var s: State

  action init = s' = {
    head: 0, publicationHead: 0, planRevision: 1, preparedPlan: 1, generation: 0, prepared: false, parent: 0, revision: 0, owner: 0, preparedGeneration: 0, refreshed: false,
    receipts: Set(), duplicate: false, attempt: 0, lastAttempt: 0, abandonedAttempt: 0, receipt1Attempt: 0, receipt2Attempt: 0, receipt1Id: 0, receipt2Id: 0, receipt1Object: 0, receipt2Object: 0, receipt1Scope: 0, receipt2Scope: 0, sealed: false, sealedAttempt: 0, sealedParent: 0, sealedOwner: 0, sealedPlan: 0, sealedReceipt1: 0, sealedReceipt2: 0, sealedReceipts: Set(), sealedDuplicate: false, sealedReceipt1Attempt: 0, sealedReceipt2Attempt: 0, sealedReceipt1Scope: 0, sealedReceipt2Scope: 0, sealedReceipt1Object: 0, sealedReceipt2Object: 0, stageDurable: false, stageProtected: false, stageClosed: false, stageDurabilityAdvanced: false, publishedDataReady: false, op: 1, done1: false, done2: false, metadataDone: false, effects1: 0, publications: 0, visible1: false, visible2: false,
    response1: false, outcome1: 0, reply1: 0, pinned: false, pinPending: false, pinRevision: 0, retirePending: false, retireRevision: 0, root: true, retired: false, deleted: false, age: 0,
    stalePublished: false, badDataCommit: false, badPlanCommit: false, badSealCommit: false, badPublication: false, badParent: false, badFence: false, badGc: false
  }

  action prepare(reuse) = {
    nondet operation = Set(1, 2).oneOf()
    nondet durable = Set(true, false).oneOf()
    nondet protected = Set(true, false).oneOf()
    all {
      not(s.prepared), not(s.retired), not(s.deleted), not(s.stageProtected),
      if (reuse) s.lastAttempt > 0 else s.lastAttempt < 2,
      s' = s.with("prepared", true).with("parent", s.publicationHead).with("revision", s.head)
        .with("owner", s.generation).with("preparedGeneration", s.generation).with("preparedPlan", s.planRevision).with("refreshed", false).with("receipts", Set()).with("duplicate", false).with("attempt", if (reuse) s.lastAttempt else s.lastAttempt + 1)
        .with("lastAttempt", if (reuse) s.lastAttempt else s.lastAttempt + 1).with("receipt1Attempt", 0).with("receipt2Attempt", 0).with("receipt1Id", 0).with("receipt2Id", 0).with("receipt1Object", 0).with("receipt2Object", 0).with("stageDurable", durable).with("stageProtected", protected).with("stageClosed", false).with("stageDurabilityAdvanced", false).with("receipt1Scope", 0).with("receipt2Scope", 0).with("sealed", false).with("op", operation)
    }
  }

  // Each partition may deliver once, duplicate, or arrive from an abandoned attempt.
  action receive = {
    nondet partition = Set(1, 2, 3).oneOf()
    nondet receiptAttempt = Set(1, 2).oneOf()
    nondet receiptId = Set(1, 2).oneOf()
    nondet receiptObject = Set(1, 2).oneOf()
    // Scope 1=(interval 1, plan 1), 2=(interval 2, plan 1), 3=(interval 1, plan 2).
    nondet receiptScope = Set(1, 2, 3).oneOf()
    all {
      s.prepared, not(s.sealed), not(s.duplicate),
      s' = s.with("receipts", s.receipts.union(Set(partition)))
        .with("duplicate", s.receipts.contains(partition))
        .with("receipt1Attempt", if (partition == 1 and not(s.receipts.contains(1))) receiptAttempt else s.receipt1Attempt)
        .with("receipt2Attempt", if (partition == 2 and not(s.receipts.contains(2))) receiptAttempt else s.receipt2Attempt)
        .with("receipt1Id", if (partition == 1 and not(s.receipts.contains(1))) receiptId else s.receipt1Id)
        .with("receipt2Id", if (partition == 2 and not(s.receipts.contains(2))) receiptId else s.receipt2Id)
        .with("receipt1Object", if (partition == 1 and not(s.receipts.contains(1))) receiptObject else s.receipt1Object)
        .with("receipt2Object", if (partition == 2 and not(s.receipts.contains(2))) receiptObject else s.receipt2Object)
        .with("receipt1Scope", if (partition == 1 and not(s.receipts.contains(1))) receiptScope else s.receipt1Scope)
        .with("receipt2Scope", if (partition == 2 and not(s.receipts.contains(2))) receiptScope else s.receipt2Scope)
    }
  }

  val expectedScope = if (s.preparedPlan == 1) 1 else 3

  val sealMatches = s.sealed and s.sealedAttempt == s.attempt and
    s.sealedParent == s.parent and s.sealedOwner == s.owner and s.sealedPlan == s.preparedPlan and
    s.sealedReceipt1 == s.receipt1Id and s.sealedReceipt2 == s.receipt2Id and
    s.sealedReceipts == s.receipts and s.sealedDuplicate == s.duplicate and
    s.sealedReceipt1Attempt == s.receipt1Attempt and s.sealedReceipt2Attempt == s.receipt2Attempt and
    s.sealedReceipt1Scope == s.receipt1Scope and s.sealedReceipt2Scope == s.receipt2Scope and
    s.sealedReceipt1Object == s.receipt1Object and s.sealedReceipt2Object == s.receipt2Object

  action seal(badReceipts) = all {
    s.prepared, not(s.sealed),
    (s.receipts == Set(1, 2) and not(s.duplicate) and
      s.receipt1Attempt == s.attempt and s.receipt2Attempt == s.attempt and
      s.receipt1Scope == expectedScope and s.receipt2Scope == expectedScope and
      s.receipt1Object == 1 and s.receipt2Object == 1) or badReceipts,
    s' = s.with("sealed", true).with("sealedAttempt", s.attempt)
      .with("sealedParent", s.parent).with("sealedOwner", s.owner).with("sealedPlan", s.preparedPlan)
      .with("sealedReceipt1", s.receipt1Id).with("sealedReceipt2", s.receipt2Id)
      .with("sealedReceipts", s.receipts).with("sealedDuplicate", s.duplicate)
      .with("sealedReceipt1Attempt", s.receipt1Attempt).with("sealedReceipt2Attempt", s.receipt2Attempt)
      .with("sealedReceipt1Scope", s.receipt1Scope).with("sealedReceipt2Scope", s.receipt2Scope)
      .with("sealedReceipt1Object", s.receipt1Object).with("sealedReceipt2Object", s.receipt2Object)
  }

  // The two expected partition receipts are bound to this prepared attempt.
  action publish(badReceipts, badOwner, badRetry, ignoreParent, ignoreRetirement, partial, ignoreRevision, ignoreSeal, ignorePlan, ignoreData) = all {
    s.prepared,
    s.parent == s.publicationHead or ignoreParent,
    s.revision == s.head or ignoreRevision,
    s.preparedPlan == s.planRevision or ignorePlan,
    (s.stageDurable and s.stageProtected) or ignoreData,
    sealMatches or ignoreSeal,
    (s.receipts == Set(1, 2) and not(s.duplicate) and s.receipt1Attempt == s.attempt and s.receipt2Attempt == s.attempt and
      s.receipt1Scope == expectedScope and s.receipt2Scope == expectedScope and
      s.receipt1Object == 1 and s.receipt2Object == 1) or badReceipts,
    s.owner == s.generation or badOwner,
    (s.op == 1 and (not(s.done1) or badRetry)) or (s.op == 2 and not(s.done2)),
    (not(s.retired) and not(s.deleted)) or ignoreRetirement,
    s.head < 3,
    s' = s.with("head", s.head + 1).with("publicationHead", s.publicationHead + 1).with("prepared", false).with("root", true)
      .with("badGc", s.badGc or s.retired or s.deleted)
      .with("done1", s.done1 or s.op == 1).with("done2", s.done2 or s.op == 2)
      .with("effects1", s.effects1 + if (s.op == 1) 1 else 0)
      .with("publications", s.publications + 1).with("visible1", true).with("visible2", not(partial))
      .with("stalePublished", s.stalePublished or (s.abandonedAttempt != 0 and s.attempt == s.abandonedAttempt and (s.receipt1Attempt == s.abandonedAttempt or s.receipt2Attempt == s.abandonedAttempt)))
      .with("outcome1", if (s.op == 1 and not(s.done1)) s.head + 1 else s.outcome1)
      .with("badSealCommit", s.badSealCommit or not(sealMatches))
      .with("badPlanCommit", s.badPlanCommit or s.preparedPlan != s.planRevision)
      .with("badDataCommit", s.badDataCommit or not(s.stageDurable and s.stageProtected))
      .with("publishedDataReady", s.stageDurable and s.stageProtected)
      .with("badParent", s.badParent or s.parent != s.publicationHead or s.revision != s.head)
      .with("badPublication", s.badPublication or s.receipts != Set(1, 2) or s.duplicate or (s.receipt1Attempt != s.attempt or s.receipt2Attempt != s.attempt) or s.receipt1Scope != expectedScope or s.receipt2Scope != expectedScope or s.receipt1Object != 1 or s.receipt2Object != 1)
      .with("badFence", s.badFence or s.preparedGeneration != s.generation)
  }
  action abandon = all { s.prepared, s' = s.with("prepared", false).with("abandonedAttempt", s.attempt) }
  action reassign = all { s.generation == 0, s.head < 3, s' = s.with("generation", 1).with("head", s.head + 1) }
  // Refresh only the CAS token; the prepared parent and generation stay fixed.
  action refresh(bad) = all {
    s.prepared, s.revision != s.head,
    s' = s.with("revision", s.head).with("refreshed", true)
      .with("owner", if (bad) s.generation else s.owner)
      .with("sealedOwner", if (bad) s.generation else s.sealedOwner)
  }
  // An independent valid publication can invalidate a prepared parent.
  action competingPublish = all {
    s.prepared, not(s.done2), not(s.retired), not(s.deleted), s.head < 3,
    s' = s.with("head", s.head + 1).with("publicationHead", s.publicationHead + 1)
      .with("done2", true).with("publications", s.publications + 1)
      .with("root", true).with("visible1", true).with("visible2", true).with("publishedDataReady", true)
  }
  // A committed response may be lost; retry consults durable outcome, even after head advances.
  action reconcile(wrongHead) = all { s.done1, not(s.response1), s' = s.with("response1", true).with("reply1", if (wrongHead) s.head else s.outcome1) }
  // An unrelated metadata operation advances the root, not a publication.
  action advance = all { not(s.metadataDone), s.head < 3, s' = s.with("head", s.head + 1).with("metadataDone", true) }
  // A plan revision changes under the same metadata root, without changing the publication parent.
  action changePlan = all { s.planRevision == 1, s.head < 3, s' = s.with("planRevision", 2).with("head", s.head + 1) }
  // The staged object represents one immutable object plus its recovery closure.
  action makeStageDurable = all { s.prepared, s.stageProtected, not(s.stageDurable), s' = s.with("stageDurable", true).with("stageDurabilityAdvanced", true) }
  action closeStage = all { s.stageProtected, s.head < 3, s' = s.with("stageProtected", false).with("stageClosed", true).with("head", s.head + 1) }
  action tick = all { s.age < 2, s' = s.with("age", s.age + 1) }
  // These pending operations read a snapshot and compete on the same metadata CAS.
  action preparePin = all {
    not(s.pinPending), not(s.pinned), not(s.retired),
    s' = s.with("pinPending", true).with("pinRevision", s.head)
  }
  action prepareRetire(bad) = all {
    not(s.retirePending), not(s.retired), not(s.pinned), not(s.root),
    not(s.stageProtected) or bad,
    s' = s.with("retirePending", true).with("retireRevision", s.head)
  }
  action refreshPin = all { s.pinPending, s.pinRevision != s.head, s' = s.with("pinRevision", s.head) }
  action refreshRetire = all { s.retirePending, s.retireRevision != s.head, s' = s.with("retireRevision", s.head) }
  action commitPin(bad) = all {
    s.pinPending, not(s.pinned), s.head < 3,
    (s.pinRevision == s.head and not(s.retired)) or bad,
    s' = s.with("pinPending", false).with("pinned", true).with("head", s.head + 1)
      .with("badGc", s.badGc or s.retired or s.pinRevision != s.head)
  }
  action commitRetire(bad) = all {
    s.retirePending, not(s.retired), s.head < 3,
    (s.retireRevision == s.head and not(s.pinned) and not(s.root) and not(s.stageProtected)) or bad,
    s' = s.with("retirePending", false).with("retired", true).with("head", s.head + 1)
      .with("badGc", s.badGc or s.pinned or s.root or s.retireRevision != s.head or s.stageProtected)
  }
  action unpin = all { s.pinned, s.head < 3, s' = s.with("pinned", false).with("head", s.head + 1) }
  action releaseRoot = all { s.root, s.head < 3, s' = s.with("root", false).with("visible1", false).with("visible2", false).with("head", s.head + 1) }
  action reference(bad) = all { not(s.root), s.head < 3, not(s.retired) or bad, s' = s.with("root", true).with("head", s.head + 1).with("badGc", s.badGc or s.retired) }
  action collect = all {
    s.retired, not(s.pinned), not(s.root), not(s.deleted), s.age >= 2,
    s' = s.with("deleted", true)
  }

  action step = any { prepare(false), receive, seal(false), publish(false, false, false, false, false, false, false, false, false, false), abandon, reassign,
    reconcile(false), advance, changePlan, refresh(false), makeStageDurable, closeStage, competingPublish, tick, preparePin, prepareRetire(false), refreshPin, refreshRetire, commitPin(false), commitRetire(false), unpin, releaseRoot, reference(false), collect }
  action tamperReceipt = all { s.prepared, s.sealed, s.receipt1Id != 3, s' = s.with("receipt1Id", 3) }
  action bad_seal_step = any { step, tamperReceipt, all { s.sealed, s.receipt1Id == 3, s.sealedReceipt1 != 3, publish(false, false, false, false, false, false, false, true, false, false) } }
  action bad_atomic_step = any { step, publish(false, false, false, false, false, true, false, false, false, false) }
  action bad_reuse_step = any { step, prepare(true) }
  action bad_publication_step = any { step, seal(true), publish(true, false, false, false, false, false, false, false, false, false) }
  action bad_fencing_step = any { step, publish(false, true, false, false, false, false, false, false, false, false) }
  action bad_retry_step = any { step, publish(false, false, true, false, false, false, false, false, false, false) }
  action bad_duplicate_step = any { step, all { s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), s.duplicate, s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == expectedScope, s.receipt2Scope == expectedScope, seal(true) }, all { s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), s.duplicate, s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == expectedScope, s.receipt2Scope == expectedScope, publish(true, false, false, false, false, false, false, false, false, false) } }
  action bad_foreign_step = any { step, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Scope == 1, s.receipt2Scope == 1, (s.receipt1Attempt != s.attempt or s.receipt2Attempt != s.attempt), seal(true) }, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Scope == 1, s.receipt2Scope == 1, (s.receipt1Attempt != s.attempt or s.receipt2Attempt != s.attempt), publish(true, false, false, false, false, false, false, false, false, false) } }
  action bad_missing_step = any { step, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipts == Set(1), s.receipt1Attempt == s.attempt, s.receipt1Scope == 1, seal(true) }, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipts == Set(1), s.receipt1Attempt == s.attempt, s.receipt1Scope == 1, publish(true, false, false, false, false, false, false, false, false, false) } }
  action bad_mixed_step = any { step, all { s.preparedPlan == 1, s.abandonedAttempt == 1, s.attempt == 2, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), s.receipt1Attempt == 1, s.receipt2Attempt == 2, s.receipt1Scope == 1, s.receipt2Scope == 1, not(s.duplicate), seal(true) }, all { s.preparedPlan == 1, s.abandonedAttempt == 1, s.attempt == 2, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), s.receipt1Attempt == 1, s.receipt2Attempt == 2, s.receipt1Scope == 1, s.receipt2Scope == 1, not(s.duplicate), publish(true, false, false, false, false, false, false, false, false, false) } }
  action bad_interval_step = any { step, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == 2, s.receipt2Scope == 1, seal(true) }, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == 2, s.receipt2Scope == 1, publish(true, false, false, false, false, false, false, false, false, false) } }
  action bad_plan_step = any { step, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == 3, s.receipt2Scope == 1, seal(true) }, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == 3, s.receipt2Scope == 1, publish(true, false, false, false, false, false, false, false, false, false) } }
  action bad_plan_revision_step = any { step, all { s.sealed, s.refreshed, s.preparedPlan == 1, s.sealedPlan == 1, s.planRevision == 2, s.parent == s.publicationHead, s.owner == s.generation, publish(false, false, false, false, false, false, false, false, true, false) } }
  action bad_foreign_object_step = any { step, all { s.stageDurable, s.stageProtected, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == expectedScope, s.receipt2Scope == expectedScope, s.receipt1Object == 2, s.receipt2Object == 1, seal(true) }, all { s.stageDurable, s.stageProtected, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == expectedScope, s.receipt2Scope == expectedScope, s.receipt1Object == 2, s.receipt2Object == 1, publish(true, false, false, false, false, false, false, false, false, false) } }
  action bad_undurable_step = any { step, all { s.sealed, not(s.stageDurable), s.stageProtected, publish(false, false, false, false, false, false, false, false, false, true) } }
  action bad_unprotected_step = any { step, all { s.sealed, s.stageDurable, s.stageClosed, not(s.stageProtected), publish(false, false, false, false, false, false, false, false, false, true) } }
  action bad_stage_retire_step = any { step, all { not(s.prepared), s.abandonedAttempt != 0, s.abandonedAttempt == s.attempt, s.stageProtected, prepareRetire(true) }, all { not(s.prepared), s.abandonedAttempt != 0, s.abandonedAttempt == s.attempt, s.stageProtected, not(s.root), not(s.pinned), s.retireRevision == s.head, commitRetire(true) } }
  action bad_refresh_step = any { step, refresh(true) }
  action bad_revision_step = any { step, publish(false, false, false, false, false, false, true, false, false, false) }
  action bad_parent_step = any { step, publish(false, false, false, true, false, false, false, false, false, false) }
  action bad_reply_step = any { step, reconcile(true) }
  action bad_pin_step = any { step, all { s.retired, commitPin(true) } }
  action bad_retire_step = any { step, all { s.pinned, commitRetire(true) } }
  // Both guards must be bypassed: a retired object cannot retain active staging protection.
  action bad_publish_retired_step = any { step, all { s.retired, s.stageDurable, not(s.stageProtected), publish(false, false, false, false, true, false, false, false, false, true) } }
  action bad_resurrection_step = any { step, reference(true) }
  action bad_young_collect_step = any {
    step,
    all {
      s.retired, not(s.pinned), not(s.root), not(s.deleted), s.age < 2,
      s' = s.with("deleted", true)
    }
  }
  action bad_unretired_collect_step = any {
    step,
    all {
      not(s.retired), not(s.pinned), not(s.root), not(s.deleted), not(s.stageProtected), s.age >= 2,
      s' = s.with("deleted", true)
    }
  }

  val publication = not(s.badDataCommit) and not(s.badPlanCommit) and not(s.badSealCommit) and not(s.badPublication) and not(s.badParent) and
    s.visible1 == s.visible2 and (not(s.visible1) or s.publications > 0)
  val fencing_and_outcomes = not(s.stalePublished) and not(s.badFence) and s.effects1 <= 1 and (not(s.response1) or s.reply1 == s.outcome1)
  val gc = (not(s.visible1) or s.publishedDataReady) and (not(s.visible1) or (s.root and not(s.retired) and not(s.deleted))) and not(s.badGc) and not(s.deleted and (s.pinned or s.root)) and not(s.retired and (s.root or s.pinned or s.stageProtected)) and (not(s.deleted) or (s.retired and s.age >= 2))
}
