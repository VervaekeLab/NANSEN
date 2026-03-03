# `FolderOrganizationUI` — Refactor Action Plan

## Background

`FolderOrganizationUI` is a `uifigure`-based table UI for editing the subfolder hierarchy of a data location. Over time it has accumulated several architectural problems:

- Dual data state (`obj.Data` vs UI controls)
- Layout managed via cumulative pixel offsets
- Preview window lifecycle entangled in the main class
- Template logic coupled to a global project state
- Callbacks used during internal rebuilds, requiring an `IsUpdating` flag workaround

This document describes a phased plan to address these problems incrementally without breaking existing behaviour.

---

## Dependency Order

```
Phase 1  ──▶  Phase 2  ──▶  Phase 3
                │
                └──────────▶  Phase 4  ──▶  Phase 5
```

Phases 1 and 2 must be completed in order. Phases 3 and 4 can proceed in parallel after Phase 2. Phase 5 is a cleanup sweep at the end.

---

## Phase 1 — Establish a stable foundation

> **Goal:** No behaviour changes. Make the existing code safe to refactor.

### 1.1 — Remove `obj.Data` as a dual state

- Audit every read of `obj.Data` — most are already superseded by direct control reads in `getSubfolderStructure()`
- Replace all remaining `obj.Data(i).X` reads with direct reads from `obj.RowControls(i)`
- Delete the `obj.Data` writes in `onCurrentDataLocationSet` and `subfolderChanged`
- Keep `obj.Data` only as a pass-through to the superclass constructor (which requires it), then treat it as write-once
- Delete `IsDirty` tracking and `markDirty` / `markClean` — replace at call sites with direct `DataLocationModel` writes where needed

### 1.2 — Replace `IsUpdating` / `notify` override

- Rename all internal rebuild methods (e.g. `onCurrentDataLocationSet`, row creation loop) to make them clearly distinct from user-triggered callbacks — prefix with `rebuild`
- Remove all callback invocations from within rebuild methods — call the underlying logic directly instead
- Delete the `notify` override once it is no longer needed

### 1.3 — Fix the layout toggle

- Wrap columns 4 and 5 (Exclusion/Inclusion list) in a dedicated `uipanel` container created at construction time
- Replace `setRowDisplayMode` and `setColumnHeaderDisplayMode` with a single toggle on that panel's `Visible` property
- Delete all `xOffset` arithmetic from both methods

---

## Phase 2 — Clean up data ownership

> **Goal:** Single authoritative source for data; no stale local copies.

### 2.1 — Replace `CurrentDataLocation` copy with an index

- Add a private `CurrentDataLocationIndex` property (integer)
- Replace all reads of `CurrentDataLocation.X` with `obj.DataLocationModel.Data(obj.CurrentDataLocationIndex).X`
- Replace the `set.CurrentDataLocation` setter and `onCurrentDataLocationSet` with a `setCurrentDataLocationIndex(idx)` method
- Remove the `CurrentDataLocation` property

### 2.2 — Make callbacks write directly to the model

- In `subFolderTypeChanged`, `ignoreListChanged`, `expressionChanged`, `subfolderChanged`: push the changed value directly to `DataLocationModel` instead of to `obj.Data`
- Remove `updateDataLocationModel` as a public flush method — it should no longer be necessary
- `onDataLocationModified` becomes read-only: it only updates the UI from model events, never the reverse

---

## Phase 3 — Extract the folder preview

> **Goal:** Isolate all preview-window responsibility from the main class.

### 3.1 — Create a `FolderPreviewCoordinator` class

Create a new private/internal class that owns everything related to the preview window:

| Responsibility | Moves from | Moves to |
|---|---|---|
| `FolderListViewer` handle | `FolderOrganizationUI` | `FolderPreviewCoordinator` |
| `FolderOrganizationFilterListener` | `FolderOrganizationUI` | `FolderPreviewCoordinator` |
| `FolderListViewerActive` flag | `FolderOrganizationUI` | `FolderPreviewCoordinator` |
| `createFolderListViewer` | `FolderOrganizationUI` | `FolderPreviewCoordinator` |
| `showFolderListViewer` / `hideFolderListViewer` | `FolderOrganizationUI` | `FolderPreviewCoordinator` |
| `onFolderListViewerDeleted` | `FolderOrganizationUI` | `FolderPreviewCoordinator` |
| `updateFolderList` | `FolderOrganizationUI` | `FolderPreviewCoordinator` |

**Public interface of `FolderPreviewCoordinator`:**

```matlab
show()
hide()
toggle()
update(sessionFolders)   % replaces updateFolderList
delete()
```

`FolderOrganizationUI` retains only:
- A `PreviewCoordinator` property
- `onFolderPreviewButtonClicked` → calls `obj.PreviewCoordinator.toggle()`
- `setActive` / `setInactive` → call `obj.PreviewCoordinator.show()` / `.hide()`

---

## Phase 4 — Extract template management

> **Goal:** Isolate template loading; remove dependency on global project state.

### 4.1 — Inject templates as a dependency

- Add an optional `Templates` argument to the `FolderOrganizationUI` constructor
- If not provided, fall back to `getDataLocationTemplates()` for backward compatibility
- Store templates as a typed property; add a `refreshTemplates()` method for external callers
- Remove the `static` `getDataLocationTemplates` method once all callers inject the templates

### 4.2 — Extract template logic into a `TemplateSelector` component

Move the following out of `FolderOrganizationUI` into a new `TemplateSelector` class:

- `onTemplateSelectionChanged`
- `refreshDataLocationTemplates`
- `DataLocationTemplates` property
- `SelectTemplateLabel`, `SelectTemplateDropdown`, `SelectTemplateHelpIcon` controls

`FolderOrganizationUI` owns a `TemplateSelector` instance, wires up events, but contains no template logic itself.

---

## Phase 5 — Final cleanup

> **Goal:** Shrink the class to its core responsibility (table row UI).

### 5.1 — Restrict access modifiers

| Methods | New access |
|---|---|
| All toolbar callbacks | `private` |
| All row callbacks | `private` |
| `getSubfolderStructure` | `private` |
| `getParentFolderAtLevel` | `private` |

### 5.2 — Remove dead code

- All `% %` commented-out blocks
- Unreachable `if obj.NumRows == 0` check in `createTableRowComponents`
- `FolderHierarchyExampleImage` and `CloseDialogButton` properties
- `onInfoButtonClicked` and `onCloseDialogButtonClicked` (methods with no live caller)
- The `% todo...` property block (`FolderHierarchyExampleImage`, `CloseDialogButton`)
- Residual `% Todo:` comments that describe already-completed work

---

## Issue reference

| Issue | Phase |
|---|---|
| Dual data state (`obj.Data` vs controls) | 1.1 |
| `IsUpdating` / `notify` override workaround | 1.2 |
| Layout via cumulative pixel offsets | 1.3 |
| `CurrentDataLocation` is a stale value copy | 2.1 |
| Callbacks write back to the model | 2.2 |
| Preview window lifecycle entangled in main class | 3.1 |
| Templates injected, not fetched from global state | 4.1 |
| Template logic separated from table UI | 4.2 |
| Access modifiers and dead code | 5.1–5.2 |
