// A finite abstraction: two publication attempts, two owner generations and one GC object.
// Bounds and verification results are recorded with their exact source in evidence.
module protocol {
  type State = {
    head: int, publicationHead: int, preparedDigest: int, sealedDigest: int, digest1: int, digest2: int, committedDigest1: int, committedDigest2: int, mismatch1: bool, mismatch2: bool, mismatchDigest1: int, mismatchDigest2: int, mismatchResult1: int, mismatchResult2: int, otherUploaded: bool, otherProtected: bool, otherBase: int, otherGeneration: int, otherKind: int, otherArgument: int, otherDigest: int, racerUploaded: bool, racerProtected: bool, racerBase: int, racerGeneration: int, racerKind: int, racerDone: bool, badOtherManifestCommit: bool, active: bool, runIncarnation: int, preparedRun: int, sealedRun: int, catalogRevision: int, preparedCatalog: int, sealedCatalog: int, planRevision: int, preparedPlan: int, generation: int, authorizedPublisher: int, preparedPublisher: int, sealedPublisher: int, committedVia: int, namespaceGeneration: int, namespaceOpen: bool, stageGeneration: int, prepared: bool, preparedAfterPublication: bool, parent: int, revision: int, owner: int, preparedGeneration: int, refreshed: bool, metadataSincePrepare: bool, refreshedAfterMetadata: bool, retryCount: int, retryDeferred: bool,
    clientFloor: int, clientRetained: bool, clientDigest: int, clientOutcome: int, clientEver: bool, clientGhostDigest: int, clientGhostOutcome: int, clientEffects: int, clientReplyIssued: bool, clientReplyFloor: int, clientReplyHead: int, clientReplyDigest: int, clientReplyKind: int, clientReplyValue: int, inputSegmentDurable: bool, inputAccepted: bool, inputUpper: int, inputProof: int, preparedUpper: int, preparedProof: int, sealedUpper: int, sealedProof: int, metadataGeneration: int, metadataPageUploaded: bool, metadataPageProtected: bool, metadataPageGeneration: int, metadataPageBase: int, metadataPageSelected: bool, rootPageReferenced: bool, rootPageProtected: bool, rootPageGeneration: int, receipts: Set[int], duplicate: bool, attempt: int, lastAttempt: int, abandonedAttempt: int, receipt1Attempt: int, receipt2Attempt: int, receipt1Id: int, receipt2Id: int, receipt1Object: int, receipt2Object: int, receipt1Scope: int, receipt2Scope: int, sealed: bool, sealDurable: bool, sealedAttempt: int, sealedParent: int, sealedOwner: int, sealedPlan: int, sealedReceipt1: int, sealedReceipt2: int, sealedReceipts: Set[int], sealedDuplicate: bool, sealedReceipt1Attempt: int, sealedReceipt2Attempt: int, sealedReceipt1Scope: int, sealedReceipt2Scope: int, sealedReceipt1Object: int, sealedReceipt2Object: int, stageDurable: bool, stageProtected: bool, stageClosed: bool, stageDurabilityAdvanced: bool, publishedDataReady: bool, op: int, done1: bool, done2: bool, metadataDone: bool, effects1: int, effects2: int, publications: int, visible1: bool, visible2: bool,
    responseDigest1: int, responseDigest2: int, responseHead1: int, responseHead2: int, response1: bool, outcome1: int, reply1: int, committed1: int, response2: bool, outcome2: int, reply2: int, committed2: int, pinned: bool, pinPending: bool, pinRevision: int, retirePending: bool, retireRevision: int, root: bool, retired: bool, deleted: bool, age: int,
    stalePublished: bool, badContextCommit: bool, badInputCommit: bool, badPageCommit: bool, badPublisherCommit: bool, badNamespaceCommit: bool, badDataCommit: bool, badPlanCommit: bool, badSealCommit: bool, badPublication: bool, badParent: bool, badFence: bool, badGc: bool
  }
  var s: State

