# MetaTable Refactoring Plan

## Architecture decisions

**Master-dummy sync** → `MetaTableCatalog` (already owns the key→filepath mapping)
**File I/O + versioning** → `VersionedFile` mixin (Template Method pattern)
**Table variable management** → `Project.synchronizeMetaTableVariables()`
**GUI dialogs** → removed from MetaTable entirely; App already handles via events
**Display formatting** → standalone utility function
**Registration** → `MetaTableCatalog.registerMetaTable()` (MetaTable has no catalog knowledge)

---

## Phase 0 — Bug fixes and dead code

- [x] **0.1** Fix `contains()` → `ismember()`/`strcmp()` for exact ID matching (5 locations)
- [x] **0.2** Remove stale TODO comments, unused `ReferenceTable` property, `openMetaTableSelectionDialog()`
- [x] **0.2** Fix orphaned `synchFromMaster()` call in `appendTableRows` → catalog delegation

---

## Phase 1 — Public API cleanup

- [x] **1.1** `class()` override not present; `MetaTableClass` property used directly
- [x] **1.2** `MetaTableKey`, `MetaTableName` are `SetAccess=private`
- [x] **1.3** Remove deprecated `setMaster(keyword)`
- [x] **1.4** `filepath SetAccess` is `protected` (via VersionedFile)

---

## Phase 2 — Extract `VersionedFile` mixin

- [x] **2.1** `+nansen/+metadata/+mixin/@VersionedFile/VersionedFile.m` created
- [x] **2.2** MetaTable inherits mixin; `load()` delegates to parent, validation in `fromFileStruct()`

---

## Phase 3 — Move sync to MetaTableCatalog

- [x] **3.1** `getMasterFilePath`, `synchronizeToMaster`, `synchronizeFromMaster` on MetaTableCatalog
- [x] **3.2** MetaTable hooks delegate to catalog sync methods
- [x] **3.3** Old sync methods removed from MetaTable
- [x] **3.4** `linkToMaster()` removed entirely (was error-only stub)

---

## Phase 4 — Move catalog integration out of MetaTable

- [x] **4.1** `archive()` removed; all callers migrated to `MetaTableCatalog.registerMetaTable()`
  - `initializeSessionTable.m`, `initializeSubjectTable.m`: `catalog.registerMetaTable(metaTable, S)`
  - `App.m`: `metaTableCatalog.registerMetaTable(metatable, S_)`
  - `MetaTableCatalog.addMetatable()`: `obj.registerMetaTable(metaTable, options)`
  - `MetaTable.save()`: raises error if filepath not set
- [x] **4.2** `setDefault()` removed; `App.m` calls `MetaTableCatalog.setDefaultMetaTable()` directly

---

## Phase 5 — Move table variable management to Project

- [x] **5.1** `Project.synchronizeMetaTableVariables()` exists and is called from `appendTableRows`
- [x] **5.2** Deprecated methods removed: `checkIfMetaTableComplete`, `addMissingVarsToMetaTable`,
  `removeMissingVarsFromMetaTable`, `getTableVariableUpdateFunction`

**Note:** `appendTableRows` still calls `nansen.getCurrentProject()` to get the project reference.
This uses the correct API but obtains the project globally. Full dependency injection would require
threading a `Project` parameter through the public `addEntries`/`addTable` API — deferred.

---

## Phase 6 — Move display formatting to utility

- [x] **6.1** `nansen.metadata.utility.formatTableForDisplay()` created
- [x] **6.2** Callers updated to use utility directly
- [x] **6.3** `getFormattedTableData()` removed

---

## Dead code sweep (post-Phase 6)

- [x] Remove `isMaster()`, `getName()`, `getKey()` — deprecated accessors with no callers
- [x] Remove `getFormattedTableData()`, `appendTable()` — deprecated wrappers with no callers
- [x] Remove `linkToMaster()` — error-only stub with no callers
- [x] Remove `assertValidClass()` — never called (`addEntries` does inline validation)
- [x] Remove `openMetaTableFromFilepath()` — inlined into `open()`
- [x] Remove `openDefault()` — half-implemented, no callers
- [x] Remove `dispStruct()` — standalone function, never called
- [x] Rename `isDummy(dbRef)` → `hasSameMasterKey(otherMetaTable)`
- [x] Remove commented-out code in `fromStruct()`
- [x] Fix `load()` duplication — delegates to `VersionedFile.load()`, validation in `fromFileStruct()`
- [x] Migrate `getName()` callers in App.m to `.MetaTableName`
- [x] Update class docstring

---

## Phase 7 — MetaObject caching (deferred)

Low urgency. No structural problem causes current issues. Defer until Phases 1–6 are stable.
Future shape: `MetaObjectRegistry` class; MetaTable delegates to it.

---

## Remaining known items

| Item | Priority | Notes |
|---|---|---|
| `appendTableRows` calls `nansen.getCurrentProject()` | Low | Uses correct API; full DI deferred |
| Phase 7 MetaObject caching | Low | Isolated; no urgency |
