# MetaTable Refactoring Plan

## Architecture decisions

**Master-dummy sync** → `MetaTableCatalog` (already owns the key→filepath mapping)
**File I/O + versioning** → `VersionedFile` mixin (Template Method pattern)
**Table variable management** → `Project.synchronizeMetaTableVariables()`
**GUI dialogs** → removed from MetaTable entirely; App already handles via events
**Display formatting** → standalone utility function

---

## Phase 0 — Bug fixes and dead code (start here)

- [x] **0.1** `removeEntries` (cell branch): `contains()` → `ismember()` for exact ID matching
- [x] **0.1** `removeEntries` (char branch): `contains()` → `strcmp()` for exact ID matching
- [x] **0.1** `linkToMaster`: `contains()` → `strcmp()` for class name matching
- [x] **0.1** `getAssociatedMetaTables` same_master: `contains()` → `strcmp()` for UUID key matching
- [x] **0.1** `getAssociatedMetaTables` same_class: `contains()` → `strcmp()` for class name matching
- [x] **0.2** Remove stale TODO comments from class header (already completed in earlier phases)
- [x] **0.2** Remove unused `ReferenceTable` property
- [x] **0.2** Remove `openMetaTableSelectionDialog()` (threw "Not implemented"; no callers)
- [x] **0.2** Fix orphaned `obj.synchFromMaster()` call in `appendTableRows` → catalog delegation

---

## Phase 1 — Public API cleanup (no structural moves)

- [x] **1.1** `class()` override not present; `MetaTableClass` property already used directly
- [x] **1.2** `MetaTableKey`, `MetaTableName` are `SetAccess=private` (no change needed)
- [x] **1.3** Remove deprecated `setMaster(keyword)`; `setAsMaster()` / `setAsDummy()` are the API
- [x] **1.4** `filepath SetAccess` is `protected` (already done in Phase 2)

---

## Phase 2 — Extract `VersionedFile` mixin

- [x] **2.1** `+nansen/+metadata/+mixin/@VersionedFile/VersionedFile.m` created
- [x] **2.2** MetaTable inherits mixin; implements `toFileStruct()`, `fromFileStruct()`, hooks

---

## Phase 3 — Move sync to MetaTableCatalog (depends on Phase 2)

- [x] **3.1** `getMasterFilePath`, `synchronizeToMaster`, `synchronizeFromMaster` on MetaTableCatalog
- [x] **3.2** MetaTable hooks delegate to catalog sync methods
- [x] **3.3** `synchToMaster`, `synchFromMaster`, `getMasterMetaTableFile` removed from MetaTable
- [x] **3.4** `linkToMaster()` GUI removed; all call sites now raise clear errors:
  - `MetaTable.archive()`: NANSEN:MetaTable:MasterKeyNotSet
  - `MetaTableCatalog.registerMetaTable()`: NANSEN:MetaTableCatalog:MasterKeyNotSet
  - `MetaTableCatalog.synchronizeFromMaster()`: NANSEN:MetaTableCatalog:MasterNotFound
  - `setAsDummy()` no longer calls `linkToMaster()`

---

## Phase 4 — Move catalog integration out of MetaTable (depends on Phase 3)

- [x] **4.1** `MetaTableCatalog.registerMetaTable()` replaces `archive()`; `archive()` is deprecated wrapper
- [x] **4.2** `MetaTableCatalog.setDefaultMetaTable()` replaces `setDefault()`

---

## Phase 5 — Move table variable management to Project (independent of Phases 3–4)

- [x] **5.1** `Project.synchronizeMetaTableVariables()` exists and is called from `appendTableRows`
- [x] **5.2** Removed from MetaTable:
  - `checkIfMetaTableComplete`
  - `addMissingVarsToMetaTable`
  - `removeMissingVarsFromMetaTable`
  - `getTableVariableUpdateFunction` (private helper)
  - `updateTableVariable()` fallback that called `getTableVariableUpdateFunction`
  - MetaTable retains: `addTableVariable`, `removeTableVariable`, `updateTableVariable`

---

## Phase 6 — Move display formatting to utility (independent, start any time)

- [x] **6.1** `nansen.metadata.utility.formatTableForDisplay()` created
- [x] **6.2** Callers updated to use utility directly
- [x] **6.3** `getFormattedTableData()` is a deprecated wrapper; `getCustomDisplayString()` removed

---

## Phase 7 — MetaObject caching (deferred)

Low urgency. No structural problem causes current issues. Defer until Phases 1–6 are stable.
Future shape: `MetaObjectRegistry` class; MetaTable delegates to it.

---

## Risk register

| Step | Risk | Reason |
|---|---|---|
| 7 MetaObject caching | Low | Isolated; no other phases depend on it |

---

## Execution order

All Phases 0–6 complete. Phase 7 deferred.