  action init = s' = {
    head: 0, publicationHead: 0, preparedDigest: 0, sealedDigest: 0, digest1: 0, digest2: 0, committedDigest1: 0, committedDigest2: 0, mismatch1: false, mismatch2: false, mismatchDigest1: 0, mismatchDigest2: 0, mismatchResult1: 0, mismatchResult2: 0, otherUploaded: false, otherProtected: false, otherBase: 0, otherGeneration: 0, otherKind: 0, otherArgument: 0, otherDigest: 0, racerUploaded: false, racerProtected: false, racerBase: 0, racerGeneration: 0, racerKind: 0, racerDone: false, badOtherManifestCommit: false, active: true, runIncarnation: 1, preparedRun: 1, sealedRun: 1, catalogRevision: 1, preparedCatalog: 1, sealedCatalog: 1, planRevision: 1, preparedPlan: 1, generation: 0, authorizedPublisher: 1, preparedPublisher: 0, sealedPublisher: 0, committedVia: 0, namespaceGeneration: 0, namespaceOpen: true, stageGeneration: 0, prepared: false, preparedAfterPublication: false, parent: 0, revision: 0, owner: 0, preparedGeneration: 0, refreshed: false, metadataSincePrepare: false, refreshedAfterMetadata: false, retryCount: 0, retryDeferred: false,
    clientFloor: 1, clientRetained: false, clientDigest: 0, clientOutcome: 0, clientEver: false, clientGhostDigest: 0, clientGhostOutcome: 0, clientEffects: 0, clientReplyIssued: false, clientReplyFloor: 0, clientReplyHead: 0, clientReplyDigest: 0, clientReplyKind: 0, clientReplyValue: 0, inputSegmentDurable: false, inputAccepted: false, inputUpper: 0, inputProof: 0, preparedUpper: 1, preparedProof: 1, sealedUpper: 0, sealedProof: 0, metadataGeneration: 0, metadataPageUploaded: false, metadataPageProtected: false, metadataPageGeneration: 0, metadataPageBase: 0, metadataPageSelected: false, rootPageReferenced: true, rootPageProtected: true, rootPageGeneration: 0, receipts: Set(), duplicate: false, attempt: 0, lastAttempt: 0, abandonedAttempt: 0, receipt1Attempt: 0, receipt2Attempt: 0, receipt1Id: 0, receipt2Id: 0, receipt1Object: 0, receipt2Object: 0, receipt1Scope: 0, receipt2Scope: 0, sealed: false, sealDurable: false, sealedAttempt: 0, sealedParent: 0, sealedOwner: 0, sealedPlan: 0, sealedReceipt1: 0, sealedReceipt2: 0, sealedReceipts: Set(), sealedDuplicate: false, sealedReceipt1Attempt: 0, sealedReceipt2Attempt: 0, sealedReceipt1Scope: 0, sealedReceipt2Scope: 0, sealedReceipt1Object: 0, sealedReceipt2Object: 0, stageDurable: false, stageProtected: false, stageClosed: false, stageDurabilityAdvanced: false, publishedDataReady: false, op: 1, done1: false, done2: false, metadataDone: false, effects1: 0, effects2: 0, publications: 0, visible1: false, visible2: false,
    responseDigest1: 0, responseDigest2: 0, responseHead1: 0, responseHead2: 0, response1: false, outcome1: 0, reply1: 0, committed1: 0, response2: false, outcome2: 0, reply2: 0, committed2: 0, pinned: false, pinPending: false, pinRevision: 0, retirePending: false, retireRevision: 0, root: true, retired: false, deleted: false, age: 0,
    stalePublished: false, badContextCommit: false, badInputCommit: false, badPageCommit: false, badPublisherCommit: false, badNamespaceCommit: false, badDataCommit: false, badPlanCommit: false, badSealCommit: false, badPublication: false, badParent: false, badFence: false, badGc: false
  }

  // A non-publication root change uploads one immutable compact manifest.
  // The kind binds it to the intended transition; argument binds input upper.
  // 1=input, 2=deactivate, 3=run, 4=catalog, 5=owner, 6=advance,
  // 7=plan, 8=stage close, 9=pin, 10=retire, 11=unpin, 12=root release,
  // 13=reference, 14=competing publication, 15=allocation-generation close,
  // 16=client rejection, 17=client outcome expiry.
  action uploadOtherManifest = {
    nondet kind = Set(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17).oneOf()
    nondet argument = Set(0, 1).oneOf()
    nondet digest = Set(1, 2).oneOf()
    all {
      not(s.otherUploaded), s.head < 5,
      kind != 9 or (s.pinPending and s.pinRevision == s.head),
      kind != 10 or (s.retirePending and s.retireRevision == s.head),
      s' = s.with("otherUploaded", true).with("otherProtected", true)
        .with("otherBase", s.head).with("otherGeneration", s.metadataGeneration)
        .with("otherKind", kind).with("otherArgument", if (kind == 1) argument else 0)
        .with("otherDigest", if (kind == 1 or kind == 14 or kind == 16) digest else 0)
    }
  }
  action discardOtherManifest = all {
    s.otherUploaded,
    s' = s.with("otherUploaded", false).with("otherProtected", false)
  }
  def otherMatches(kind) = s.otherUploaded and s.otherProtected and
    s.otherKind == kind and s.otherBase == s.head and s.otherGeneration == s.metadataGeneration
  def selectOther(kind) = s.with("rootPageReferenced", true).with("rootPageProtected", s.otherProtected)
    .with("rootPageGeneration", s.otherGeneration)
    .with("badOtherManifestCommit", s.badOtherManifestCommit or not(otherMatches(kind)))
    .with("otherUploaded", false).with("otherProtected", false)

  // An independently uploaded contender can change the root or close a generation.
  action uploadRacer = {
    nondet kind = Set(1, 2, 9, 10).oneOf()
    all {
      not(s.racerUploaded), not(s.racerDone), s.head < 5,
      kind != 9 or (s.pinPending and s.pinRevision == s.head),
      kind != 10 or (s.retirePending and s.retireRevision == s.head),
      s' = s.with("racerUploaded", true).with("racerProtected", true)
        .with("racerBase", s.head).with("racerGeneration", s.metadataGeneration).with("racerKind", kind)
    }
  }
  action discardRacer = all {
    s.racerUploaded,
    s' = s.with("racerUploaded", false).with("racerProtected", false)
  }
  action commitRacer = all {
    s.racerUploaded, s.racerProtected, not(s.racerDone), s.head < 5,
    s.racerBase == s.head, s.racerGeneration == s.metadataGeneration,
    s.racerKind == 1 or (s.racerKind == 2 and s.metadataGeneration == 0) or
      (s.racerKind == 9 and s.pinPending and not(s.pinned) and not(s.retired) and s.pinRevision == s.head) or
      (s.racerKind == 10 and s.retirePending and not(s.retired) and not(s.pinned) and not(s.root) and not(s.stageProtected) and s.retireRevision == s.head),
    s' = s.with("head", s.head + 1).with("racerDone", true)
      .with("rootPageReferenced", true).with("rootPageProtected", true).with("rootPageGeneration", s.racerGeneration)
      .with("metadataGeneration", if (s.racerKind == 2) 1 else s.metadataGeneration)
      .with("metadataPageProtected", if (s.racerKind == 2 and not(s.metadataPageSelected)) false else s.metadataPageProtected)
      .with("pinned", if (s.racerKind == 9) true else s.pinned)
      .with("pinPending", if (s.racerKind == 9) false else s.pinPending)
      .with("retired", if (s.racerKind == 10) true else s.retired)
      .with("retirePending", if (s.racerKind == 10) false else s.retirePending)
      .with("racerUploaded", false).with("racerProtected", false)
  }

  // Logical publisher identity is authenticated; credential forgery is outside this model.
  action prepare(reuse) = {
    nondet operation = Set(1, 2).oneOf()
    nondet payload = Set(1, 2).oneOf()
    nondet publisher = Set(1, 2).oneOf()
    nondet claimedProof = Set(1, 2).oneOf()
    all {
      not(s.prepared), not(s.retired), not(s.deleted), s.active,
      s.namespaceOpen, s.namespaceGeneration == s.generation,
      not(s.stageProtected) or s.stageGeneration == s.namespaceGeneration,
      if (reuse) s.lastAttempt > 0 else s.lastAttempt < 2,
      s' = s.with("prepared", true).with("preparedAfterPublication", s.publications > 0).with("parent", s.publicationHead).with("revision", s.head)
        .with("preparedDigest", payload).with("preparedRun", s.runIncarnation).with("preparedCatalog", s.catalogRevision).with("preparedUpper", 1).with("preparedProof", claimedProof).with("metadataPageUploaded", false).with("metadataPageProtected", false).with("metadataPageSelected", false).with("owner", s.generation).with("preparedPublisher", publisher).with("preparedGeneration", s.generation).with("preparedPlan", s.planRevision).with("refreshed", false).with("metadataSincePrepare", false).with("refreshedAfterMetadata", false).with("retryCount", 0).with("retryDeferred", false).with("receipts", Set()).with("duplicate", false).with("attempt", if (reuse) s.lastAttempt else s.lastAttempt + 1)
        .with("lastAttempt", if (reuse) s.lastAttempt else s.lastAttempt + 1).with("receipt1Attempt", 0).with("receipt2Attempt", 0).with("receipt1Id", 0).with("receipt2Id", 0).with("receipt1Object", 0).with("receipt2Object", 0).with("stageDurable", false).with("stageProtected", true).with("stageGeneration", s.namespaceGeneration).with("stageClosed", false).with("stageDurabilityAdvanced", false).with("receipt1Scope", 0).with("receipt2Scope", 0).with("sealed", false).with("sealDurable", false).with("op", operation)
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

  val sealMatches = s.sealed and s.sealedAttempt == s.attempt and s.sealedDigest == s.preparedDigest and
    s.sealedRun == s.preparedRun and s.sealedCatalog == s.preparedCatalog and
    s.sealedUpper == s.preparedUpper and s.sealedProof == s.preparedProof and
    s.sealedParent == s.parent and s.sealedOwner == s.owner and s.sealedPublisher == s.preparedPublisher and s.sealedPlan == s.preparedPlan and
    s.sealedReceipt1 == s.receipt1Id and s.sealedReceipt2 == s.receipt2Id and
    s.sealedReceipts == s.receipts and s.sealedDuplicate == s.duplicate and
    s.sealedReceipt1Attempt == s.receipt1Attempt and s.sealedReceipt2Attempt == s.receipt2Attempt and
    s.sealedReceipt1Scope == s.receipt1Scope and s.sealedReceipt2Scope == s.receipt2Scope and
    s.sealedReceipt1Object == s.receipt1Object and s.sealedReceipt2Object == s.receipt2Object

  action seal(badReceipts, badInput) = all {
    s.prepared, not(s.sealed),
    (s.inputAccepted and s.inputSegmentDurable and s.preparedUpper <= s.inputUpper and s.preparedProof == s.inputProof) or badInput,
    (s.receipts == Set(1, 2) and not(s.duplicate) and
      s.receipt1Attempt == s.attempt and s.receipt2Attempt == s.attempt and
      s.receipt1Scope == expectedScope and s.receipt2Scope == expectedScope and
      s.receipt1Object == 1 and s.receipt2Object == 1) or badReceipts,
    s' = s.with("sealed", true).with("sealedDigest", s.preparedDigest).with("sealedRun", s.preparedRun).with("sealedCatalog", s.preparedCatalog).with("sealedUpper", s.preparedUpper).with("sealedProof", s.preparedProof).with("sealedAttempt", s.attempt)
      .with("sealedParent", s.parent).with("sealedOwner", s.owner).with("sealedPublisher", s.preparedPublisher).with("sealedPlan", s.preparedPlan)
      .with("sealedReceipt1", s.receipt1Id).with("sealedReceipt2", s.receipt2Id)
      .with("sealedReceipts", s.receipts).with("sealedDuplicate", s.duplicate)
      .with("sealedReceipt1Attempt", s.receipt1Attempt).with("sealedReceipt2Attempt", s.receipt2Attempt)
      .with("sealedReceipt1Scope", s.receipt1Scope).with("sealedReceipt2Scope", s.receipt2Scope)
      .with("sealedReceipt1Object", s.receipt1Object).with("sealedReceipt2Object", s.receipt2Object)
  }

  // An immutable validation record becomes durable separately from sealing.
  action persistSeal = all {
    s.prepared, s.sealed, not(s.sealDurable), s.stageProtected,
    s' = s.with("sealDurable", true)
  }

  // Input segment upload precedes its durable root acceptance.
  action makeInputDurable = all { not(s.inputSegmentDurable), s' = s.with("inputSegmentDurable", true) }
  // One client-generation/sequence identity; digests 1 and 2 represent different bytes.
  action acceptInputWith(upper, digest, bypassFloor) = all {
    otherMatches(1), s.inputSegmentDurable, not(s.clientRetained), s.clientFloor == 1 or bypassFloor, s.head < 5,
    s' = selectOther(1).with("inputAccepted", true).with("inputUpper", upper).with("inputProof", 1).with("head", s.head + 1)
      .with("clientRetained", true).with("clientDigest", digest).with("clientOutcome", s.head + 1)
      .with("clientEver", true).with("clientGhostDigest", if (s.clientEver) s.clientGhostDigest else digest)
      .with("clientGhostOutcome", if (s.clientEver) s.clientGhostOutcome else s.head + 1)
      .with("clientEffects", s.clientEffects + 1)
  }
  action acceptInput = {
    acceptInputWith(s.otherArgument, s.otherDigest, false)
  }
  // A definitive rejected result is durable and consumes the same identity.
  action rejectClientWith(digest) = all {
    not(s.clientRetained), s.clientFloor == 1, s.head < 5, otherMatches(16),
    s' = selectOther(16).with("head", s.head + 1).with("clientRetained", true).with("clientDigest", digest)
      .with("clientOutcome", -1).with("clientEver", true)
      .with("clientGhostDigest", if (s.clientEver) s.clientGhostDigest else digest)
      .with("clientGhostOutcome", if (s.clientEver) s.clientGhostOutcome else -1)
  }
  action rejectClient = {
    rejectClientWith(s.otherDigest)
  }
  // Pruning a detailed outcome atomically advances its durable replay floor.
  action expireClient = all {
    s.clientRetained, s.clientFloor == 1, s.head < 5, otherMatches(17),
    s' = selectOther(17).with("head", s.head + 1).with("clientFloor", 2).with("clientRetained", false)
      .with("clientDigest", 0).with("clientOutcome", 0)
  }
  // 1=replay the original result, 2=payload conflict, 3=expired identity.
  action retryClient(badConflict, badExpiry) = {
    nondet digest = Set(1, 2).oneOf()
    all {
      s.clientEver, not(s.clientReplyIssued), s.clientFloor > 1 or s.clientRetained,
      s' = s.with("clientReplyIssued", true).with("clientReplyFloor", s.clientFloor).with("clientReplyHead", s.head).with("clientReplyDigest", digest)
        .with("clientReplyKind", if (s.clientFloor > 1) { if (badExpiry) 1 else 3 } else if (digest != s.clientDigest) { if (badConflict) 1 else 2 } else 1)
        .with("clientReplyValue", if (s.clientFloor > 1) { if (badExpiry) s.head else 0 } else if (digest != s.clientDigest) { if (badConflict) s.clientOutcome else 0 } else s.clientOutcome)
    }
  }
  // Valid metadata pages are built from the current root in its open allocation generation.
  action uploadMetadataPage = all {
    s.prepared, s.sealed, not(s.metadataPageUploaded), s.revision == s.head,
    s' = s.with("metadataPageUploaded", true).with("metadataPageProtected", true)
      .with("metadataPageGeneration", s.metadataGeneration).with("metadataPageBase", s.head)
  }
  action discardMetadataPage = all {
    s.prepared, s.metadataPageUploaded,
    s' = s.with("metadataPageUploaded", false).with("metadataPageProtected", false)
  }
  // Closing a generation forbids new adoption of unselected pages; it is not physical deletion.
  action closeMetadataGeneration = all {
    s.metadataGeneration == 0, s.head < 5, otherMatches(15),
    s' = selectOther(15).with("metadataGeneration", 1)
      .with("metadataPageProtected", if (s.metadataPageSelected) s.metadataPageProtected else false)
      .with("head", s.head + 1)
  }
  val inputMatches = s.inputSegmentDurable and s.inputAccepted and s.sealedUpper <= s.inputUpper and
    s.sealedProof == s.inputProof and s.sealedProof != 0
  val metadataPageGenerationMatches = s.metadataPageUploaded and s.metadataPageProtected and
    s.metadataPageGeneration == s.metadataGeneration
  val metadataPageBaseMatches = s.metadataPageUploaded and s.metadataPageBase == s.head
  val metadataPageMatches = metadataPageGenerationMatches and metadataPageBaseMatches

  val namespaceMatches = s.namespaceOpen and s.namespaceGeneration == s.generation and
    s.stageGeneration == s.preparedGeneration and s.stageGeneration == s.namespaceGeneration

  // The two expected partition receipts are bound to this prepared attempt.
  action publish(badReceipts, badOwner, badRetry, ignoreParent, ignoreRetirement, partial, ignoreRevision, ignoreSeal, ignorePlan, ignoreData, omitOutcome, ignoreNamespace, ignorePublisher, bypass) = {
    // The committer is recorded only for witnesses and grants no authority.
    nondet committer = Set(1, 2).oneOf()
    all {
    s.prepared,
    s.active or bypass.contains(1),
    s.preparedRun == s.runIncarnation or bypass.contains(2),
    s.preparedCatalog == s.catalogRevision or bypass.contains(3),
    inputMatches or bypass.contains(4),
    metadataPageGenerationMatches or bypass.contains(5),
    metadataPageBaseMatches or bypass.contains(6),
    s.parent == s.publicationHead or ignoreParent,
    s.revision == s.head or ignoreRevision,
    s.preparedPlan == s.planRevision or ignorePlan,
    (s.stageDurable and s.stageProtected) or ignoreData,
    namespaceMatches or ignoreNamespace,
    (sealMatches and s.sealDurable) or ignoreSeal,
    (s.receipts == Set(1, 2) and not(s.duplicate) and s.receipt1Attempt == s.attempt and s.receipt2Attempt == s.attempt and
      s.receipt1Scope == expectedScope and s.receipt2Scope == expectedScope and
      s.receipt1Object == 1 and s.receipt2Object == 1) or badReceipts,
    s.owner == s.generation or badOwner,
    s.preparedPublisher == s.authorizedPublisher or ignorePublisher,
    (s.op == 1 and (not(s.done1) or badRetry)) or (s.op == 2 and (not(s.done2) or badRetry)),
    (not(s.retired) and not(s.deleted)) or ignoreRetirement,
    s.head < 5,
    s' = s.with("head", s.head + 1).with("publicationHead", s.publicationHead + 1).with("prepared", false).with("root", true)
      .with("badGc", s.badGc or s.retired or s.deleted)
      .with("badContextCommit", s.badContextCommit or not(s.active) or s.preparedRun != s.runIncarnation or s.preparedCatalog != s.catalogRevision)
      .with("badInputCommit", s.badInputCommit or not(inputMatches))
      .with("badPageCommit", s.badPageCommit or not(metadataPageMatches))
      .with("metadataPageSelected", true)
      .with("rootPageReferenced", true).with("rootPageProtected", s.metadataPageProtected)
      .with("rootPageGeneration", s.metadataPageGeneration)
      .with("badNamespaceCommit", s.badNamespaceCommit or not(namespaceMatches))
      .with("badPublisherCommit", s.badPublisherCommit or s.preparedPublisher != s.authorizedPublisher)
      .with("committedVia", committer)
      .with("done1", s.done1 or s.op == 1).with("done2", s.done2 or s.op == 2)
      .with("effects1", s.effects1 + if (s.op == 1) 1 else 0)
      .with("effects2", s.effects2 + if (s.op == 2) 1 else 0)
      .with("publications", s.publications + 1).with("visible1", true).with("visible2", not(partial))
      .with("stalePublished", s.stalePublished or (s.abandonedAttempt != 0 and s.attempt == s.abandonedAttempt and (s.receipt1Attempt == s.abandonedAttempt or s.receipt2Attempt == s.abandonedAttempt)))
      .with("outcome1", if (s.op == 1 and not(s.done1) and not(omitOutcome)) s.head + 1 else s.outcome1)
      .with("committed1", if (s.op == 1 and not(s.done1)) s.head + 1 else s.committed1)
      .with("digest1", if (s.op == 1 and not(s.done1)) s.preparedDigest else s.digest1)
      .with("committedDigest1", if (s.op == 1 and not(s.done1)) s.preparedDigest else s.committedDigest1)
      .with("outcome2", if (s.op == 2 and not(s.done2) and not(omitOutcome)) s.head + 1 else s.outcome2)
      .with("committed2", if (s.op == 2 and not(s.done2)) s.head + 1 else s.committed2)
      .with("digest2", if (s.op == 2 and not(s.done2)) s.preparedDigest else s.digest2)
      .with("committedDigest2", if (s.op == 2 and not(s.done2)) s.preparedDigest else s.committedDigest2)
      .with("badSealCommit", s.badSealCommit or not(sealMatches and s.sealDurable))
      .with("badPlanCommit", s.badPlanCommit or s.preparedPlan != s.planRevision)
      .with("badDataCommit", s.badDataCommit or not(s.stageDurable and s.stageProtected))
      .with("publishedDataReady", s.stageDurable and s.stageProtected)
      .with("badParent", s.badParent or s.parent != s.publicationHead or s.revision != s.head)
      .with("badPublication", s.badPublication or s.receipts != Set(1, 2) or s.duplicate or (s.receipt1Attempt != s.attempt or s.receipt2Attempt != s.attempt) or s.receipt1Scope != expectedScope or s.receipt2Scope != expectedScope or s.receipt1Object != 1 or s.receipt2Object != 1)
      .with("badFence", s.badFence or s.preparedGeneration != s.generation)
    }
  }
  action abandon = all { s.prepared, s' = s.with("prepared", false).with("abandonedAttempt", s.attempt) }
  // Changes to these root predicates invalidate older prepared publications.
  action deactivate = all { s.active, s.head < 5, otherMatches(2), s' = selectOther(2).with("active", false).with("head", s.head + 1) }
  action changeRun = all { s.runIncarnation == 1, s.head < 5, otherMatches(3), s' = selectOther(3).with("runIncarnation", 2).with("head", s.head + 1) }
  action changeCatalog = all { s.catalogRevision == 1, s.head < 5, otherMatches(4), s' = selectOther(4).with("catalogRevision", 2).with("head", s.head + 1) }
  // Owner generation and its preallocated namespace are registered in one CAS.
  action reassign(bad) = all {
    s.generation == 0, s.head < 5, otherMatches(5),
    s' = selectOther(5).with("generation", 1).with("authorizedPublisher", 2).with("namespaceGeneration", if (bad) 0 else 1)
      .with("namespaceOpen", true).with("head", s.head + 1)
  }
  // Refresh only the CAS token; the prepared parent and generation stay fixed.
  action refresh(bad) = all {
    s.prepared, s.revision != s.head, not(s.retryDeferred), s.retryCount < 1,
    s' = s.with("revision", s.head).with("refreshed", true).with("refreshedAfterMetadata", s.metadataSincePrepare).with("retryCount", s.retryCount + 1)
      .with("owner", if (bad) s.generation else s.owner)
      .with("sealedOwner", if (bad) s.generation else s.sealedOwner)
  }
  // A bounded retry episode can defer without discarding its protected work.
  action deferRetry = all {
    s.prepared, s.revision != s.head, s.retryCount == 1, not(s.retryDeferred),
    s' = s.with("retryDeferred", true)
  }
  action resumeRetry = all {
    s.prepared, s.retryDeferred,
    s' = s.with("retryDeferred", false).with("retryCount", 0)
  }
  // A faulty retry rebinds a stale sealed preparation to the new owner.
  action unsafeRetryRefence = all {
    s.prepared, s.sealed, s.sealDurable, s.retryDeferred, s.preparedGeneration != s.generation,
    s' = s.with("revision", s.head).with("owner", s.generation)
      .with("sealedOwner", s.generation).with("retryDeferred", false)
  }
  // An independent valid publication can invalidate a prepared parent.
  action competingPublish = all {
    s.prepared, s.active, s.inputAccepted, s.inputSegmentDurable, s.inputUpper >= 1, s.inputProof == 1, not(s.done2), not(s.retired), not(s.deleted), s.head < 5, otherMatches(14),
    s' = selectOther(14).with("head", s.head + 1).with("publicationHead", s.publicationHead + 1)
      .with("done2", true).with("effects2", s.effects2 + 1).with("outcome2", s.head + 1).with("committed2", s.head + 1).with("publications", s.publications + 1)
      .with("digest2", s.otherDigest).with("committedDigest2", s.otherDigest)
      .with("root", true).with("rootPageReferenced", true).with("rootPageProtected", true)
      .with("rootPageGeneration", s.metadataGeneration).with("visible1", true).with("visible2", true).with("publishedDataReady", true)
  }
  // A committed response may be lost; retry consults durable outcome, even after head advances.
  action reconcile(wrongHead) = {
    nondet digest = Set(1, 2).oneOf()
    all { s.done1, not(s.response1), digest == s.digest1,
      s' = s.with("response1", true).with("responseHead1", s.head).with("responseDigest1", digest).with("reply1", if (wrongHead) s.head else s.outcome1) }
  }
  action reconcile2(wrongHead) = {
    nondet digest = Set(1, 2).oneOf()
    all { s.done2, not(s.response2), digest == s.digest2,
      s' = s.with("response2", true).with("responseHead2", s.head).with("responseDigest2", digest).with("reply2", if (wrongHead) s.head else s.outcome2) }
  }
  // Mismatched publication payloads reject without changing the recorded result.
  action mismatchPub1(bad) = {
    nondet digest = Set(1, 2).oneOf()
    all { s.done1, not(s.mismatch1), digest != s.digest1,
      s' = s.with("mismatch1", true).with("mismatchDigest1", digest).with("mismatchResult1", if (bad) 1 else 2) }
  }
  action mismatchPub2(bad) = {
    nondet digest = Set(1, 2).oneOf()
    all { s.done2, not(s.mismatch2), digest != s.digest2,
      s' = s.with("mismatch2", true).with("mismatchDigest2", digest).with("mismatchResult2", if (bad) 1 else 2) }
  }
  // An unrelated metadata operation advances the root, not a publication.
  action advance = all { not(s.metadataDone), s.head < 5, otherMatches(6), s' = selectOther(6).with("head", s.head + 1).with("metadataDone", true).with("metadataSincePrepare", s.metadataSincePrepare or s.prepared) }
  // A plan revision changes under the same metadata root, without changing the publication parent.
  action changePlan = all { s.planRevision == 1, s.head < 5, otherMatches(7), s' = selectOther(7).with("planRevision", 2).with("head", s.head + 1) }
  // The staged object represents one immutable object plus its recovery closure.
  action makeStageDurable = all { s.prepared, s.stageProtected, not(s.stageDurable), s' = s.with("stageDurable", true).with("stageDurabilityAdvanced", true) }
  action closeStage = all {
    s.stageProtected, s.head < 5, otherMatches(8),
    s' = selectOther(8).with("stageProtected", false).with("stageClosed", true)
      .with("namespaceOpen", if (s.stageGeneration == s.namespaceGeneration) false else s.namespaceOpen)
      .with("head", s.head + 1)
  }
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
    s.pinPending, not(s.pinned), s.head < 5, otherMatches(9),
    (s.pinRevision == s.head and not(s.retired)) or bad,
    s' = selectOther(9).with("pinPending", false).with("pinned", true).with("head", s.head + 1)
      .with("badGc", s.badGc or s.retired or s.pinRevision != s.head)
  }
  action commitRetire(bad) = all {
    s.retirePending, not(s.retired), s.head < 5, otherMatches(10),
    (s.retireRevision == s.head and not(s.pinned) and not(s.root) and not(s.stageProtected)) or bad,
    s' = selectOther(10).with("retirePending", false).with("retired", true).with("head", s.head + 1)
      .with("badGc", s.badGc or s.pinned or s.root or s.retireRevision != s.head or s.stageProtected)
  }
  action unpin = all { s.pinned, s.head < 5, otherMatches(11), s' = selectOther(11).with("pinned", false).with("head", s.head + 1) }
  action releaseRoot = all { s.root, s.head < 5, otherMatches(12), s' = selectOther(12).with("root", false).with("visible1", false).with("visible2", false).with("head", s.head + 1) }
  action reference(bad) = all { not(s.root), s.head < 5, not(s.retired) or bad, otherMatches(13), s' = selectOther(13).with("root", true).with("head", s.head + 1).with("badGc", s.badGc or s.retired) }
  action collect = all {
    s.retired, not(s.pinned), not(s.root), not(s.deleted), s.age >= 2,
    s' = s.with("deleted", true)
  }

  action step = any { uploadOtherManifest, discardOtherManifest, uploadRacer, discardRacer, commitRacer, makeInputDurable, acceptInput, rejectClient, expireClient, retryClient(false, false), mismatchPub1(false), mismatchPub2(false), deactivate, changeRun, changeCatalog, prepare(false), receive, seal(false, false), persistSeal, uploadMetadataPage, discardMetadataPage, closeMetadataGeneration, publish(false, false, false, false, false, false, false, false, false, false, false, false, false, Set()), abandon, reassign(false),
    reconcile(false), reconcile2(false), advance, changePlan, refresh(false), deferRetry, resumeRetry, makeStageDurable, closeStage, competingPublish, tick, preparePin, prepareRetire(false), refreshPin, refreshRetire, commitPin(false), commitRetire(false), unpin, releaseRoot, reference(false), collect }
  // Fault: discard a definitive outcome without moving its durable floor.
  action unsafeForgetClient = all {
    s.clientRetained, s.head < 5, otherMatches(17),
    s' = selectOther(17).with("head", s.head + 1).with("clientRetained", false).with("clientDigest", 0).with("clientOutcome", 0)
  }
  action bad_forget_client_step = any { step, unsafeForgetClient }
  action bad_expired_accept_step = {
    any { step, acceptInputWith(s.otherArgument, s.otherDigest, true) }
  }
  action bad_client_conflict_step = any { step, retryClient(true, false) }
  action bad_client_expired_step = any { step, retryClient(false, true) }
  action bad_pub_mismatch1_step = any { step, mismatchPub1(true) }
  action bad_pub_mismatch2_step = any { step, mismatchPub2(true) }
  action tamperReceipt = all { s.prepared, s.sealed, s.receipt1Id != 3, s' = s.with("receipt1Id", 3) }
  // Fault controls bypass manifest predicates at commit; generation is a compound fault.
  action unsafeOtherAdvance = all {
    not(s.metadataDone), s.head < 5,
    s' = selectOther(6).with("head", s.head + 1).with("metadataDone", true)
  }
  action loseOtherProtection = all {
    s.otherUploaded, s.otherProtected,
    s' = s.with("otherProtected", false)
  }
  action bad_other_unprotected_step = any {
    step, loseOtherProtection,
    all { s.otherUploaded, not(s.otherProtected), s.otherKind == 6, s.otherBase == s.head,
      s.otherGeneration == s.metadataGeneration, unsafeOtherAdvance }
  }
  action bad_other_stale_step = any {
    step,
    all { s.otherUploaded, s.otherProtected, s.otherKind == 6, s.otherBase != s.head,
      s.otherGeneration == s.metadataGeneration, unsafeOtherAdvance }
  }
  action bad_other_generation_step = any {
    step,
    all { s.otherUploaded, s.otherProtected, s.otherKind == 6, s.otherBase != s.head,
      s.otherGeneration != s.metadataGeneration, unsafeOtherAdvance }
  }
  action bad_other_kind_step = any {
    step,
    all { s.otherUploaded, s.otherProtected, s.otherKind != 6, s.otherBase == s.head,
      s.otherGeneration == s.metadataGeneration, unsafeOtherAdvance }
  }
  // Mutants bypass only the named final check unless otherwise stated.
  action bad_active_step = any { step, all { not(s.active), publish(false, false, false, false, false, false, false, false, false, false, false, false, false, Set(1)) } }
  action bad_run_step = any { step, all { s.preparedRun != s.runIncarnation, publish(false, false, false, false, false, false, false, false, false, false, false, false, false, Set(2)) } }
  action bad_catalog_step = any { step, all { s.preparedCatalog != s.catalogRevision, publish(false, false, false, false, false, false, false, false, false, false, false, false, false, Set(3)) } }
  action badInputAcceptance = all {
    not(s.inputSegmentDurable), not(s.inputAccepted), s.head < 5, otherMatches(1), s.otherArgument == 1,
    s' = selectOther(1).with("inputAccepted", true).with("inputUpper", 1).with("inputProof", 1).with("head", s.head + 1)
  }
  action bad_input_accept_step = any { step, badInputAcceptance }
  // A faulty validator can seal a claimed input proof before it is accepted.
  action bad_input_publication_step = any {
    step, seal(false, true),
    all { not(inputMatches), publish(false, false, false, false, false, false, false, false, false, false, false, false, false, Set(4)) }
  }
  // Each mutation constrains the acceptance state at the actual publication,
  // rather than inferring it later from the sticky error marker.
  action bad_foreign_input_step = any {
    step,
    all { s.inputAccepted, s.inputSegmentDurable, s.inputUpper >= s.preparedUpper, s.preparedProof != s.inputProof, seal(false, true) },
    all { s.inputAccepted, s.inputSegmentDurable, s.inputUpper >= s.sealedUpper, s.sealedProof != s.inputProof,
      publish(false, false, false, false, false, false, false, false, false, false, false, false, false, Set(4)) }
  }
  action bad_future_input_step = any {
    step,
    all { s.inputAccepted, s.inputSegmentDurable, s.inputUpper < s.preparedUpper, s.preparedProof == s.inputProof, seal(false, true) },
    all { s.inputAccepted, s.inputSegmentDurable, s.inputUpper < s.sealedUpper, s.sealedProof == s.inputProof,
      publish(false, false, false, false, false, false, false, false, false, false, false, false, false, Set(4)) }
  }
  // Fault: allocation closure fails to retain a still-referenced root page.
  action unsafeCloseReferencedPage = all {
    s.publications > 0, s.prepared, s.preparedAfterPublication, s.rootPageReferenced, s.rootPageProtected,
    s.metadataGeneration == 0, s.head < 5, otherMatches(15),
    s' = selectOther(15).with("metadataGeneration", 1).with("rootPageProtected", false).with("head", s.head + 1)
  }
  action bad_root_page_step = any { step, unsafeCloseReferencedPage }
  // A page built from an old root remains stale even after the CAS token refreshes.
  action bad_page_base_step = any {
    step,
    all { s.metadataPageUploaded, s.metadataPageProtected, s.metadataPageGeneration == s.metadataGeneration, s.metadataPageBase != s.head,
      publish(false, false, false, false, false, false, false, false, false, false, false, false, false, Set(6)) }
  }
  // Compound fault: a stale allocator writes into a closed generation and the
  // final CAS also skips generation/protection validation.
  action unsafeUploadOldMetadataPage = all {
    s.prepared, s.sealed, s.sealDurable, not(s.metadataPageUploaded), s.metadataGeneration == 1, s.revision == s.head,
    s' = s.with("metadataPageUploaded", true).with("metadataPageProtected", false)
      .with("metadataPageGeneration", 0).with("metadataPageBase", s.head)
  }
  action bad_page_generation_step = any {
    step, unsafeUploadOldMetadataPage,
    all { s.metadataPageUploaded, not(s.metadataPageProtected), s.metadataPageGeneration != s.metadataGeneration,
      publish(false, false, false, false, false, false, false, false, false, false, false, false, false, Set(5)) }
  }
  action bad_publisher_step = any {
    step,
    all { s.preparedPublisher != s.authorizedPublisher,
      publish(false, false, false, false, false, false, false, false, false, false, false, false, true, Set()) }
  }
  action bad_namespace_step = any { step, reassign(true) }
  // Simulate closure failing to revoke a stale protection view, then bypass
  // the independent publication namespace check.
  action unsafeCloseNamespace = all {
    s.namespaceOpen, s.stageProtected, s.head < 5, otherMatches(8),
    s' = selectOther(8).with("namespaceOpen", false).with("head", s.head + 1)
  }
  action bad_namespace_publication_step = any {
    step, unsafeCloseNamespace,
    all { not(s.namespaceOpen), publish(false, false, false, false, false, false, false, false, false, false, false, true, false, Set()) }
  }
  action bad_retry_revalidation_step = any { step, unsafeRetryRefence, all { s.preparedGeneration != s.generation, publish(false, false, false, false, false, false, false, false, false, false, false, true, false, Set()) } }
  action bad_undurable_seal_step = any { step, all { s.sealed, not(s.sealDurable), publish(false, false, false, false, false, false, false, true, false, false, false, false, false, Set()) } }
  action bad_seal_step = any { step, tamperReceipt, all { s.sealed, s.sealDurable, s.receipt1Id == 3, s.sealedReceipt1 != 3, publish(false, false, false, false, false, false, false, true, false, false, false, false, false, Set()) } }
  action bad_atomic_step = any { step, publish(false, false, false, false, false, true, false, false, false, false, false, false, false, Set()) }
  action bad_reuse_step = any { step, prepare(true) }
  action bad_publication_step = any { step, seal(true, false), publish(true, false, false, false, false, false, false, false, false, false, false, false, false, Set()) }
  action bad_fencing_step = any { step, publish(false, true, false, false, false, false, false, false, false, false, false, true, false, Set()) }
  action bad_retry_step = any { step, all { s.op == 1, publish(false, false, true, false, false, false, false, false, false, false, false, false, false, Set()) } }
  action bad_duplicate_step = any { step, all { s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), s.duplicate, s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == expectedScope, s.receipt2Scope == expectedScope, seal(true, false) }, all { s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), s.duplicate, s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == expectedScope, s.receipt2Scope == expectedScope, publish(true, false, false, false, false, false, false, false, false, false, false, false, false, Set()) } }
  action bad_foreign_step = any { step, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Scope == 1, s.receipt2Scope == 1, (s.receipt1Attempt != s.attempt or s.receipt2Attempt != s.attempt), seal(true, false) }, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Scope == 1, s.receipt2Scope == 1, (s.receipt1Attempt != s.attempt or s.receipt2Attempt != s.attempt), publish(true, false, false, false, false, false, false, false, false, false, false, false, false, Set()) } }
  action bad_missing_step = any { step, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipts == Set(1), s.receipt1Attempt == s.attempt, s.receipt1Scope == 1, seal(true, false) }, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipts == Set(1), s.receipt1Attempt == s.attempt, s.receipt1Scope == 1, publish(true, false, false, false, false, false, false, false, false, false, false, false, false, Set()) } }
  action bad_mixed_step = any { step, all { s.preparedPlan == 1, s.abandonedAttempt == 1, s.attempt == 2, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), s.receipt1Attempt == 1, s.receipt2Attempt == 2, s.receipt1Scope == 1, s.receipt2Scope == 1, not(s.duplicate), seal(true, false) }, all { s.preparedPlan == 1, s.abandonedAttempt == 1, s.attempt == 2, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), s.receipt1Attempt == 1, s.receipt2Attempt == 2, s.receipt1Scope == 1, s.receipt2Scope == 1, not(s.duplicate), publish(true, false, false, false, false, false, false, false, false, false, false, false, false, Set()) } }
  action bad_interval_step = any { step, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == 2, s.receipt2Scope == 1, seal(true, false) }, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == 2, s.receipt2Scope == 1, publish(true, false, false, false, false, false, false, false, false, false, false, false, false, Set()) } }
  action bad_plan_step = any { step, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == 3, s.receipt2Scope == 1, seal(true, false) }, all { s.preparedPlan == 1, s.stageDurable, s.stageProtected, s.receipt1Object == 1, s.receipt2Object == 1, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == 3, s.receipt2Scope == 1, publish(true, false, false, false, false, false, false, false, false, false, false, false, false, Set()) } }
  action bad_plan_revision_step = any { step, all { s.sealed, s.refreshed, s.preparedPlan == 1, s.sealedPlan == 1, s.planRevision == 2, s.parent == s.publicationHead, s.owner == s.generation, publish(false, false, false, false, false, false, false, false, true, false, false, false, false, Set()) } }
  action bad_foreign_object_step = any { step, all { s.stageDurable, s.stageProtected, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == expectedScope, s.receipt2Scope == expectedScope, s.receipt1Object == 2, s.receipt2Object == 1, seal(true, false) }, all { s.stageDurable, s.stageProtected, s.receipts == Set(1, 2), not(s.duplicate), s.receipt1Attempt == s.attempt, s.receipt2Attempt == s.attempt, s.receipt1Scope == expectedScope, s.receipt2Scope == expectedScope, s.receipt1Object == 2, s.receipt2Object == 1, publish(true, false, false, false, false, false, false, false, false, false, false, false, false, Set()) } }
  action bad_undurable_step = any { step, all { s.sealed, not(s.stageDurable), s.stageProtected, publish(false, false, false, false, false, false, false, false, false, true, false, false, false, Set()) } }
  action bad_unprotected_step = any { step, all { s.sealed, s.stageDurable, s.stageClosed, not(s.stageProtected), publish(false, false, false, false, false, false, false, false, false, true, false, true, false, Set()) } }
  action bad_stage_retire_step = any { step, all { not(s.prepared), s.abandonedAttempt != 0, s.abandonedAttempt == s.attempt, s.stageProtected, prepareRetire(true) }, all { not(s.prepared), s.abandonedAttempt != 0, s.abandonedAttempt == s.attempt, s.stageProtected, not(s.root), not(s.pinned), s.retireRevision == s.head, commitRetire(true) } }
  action bad_refresh_step = any { step, refresh(true), all { s.preparedGeneration != s.generation, publish(false, false, false, false, false, false, false, false, false, false, false, true, false, Set()) } }
  // The page-base guard independently rejects a stale revision.
  action bad_revision_step = any { step, publish(false, false, false, false, false, false, true, false, false, false, false, false, false, Set()) }
  // Compound fault: stale CAS revision and the page built from that revision
  // are both admitted after the root advances.
  action bad_revision_and_page_step = any { step, all {
    s.metadataPageUploaded, s.metadataPageBase == s.revision, s.revision + 1 == s.head,
    publish(false, false, false, false, false, false, true, false, false, false, false, false, false, Set(6))
  } }
  action bad_parent_step = any { step, publish(false, false, false, true, false, false, false, false, false, false, false, false, false, Set()) }
  action bad_reply_step = any { step, reconcile(true) }
  action bad_pin_step = any { step, all { s.retired, commitPin(true) } }
  action bad_retire_step = any { step, all { s.pinned, commitRetire(true) } }
  // Retirement, staging and namespace fences must be bypassed together.
  action bad_publish_retired_step = any { step, all { s.retired, s.stageDurable, not(s.stageProtected), publish(false, false, false, false, true, false, false, false, false, true, false, true, false, Set()) } }
  action bad_retry2_step = any { step, all { s.op == 2, publish(false, false, true, false, false, false, false, false, false, false, false, false, false, Set()) } }
  action bad_missing_outcome1_step = any { step, all { s.op == 1, publish(false, false, false, false, false, false, false, false, false, false, true, false, false, Set()) } }
  action bad_missing_outcome2_step = any { step, all { s.op == 2, publish(false, false, false, false, false, false, false, false, false, false, true, false, false, Set()) } }
  action bad_corrupt_outcome1_step = any { step, all { s.done1, not(s.response1), s.outcome1 == s.committed1, s.head > s.outcome1, s' = s.with("outcome1", s.head) } }
  action bad_corrupt_outcome2_step = any { step, all { s.done2, not(s.response2), s.outcome2 == s.committed2, s.head > s.outcome2, s' = s.with("outcome2", s.head) } }
  action bad_reply2_step = any { step, reconcile2(true) }
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

  val publication = not(s.badOtherManifestCommit) and (not(s.rootPageReferenced) or s.rootPageProtected) and not(s.badContextCommit) and not(s.badInputCommit) and not(s.badPageCommit) and not(s.badNamespaceCommit) and not(s.badDataCommit) and not(s.badPlanCommit) and not(s.badSealCommit) and not(s.badPublication) and not(s.badParent) and
    s.visible1 == s.visible2 and (not(s.visible1) or s.publications > 0)
  val fencing_and_outcomes = (not(s.inputAccepted) or s.inputSegmentDurable) and
    s.clientEffects <= 1 and (not(s.clientEver) or s.clientGhostDigest > 0) and
    (not(s.clientRetained) or (s.clientFloor == 1 and s.clientDigest == s.clientGhostDigest and s.clientOutcome == s.clientGhostOutcome)) and
    (not(s.clientEver) or s.clientRetained or s.clientFloor > 1) and
    (not(s.clientEver) or s.clientGhostOutcome != -1 or (not(s.inputAccepted) and s.clientEffects == 0)) and
    (not(s.clientReplyIssued) or
      (if (s.clientReplyFloor > 1) s.clientReplyKind == 3
       else if (s.clientReplyDigest != s.clientGhostDigest) s.clientReplyKind == 2
       else s.clientReplyKind == 1 and s.clientReplyValue == s.clientGhostOutcome)) and
    (not(s.mismatch1) or (s.mismatchDigest1 != s.committedDigest1 and s.mismatchResult1 == 2)) and
    (not(s.mismatch2) or (s.mismatchDigest2 != s.committedDigest2 and s.mismatchResult2 == 2)) and not(s.badPublisherCommit) and (not(s.namespaceOpen) or s.namespaceGeneration == s.generation) and not(s.stalePublished) and not(s.badFence) and s.effects1 <= 1 and s.effects2 <= 1 and
    (not(s.done1) or (s.committed1 > 0 and s.outcome1 == s.committed1 and s.digest1 == s.committedDigest1 and s.digest1 > 0)) and
    (not(s.done2) or (s.committed2 > 0 and s.outcome2 == s.committed2 and s.digest2 == s.committedDigest2 and s.digest2 > 0)) and
    (not(s.response1) or (s.reply1 == s.outcome1 and s.responseDigest1 == s.committedDigest1)) and (not(s.response2) or (s.reply2 == s.outcome2 and s.responseDigest2 == s.committedDigest2))
  val gc = (not(s.visible1) or s.publishedDataReady) and (not(s.visible1) or (s.root and not(s.retired) and not(s.deleted))) and not(s.badGc) and not(s.deleted and (s.pinned or s.root)) and not(s.retired and (s.root or s.pinned or s.stageProtected)) and (not(s.deleted) or (s.retired and s.age >= 2))
}
