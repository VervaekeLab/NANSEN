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
- [ ] **0.2** Remove `updateEntries` (throws immediately, `Access=private`, never called)
- [ ] **0.2** Remove `openMetaTableFromName` (superseded by `MetaTable.open()`)

---

## Phase 1 — Public API cleanup (no structural moves)

- [ ] **1.1** Remove `class()` override; update callers in App.m (×2) and MetaTable internal uses to `obj.MetaTableClass`
- [ ] **1.2** Change `MetaTableKey`, `MetaTableName` to `SetAccess=private, GetAccess=public`; deprecate `getKey()` / `getName()`
- [ ] **1.3** Replace `setMaster(keyword)` with `setAsMaster()` / `setAsDummy()`; keep deprecated wrapper
- [ ] **1.4** Change `filepath SetAccess` from `{?MetaTable, ?App}` to `protected`

---

## Phase 2 — Extract `VersionedFile` mixin

- [ ] **2.1** Create `+nansen/+metadata/+mixin/@VersionedFile/VersionedFile.m`
  - Properties: `filepath (protected)`, `VersionNumber (protected)`
  - Abstract: `toFileStruct()`, `fromFileStruct(S)`
  - Protected hooks: `onBeforeSave()`, `onAfterLoad()` (default no-op)
  - Concrete: `save(force)`, `load()`, `isLatestVersion()`, `loadVersionNumber()`, `saveCopy(path)`
  - `save()` does NOT call `resolveCurrentVersion()` — version conflicts surface as events (already handled by MetaTableCache/App)

- [ ] **2.2** MetaTable inherits mixin
  - `classdef MetaTable < handle & nansen.metadata.mixin.VersionedFile`
  - Implement `toFileStruct()` (from `toStruct('metatable_file')`)
  - Implement `fromFileStruct(S)` (from `fromStruct()`)
  - Override `onAfterLoad()` → `synchFromMaster()` (temporary; moves in Phase 3)
  - Override `onBeforeSave()` → `synchToMaster(S)` (temporary; moves in Phase 3)
  - Remove duplicate `save()`, `load()`, `isLatestVersion()`, `loadVersionNumber()`, `saveCopy()`
  - Remove `resolveCurrentVersion()` from MetaTable (App already handles via `onMetaTableFileChangedOnDisk`)

---

## Phase 3 — Move sync to MetaTableCatalog (depends on Phase 2)

- [ ] **3.1** Add to MetaTableCatalog:
  - `getMasterFilePath(obj, metaTableKey)` — replaces `MetaTable.getMasterMetaTableFile()`
  - `synchronizeToMaster(obj, dummyMetaTable, S)` — replaces `MetaTable.synchToMaster()`
  - `synchronizeFromMaster(obj, dummyMetaTable)` — replaces `MetaTable.synchFromMaster()`

- [ ] **3.2** MetaTable's `onBeforeSave()` and `onAfterLoad()` delegate to catalog sync methods

- [ ] **3.3** Remove `synchToMaster`, `synchFromMaster`, `getMasterMetaTableFile` from MetaTable

- [ ] **3.4** Remove `linkToMaster()` GUI dialog from MetaTable; missing master → clear error; caller (App) handles recovery
  - Update `addTableVariable()` internal call to master propagation to go through catalog

---

## Phase 4 — Move catalog integration out of MetaTable (depends on Phase 3)

- [ ] **4.1** Add `MetaTableCatalog.registerMetaTable(metaTable, options)` (replaces `archive()`)
  - Generates/assigns MetaTableKey, sets filepath, adds catalog entry, calls `metaTable.save(true)`
  - Keep `archive()` as deprecated forwarding method
  - Callers: App.m, initializeSessionTable.m, initializeSubjectTable.m, MetaTableCatalog.addMetatable()

- [ ] **4.2** Add `MetaTableCatalog.setDefaultMetaTable(metaTable)` and `openDefaultMetaTable(class)`
  - Keep `setDefault()` / `openDefault()` as deprecated forwarders
  - Update App.m caller

---

## Phase 5 — Move table variable management to Project (independent of Phases 3–4)

- [ ] **5.1** Add `Project.synchronizeMetaTableVariables(metaTable, options)` consolidating `checkIfMetaTableComplete`, `addMissingVarsToMetaTable`, `removeMissingVarsFromMetaTable`
  - No call to `nansen.getCurrentProject()` — Project is the caller
  - Update callers: App.m (×2), updateSubjectTable.m, MetaTable.appendTableRows() internal call

- [ ] **5.2** Remove `checkIfMetaTableComplete`, `addMissingVarsToMetaTable`, `removeMissingVarsFromMetaTable`, `getTableVariableUpdateFunction` from MetaTable
  - MetaTable retains only: `addTableVariable`, `removeTableVariable`, `updateTableVariable`

---

## Phase 6 — Move display formatting to utility (independent, start any time)

- [ ] **6.1** Create `nansen.metadata.utility.formatTableForDisplay(metaTable, columnIndices, rowIndices)`
  - Move `getFormattedTableData()` logic and `getCustomDisplayString()` here

- [ ] **6.2** Update callers: App.m (×2), MetaTableViewer.m, MetaTable.onMetaObjectPropertyChanged()

- [ ] **6.3** Remove `getFormattedTableData()` and `getCustomDisplayString()` from MetaTable

---

## Phase 7 — MetaObject caching (deferred)

Low urgency. No structural problem causes current issues. Defer until Phases 1–6 are stable.
Future shape: `MetaObjectRegistry` class; MetaTable delegates to it.

---

## Risk register

| Step | Risk | Reason |
|---|---|---|
| 1.1 remove `class()` | Medium | Easy to miss external user code that relies on the semantic override |
| 2.2 VersionedFile inheritance | Medium | Changes inheritance chain; silent data corruption if hook ordering is wrong |
| 3.2/3.3 sync removal | Medium | `synchFromMaster` called during load; breakage is data corruption, not an error |
| 4.1 archive move | High | Most complex method; three external callers; UUID generation + filepath + catalog + save side effects |
| 5.1 variable sync to Project | Medium | `appendTableRows` calls `addMissingVarsToMetaTable` on a temp MetaTable internally |

---

## Execution order

```
Phase 0 (bugfixes)
Phase 1 (API cleanup)          Phase 5 (vars → Project)    Phase 6 (formatting)
Phase 2 (VersionedFile)
Phase 3 (sync → Catalog)
Phase 4 (catalog integration)
Phase 7 (deferred)
```

Phases 5 and 6 are independent and can run in parallel with Phases 2–4.
