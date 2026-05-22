classdef (Abstract) Registry < handle
%Registry Abstract base class for project-owned plugin registries.
%
%   Stores plugin entries from multiple sources with three precedence tiers:
%     - Top (single pinned slot, highest priority)
%     - Middle (ordered list of sources, appended with addSource)
%     - Bottom (single pinned slot, lowest priority)
%
%   Subclasses implement scanSource (what to parse) and primaryId (which
%   field of the returned entry struct is the unique identifier).
%
%   Usage:
%       reg = MyConcreteRegistry();
%       reg.pinBottom("core", "/path/to/core");
%       reg.addSource("mymod", "/path/to/module");
%       reg.pinTop("project", "/path/to/project");
%       reg.reconcile();
%       entries = reg.list();

    events
        PluginAdded
        PluginRemoved
        PluginChanged
        PluginRegistryReconciled
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
        %   pinTop(id, path) assigns the top slot. If a different source is
        %   already pinned at the top it is silently replaced.
            arguments
                obj
                id   (1,1) string
                path (1,1) string
            end
            obj.TopSource = struct('id', id, 'path', path);
        end

        function pinBottom(obj, id, path)
        %pinBottom Set or replace the bottom-priority source slot.
        %
        %   pinBottom(id, path) assigns the bottom slot. If a different source
        %   is already pinned at the bottom it is silently replaced.
            arguments
                obj
                id   (1,1) string
                path (1,1) string
            end
            obj.BottomSource = struct('id', id, 'path', path);
        end

        function addSource(obj, id, path)
        %addSource Append a source to the middle tier.
        %
        %   Errors if the id is already present in any slot.
            arguments
                obj
                id   (1,1) string
                path (1,1) string
            end
            if obj.hasSourceId(id)
                error('NANSEN:Registry:DuplicateSourceId', ...
                    'A source with id "%s" is already registered.', id)
            end
            obj.MiddleSources(end+1) = struct('id', id, 'path', path);
        end

        function removeSource(obj, id)
        %removeSource Remove a source by id from any slot.
        %
        %   Silently ignores unknown ids.
            arguments
                obj
                id (1,1) string
            end
            if ~isempty(obj.TopSource) && obj.TopSource.id == id
                obj.TopSource = struct('id', {}, 'path', {}); return
            end
            if ~isempty(obj.BottomSource) && obj.BottomSource.id == id
                obj.BottomSource = struct('id', {}, 'path', {}); return
            end
            if ~isempty(obj.MiddleSources)
                keep = [obj.MiddleSources.id] ~= id;
                obj.MiddleSources = obj.MiddleSources(keep);
            end
        end

        function reconcile(obj)
        %reconcile Rescan all sources, diff against current entries, emit events.
        %
        %   Fires PluginAdded, PluginRemoved, or PluginChanged for each
        %   changed entry, then fires PluginRegistryReconciled once at the end.
            sources = obj.orderedSources();
            newEntries = obj.buildEntries(sources);

            oldIds = obj.entryIds(obj.Entries);
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
                oldEntry = obj.findEntry(obj.Entries, sharedIds(i));
                newEntry = obj.findEntry(newEntries, sharedIds(i));
                if ~isequal(oldEntry, newEntry)
                    evtData = nansen.plugin.base.PluginEventData(newEntry, sharedIds(i));
                    notify(obj, 'PluginChanged', evtData);
                end
            end

            obj.Entries = newEntries;
            notify(obj, 'PluginRegistryReconciled');
        end
    end

    methods % Read API
        function entries = list(obj)
        %list Return the resolved entry struct array.
            entries = obj.Entries;
        end

        function entry = get(obj, id)
        %get Return the entry with the given id, or empty struct if not found.
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
