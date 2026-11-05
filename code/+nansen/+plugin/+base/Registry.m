classdef (Abstract) Registry < handle
%Registry Abstract base class for project-owned plugin registries.
%
%   Stores plugin entries from multiple sources with three precedence tiers:
%     - Top (single pinned slot, highest priority)
%     - Middle (ordered list of sources, added with addSource)
%     - Bottom (single pinned slot, lowest priority)
%
%   A source id names one source only. pinTop, pinBottom and addSource
%   error with NANSEN:Registry:DuplicateSourceId when the id already names
%   a source in another slot.
%
%   The registry scans its sources on the first list, get or resolve after
%   a change: pinning, adding or removing a source, or calling markStale.
%   Until the next change, these methods return the entries of the last
%   scan. reconcile scans the sources immediately.
%
%   Subclasses implement scanSource (what to parse) and primaryId (which
%   field of the returned entry struct is the unique identifier).
%
%   Usage:
%       reg = MyConcreteRegistry();
%       reg.pinBottom("core", "/path/to/core");
%       reg.addSource("mymod", "/path/to/module");
%       reg.pinTop("project", "/path/to/project");
%       entries = reg.list();   % Scans the three sources

    events
        PluginAdded
        PluginRemoved
        PluginChanged
        PluginRegistryReconciled
    end

    properties (SetAccess = private)
        % IsStale - True when the sources changed since the last scan. The
        % next list, get or resolve scans the sources when it is true.
        IsStale (1,1) logical = true
    end

    properties (Access = private)
        % Three-tier source storage
        TopSource       struct  % scalar or empty struct with fields: id, path
        MiddleSources   struct  % struct array with fields: id, path
        BottomSource    struct  % scalar or empty struct with fields: id, path

        % Resolved entry list after last reconcile (struct array, subclass-defined fields)
        Entries         struct
    end

    methods % Constructor
        function obj = Registry()
            obj.TopSource    = struct('id', {}, 'path', {});
            obj.MiddleSources = struct('id', {}, 'path', {});
            obj.BottomSource = struct('id', {}, 'path', {});
            obj.Entries      = struct.empty;
        end
    end

    methods % Source management API
        function pinTop(obj, id, path)
        %pinTop Set or replace the top-priority source slot.
        %
        %   pinTop(id, path) assigns the top slot. A source already pinned
        %   at the top is replaced. Errors if id names a source in the
        %   middle tier or the bottom slot.
            arguments
                obj
                id   (1,1) string
                path (1,1) string
            end
            obj.assertSourceIdIsFree(id, obj.TopSource)
            obj.TopSource = struct('id', id, 'path', path);
            obj.IsStale = true;
        end

        function pinBottom(obj, id, path)
        %pinBottom Set or replace the bottom-priority source slot.
        %
        %   pinBottom(id, path) assigns the bottom slot. A source already
        %   pinned at the bottom is replaced. Errors if id names a source
        %   in the top slot or the middle tier.
            arguments
                obj
                id   (1,1) string
                path (1,1) string
            end
            obj.assertSourceIdIsFree(id, obj.BottomSource)
            obj.BottomSource = struct('id', id, 'path', path);
            obj.IsStale = true;
        end

        function addSource(obj, id, path, options)
        %addSource Add a source to the middle tier.
        %
        %   addSource(id, path) appends the source to the middle tier,
        %   after the sources that are already there.
        %
        %   addSource(id, path, Position="first") inserts the source before
        %   the other middle-tier sources, so that it has the highest
        %   priority of the middle tier.
        %
        %   Errors if the id is already present in any slot.
            arguments
                obj
                id   (1,1) string
                path (1,1) string
                options.Position (1,1) string ...
                    {mustBeMember(options.Position, ["first", "last"])} = "last"
            end
            obj.assertSourceIdIsFree(id)

            newSource = struct('id', id, 'path', path);
            if options.Position == "first"
                obj.MiddleSources = [newSource, obj.MiddleSources];
            else
                obj.MiddleSources(end+1) = newSource;
            end
            obj.IsStale = true;
        end

        function removeSource(obj, id)
        %removeSource Remove a source by id from any slot.
        %
        %   Silently ignores unknown ids.
            arguments
                obj
                id (1,1) string
            end
            if ~obj.hasSourceId(id)
                return
            end

            if ~isempty(obj.TopSource) && obj.TopSource.id == id
                obj.TopSource = struct('id', {}, 'path', {});
            elseif ~isempty(obj.BottomSource) && obj.BottomSource.id == id
                obj.BottomSource = struct('id', {}, 'path', {});
            else
                isRemoved = [obj.MiddleSources.id] == id;
                obj.MiddleSources(isRemoved) = [];
            end
            obj.IsStale = true;
        end

        function markStale(obj)
        %markStale Make the next list, get or resolve scan the sources.
        %
        %   Call markStale after plugin files are added, changed or removed
        %   in a source folder, so that the next lookup finds the change.
            obj.IsStale = true;
        end

        function reconcile(obj)
        %reconcile Rescan all sources, diff against current entries, emit events.
        %
        %   Fires PluginAdded, PluginRemoved, or PluginChanged for each
        %   changed entry, then fires PluginRegistryReconciled once at the
        %   end. The new entries are stored before the events fire, so a
        %   listener that calls list gets them without starting another scan.
            oldEntries = obj.Entries;
            newEntries = obj.buildEntries(obj.orderedSources());

            obj.Entries = newEntries;
            obj.IsStale = false;

            oldIds = obj.entryIds(oldEntries);
            newIds = obj.entryIds(newEntries);

            removedIds = setdiff(oldIds, newIds);
            for i = 1:numel(removedIds)
                evtData = nansen.plugin.base.PluginEventData( ...
                    struct.empty, removedIds(i));
                notify(obj, 'PluginRemoved', evtData);
            end

            addedIds = setdiff(newIds, oldIds);
            for i = 1:numel(addedIds)
                entry = obj.findEntry(newEntries, addedIds(i));
                evtData = nansen.plugin.base.PluginEventData(entry, addedIds(i));
                notify(obj, 'PluginAdded', evtData);
            end

            sharedIds = intersect(oldIds, newIds);
            for i = 1:numel(sharedIds)
                oldEntry = obj.findEntry(oldEntries, sharedIds(i));
                newEntry = obj.findEntry(newEntries, sharedIds(i));
                if ~isequal(oldEntry, newEntry)
                    evtData = nansen.plugin.base.PluginEventData(newEntry, sharedIds(i));
                    notify(obj, 'PluginChanged', evtData);
                end
            end

            notify(obj, 'PluginRegistryReconciled');
        end
    end

    methods % Read API
        function entries = list(obj)
        %list Return the resolved entry struct array.
        %
        %   Scans the sources first if they changed since the last scan.
            obj.reconcileIfStale()
            entries = obj.Entries;
        end

        function entry = get(obj, id)
        %get Return the entry with the given id, or empty struct if not found.
        %
        %   Scans the sources first if they changed since the last scan.
            obj.reconcileIfStale()
            entry = obj.findEntry(obj.Entries, id);
        end

        function entry = resolve(obj, id)
        %resolve Return the highest-priority entry with the given id.
        %
        %   Equivalent to get() for registries that already deduplicate by id
        %   during reconcile.
            entry = obj.get(id);
        end
    end

    methods (Abstract, Access = protected)
        entries = scanSource(obj, sourceId, sourcePath)
        %scanSource Scan one source directory and return its entries.
        %
        %   Subclass defines the entry struct fields and parsing logic.

        id = primaryId(obj, entry)
        %primaryId Return the unique id string for an entry.
        %
        %   Subclass returns the field of the entry struct that uniquely
        %   identifies the plugin (e.g. string(entry.FileAdapterName)).
    end

    methods (Access = private)
        function reconcileIfStale(obj)
        %reconcileIfStale Rescan the sources if they changed since the last scan.
            if obj.IsStale
                obj.reconcile()
            end
        end

        function sources = orderedSources(obj)
        %orderedSources Return all sources in precedence order (top > middle > bottom).
            sources = [obj.TopSource, obj.MiddleSources, obj.BottomSource];
        end

        function allEntries = buildEntries(obj, sources)
        %buildEntries Scan all sources and merge with precedence dedup.
            allEntries = [];   % Becomes a struct array on first assignment
            seenIds = string.empty;

            for i = 1:numel(sources)
                raw = obj.scanSource(sources(i).id, sources(i).path);
                if isempty(raw); continue; end

                for j = 1:numel(raw)
                    entryId = obj.primaryId(raw(j));
                    if ~ismember(entryId, seenIds)
                        seenIds(end+1) = entryId; %#ok<AGROW>
                        if isempty(allEntries)
                            allEntries = raw(j);
                        else
                            allEntries(end+1) = raw(j); %#ok<AGROW>
                        end
                    end
                    % Higher-priority (earlier) source wins; lower-priority entries
                    % are silently dropped.
                end
            end

            if isempty(allEntries)
                allEntries = struct.empty;
            end
        end

        function tf = hasSourceId(obj, id)
        %hasSourceId Return true if id is already registered in any slot.
            tf = false;
            if ~isempty(obj.TopSource) && obj.TopSource.id == id
                tf = true; return
            end
            if ~isempty(obj.BottomSource) && obj.BottomSource.id == id
                tf = true; return
            end
            if ~isempty(obj.MiddleSources) && any([obj.MiddleSources.id] == id)
                tf = true;
            end
        end

        function assertSourceIdIsFree(obj, id, replacedSource)
        %assertSourceIdIsFree Error if id names a source other than replacedSource.
        %
        %   replacedSource is the source in the slot that is being assigned.
        %   Reusing its id replaces it, which is allowed.
            arguments
                obj
                id (1,1) string
                replacedSource struct = struct('id', {}, 'path', {})
            end
            isReplacedId = ~isempty(replacedSource) && replacedSource.id == id;
            if obj.hasSourceId(id) && ~isReplacedId
                error('NANSEN:Registry:DuplicateSourceId', ...
                    ['A source with id "%s" is already registered. ', ...
                    'Remove it with removeSource before registering it again.'], id)
            end
        end

        function ids = entryIds(obj, entries)
        %entryIds Return a string array of all entry ids.
            if isempty(entries)
                ids = string.empty;
            else
                ids = arrayfun(@(e) obj.primaryId(e), entries);
            end
        end

        function entry = findEntry(obj, entries, id)
        %findEntry Find an entry by id; returns empty struct if not found.
            entry = struct.empty;
            if isempty(entries); return; end
            ids = obj.entryIds(entries);
            idx = find(ids == id, 1);
            if ~isempty(idx)
                entry = entries(idx);
            end
        end
    end
end
