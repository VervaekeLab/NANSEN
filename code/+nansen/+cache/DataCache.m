classdef DataCache < handle & matlab.mixin.CustomDisplay
%DataCache Process-wide, memory-bounded LRU cache for entity data variables
%
%   nansen.cache.DataCache is a singleton that keeps loaded data variables
%   in memory so they are not re-read from disk on repeated access. It
%   enforces a configurable memory budget by evicting the least-recently-
%   used (LRU) entries whenever a new entry would exceed the budget.
%
%   The cache is entity-agnostic: it stores values under opaque string
%   keys and never needs to know what a "session" or "subject" is. Use the
%   static buildKey method to construct keys with the convention
%   "entityType:entityId:variableName".
%
%   USAGE:
%
%       Get the shared cache:
%           cache = nansen.cache.DataCache.instance();
%
%       Load-through cache (load on miss, serve from memory on hit):
%           key  = nansen.cache.DataCache.buildKey("session", id, varName);
%           data = cache.getOrLoad(key, @() sessionObj.loadData(varName));
%
%       Drop every entry belonging to one entity (e.g. on save/delete):
%           cache.removeByPrefix("session:" + id + ":");
%
%   Note on budgeting accuracy: entry size is measured exactly for numeric,
%   logical, char, struct and cell data. Handle objects are measured either
%   via an optional getCacheSize method (preferred) or by serialization,
%   which is approximate and relatively costly. Budget enforcement is
%   therefore best-effort, not a hard guarantee, for object payloads.
%
%   See also nansen.cache.CacheEntry, nansen.session.SessionData

    properties (Constant, Hidden)
        DEFAULT_MAX_BYTES = 2 * 2^30    % 2 GiB default budget
    end

    properties (SetAccess = private)
        MaxBytes (1,1) double           % Memory budget in bytes
        CurrentBytes (1,1) double = 0   % Bytes currently held
        PeakBytes (1,1) double = 0      % High-water mark of CurrentBytes
    end

    properties (Dependent, SetAccess = private)
        Count   % Number of entries currently cached
    end

    properties (Access = private)
        Entries                    % containers.Map: char key -> CacheEntry
        AccessCounter (1,1) double = 0  % Monotonic source of access stamps
        Stats struct               % Cumulative hit/miss/eviction counters
    end

    methods % Constructor
        function obj = DataCache(options)
        %DataCache Construct a cache instance
        %
        %   Use nansen.cache.DataCache.instance() for the shared singleton.
        %   Construct directly only for an isolated/scoped cache (e.g. tests).

            arguments
                options.MaxBytes (1,1) double {mustBeNonnegative} = ...
                    nansen.cache.DataCache.DEFAULT_MAX_BYTES
            end

            obj.MaxBytes = options.MaxBytes;
            obj.Entries = containers.Map("KeyType", "char", "ValueType", "any");
            obj.Stats = struct("NumHits", 0, "NumMisses", 0, "NumEvictions", 0);
        end
    end

    methods % Get/set
        function n = get.Count(obj)
            % containers.Map.Count is uint64; expose a plain double so the
            % count does not silently turn arithmetic unsigned downstream.
            n = double(obj.Entries.Count);
        end
    end

    methods % Public cache API

        function tf = isKey(obj, key)
        %isKey Return true if a value is cached under key (no LRU bump)
            arguments
                obj
                key (1,1) string
            end
            tf = obj.Entries.isKey(char(key));
        end

        function [data, hit] = peek(obj, key, default)
        %peek Return cached value (or a caller default) without side effects
        %
        %   data = peek(obj, key) returns the cached value, or [] on a miss.
        %
        %   data = peek(obj, key, default) returns default on a miss. This is
        %   the clean way to get "value or fallback": the caller chooses the
        %   sentinel, so it can never collide with a legitimately cached
        %   value the way a fixed missing/[]/NaN sentinel would.
        %
        %   [data, hit] = peek(...) also returns whether it was a hit, for
        %   the rare caller that must distinguish presence from value.
        %
        %   Unlike tryGet, peek does not bump the entry's LRU recency and is
        %   not counted as a hit or miss, so it is safe for display paths.

            arguments
                obj
                key (1,1) string
                default = []
            end

            charKey = char(key);
            hit = obj.Entries.isKey(charKey);
            if hit
                data = obj.Entries(charKey).Data;
            else
                data = default;
            end
        end

        function data = getOrLoad(obj, key, loadFcn)
        %getOrLoad Return cached value, loading and caching it on a miss
        %
        %   data = getOrLoad(obj, key, loadFcn) returns the cached value for
        %   key if present. Otherwise it calls loadFcn (a zero-argument
        %   function handle), caches the result, and returns it.

            arguments
                obj
                key (1,1) string
                loadFcn (1,1) function_handle
            end

            [data, hit] = obj.tryGet(key);
            if ~hit
                data = loadFcn();
                obj.put(key, data);
            end
        end

        function put(obj, key, data)
        %put Insert or replace a cached value, evicting LRU entries if needed
        %
        %   Empty data is not cached (it represents "not loaded"). Data
        %   larger than the whole budget is not cached and a warning is
        %   issued.

            arguments
                obj
                key (1,1) string
                data
            end

            if isempty(data)
                return
            end

            numBytes = obj.measureBytes(data);

            if numBytes > obj.MaxBytes
                warning("NANSEN:DataCache:ItemTooLarge", ...
                    ['Data for key ''%s'' (%s) exceeds the cache budget ', ...
                    '(%s) and was not cached. Increase the budget with ', ...
                    'setBudget or cache a smaller representation.'], ...
                    key, obj.bytes2str(numBytes), obj.bytes2str(obj.MaxBytes))
                return
            end

            obj.remove(key);              % replace any existing entry
            obj.evictToFit(numBytes);

            obj.AccessCounter = obj.AccessCounter + 1;
            entry = nansen.cache.CacheEntry(key, data, numBytes, obj.AccessCounter);
            obj.Entries(char(key)) = entry;

            obj.CurrentBytes = obj.CurrentBytes + numBytes;
            obj.PeakBytes = max(obj.PeakBytes, obj.CurrentBytes);
        end

        function remove(obj, key)
        %remove Remove the entry for key if present (no-op otherwise)
            arguments
                obj
                key (1,1) string
            end

            charKey = char(key);
            if obj.Entries.isKey(charKey)
                entry = obj.Entries(charKey);
                obj.CurrentBytes = obj.CurrentBytes - entry.Bytes;
                obj.Entries.remove(charKey);
            end
        end

        function numRemoved = removeByPrefix(obj, prefix)
        %removeByPrefix Remove every entry whose key starts with prefix
        %
        %   Use this to drop all variables for one entity, e.g.
        %   removeByPrefix("session:" + sessionId + ":").

            arguments
                obj
                prefix (1,1) string
            end

            allKeys = string(obj.Entries.keys);
            victims = allKeys(startsWith(allKeys, prefix));
            for i = 1:numel(victims)
                obj.remove(victims(i));
            end
            numRemoved = numel(victims);

            if ~nargout
                clear numRemoved
            end
        end

        function clear(obj)
        %clear Remove all entries and free their memory
            obj.Entries = containers.Map("KeyType", "char", "ValueType", "any");
            obj.CurrentBytes = 0;
        end

        function setBudget(obj, numBytes)
        %setBudget Set the memory budget, evicting down to it if necessary
            arguments
                obj
                numBytes (1,1) double {mustBeNonnegative}
            end
            obj.MaxBytes = numBytes;
            obj.evictToFit(0);
        end

        function s = summary(obj)
        %summary Return a struct describing cache usage and hit statistics
            s = struct();
            s.MaxBytes = obj.MaxBytes;
            s.CurrentBytes = obj.CurrentBytes;
            s.PeakBytes = obj.PeakBytes;
            s.NumEntries = obj.Count;
            s.NumHits = obj.Stats.NumHits;
            s.NumMisses = obj.Stats.NumMisses;
            s.NumEvictions = obj.Stats.NumEvictions;

            numRequests = s.NumHits + s.NumMisses;
            if numRequests > 0
                s.HitRate = s.NumHits / numRequests;
            else
                s.HitRate = NaN;
            end
        end
    end

    methods (Access = private)

        function [data, hit] = tryGet(obj, key)
        %tryGet Internal read primitive: count the access and bump recency
        %
        %   [data, hit] = tryGet(obj, key) returns the cached value (hit =
        %   true) on a hit, bumping the entry's LRU recency and counting a
        %   hit; on a miss it returns data = [], hit = false and counts a
        %   miss. Used by getOrLoad. External callers use getOrLoad, peek or
        %   isKey, which keep presence and value cleanly separated.

            arguments
                obj
                key (1,1) string
            end

            charKey = char(key);
            if obj.Entries.isKey(charKey)
                entry = obj.Entries(charKey);
                obj.AccessCounter = obj.AccessCounter + 1;
                entry.LastAccess = obj.AccessCounter;   % LRU bump (in place)
                data = entry.Data;
                hit = true;
                obj.Stats.NumHits = obj.Stats.NumHits + 1;
            else
                data = [];
                hit = false;
                obj.Stats.NumMisses = obj.Stats.NumMisses + 1;
            end
        end

        function evictToFit(obj, requiredBytes)
        %evictToFit Evict least-recently-used entries until requiredBytes fit
        %
        %   Eviction order is computed once per call (O(n log n) in the
        %   number of entries), which is acceptable for the expected scale
        %   of tens to low hundreds of entries.

            if (obj.CurrentBytes + requiredBytes) <= obj.MaxBytes
                return
            end

            allKeys = string(obj.Entries.keys);
            entries = obj.Entries.values;
            accessStamps = cellfun(@(e) e.LastAccess, entries);
            [~, evictionOrder] = sort(accessStamps, "ascend");  % LRU first

            i = 1;
            while (obj.CurrentBytes + requiredBytes) > obj.MaxBytes ...
                    && i <= numel(evictionOrder)
                obj.remove(allKeys(evictionOrder(i)));
                obj.Stats.NumEvictions = obj.Stats.NumEvictions + 1;
                i = i + 1;
            end
        end

        function numBytes = measureBytes(~, data)
        %measureBytes Estimate the in-memory size of data in bytes
        %
        %   Exact for fundamental types (numeric/logical/char/struct/cell)
        %   via whos. For objects, prefer a getCacheSize method if the class
        %   provides one; otherwise fall back to serialization, which is
        %   approximate and costly. whos under-reports handle objects (it
        %   only counts the handle), so it is not used for them.

            if isobject(data) && ismethod(data, 'getCacheSize')
                numBytes = data.getCacheSize();
            elseif isobject(data)
                try
                    numBytes = numel(getByteStreamFromArray(data));
                catch
                    info = whos("data");
                    numBytes = info.bytes;
                end
            else
                info = whos("data");
                numBytes = info.bytes;
            end
        end

        function str = bytes2str(~, numBytes)
        %bytes2str Format a byte count as a human-readable string
            units = ["B", "KB", "MB", "GB", "TB"];
            idx = 1;
            value = double(numBytes);
            while value >= 1024 && idx < numel(units)
                value = value / 1024;
                idx = idx + 1;
            end
            str = sprintf("%.1f %s", value, units(idx));
        end
    end

    methods (Access = protected) % Custom display

        function propgrp = getPropertyGroups(obj)
            if ~isscalar(obj)
                propgrp = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
                return
            end

            stats = obj.summary();
            s = struct();
            s.Usage = sprintf("%s / %s", ...
                obj.bytes2str(obj.CurrentBytes), obj.bytes2str(obj.MaxBytes));
            s.Entries = stats.NumEntries;
            if isnan(stats.HitRate)
                s.HitRate = "n/a";
            else
                s.HitRate = sprintf("%.0f%% (%d hit / %d miss)", ...
                    100 * stats.HitRate, stats.NumHits, stats.NumMisses);
            end
            s.Evictions = stats.NumEvictions;

            propgrp = matlab.mixin.util.PropertyGroup(s);
        end
    end

    methods (Static)

        function obj = instance(mode)
        %instance Return the shared singleton DataCache
        %
        %   cache = nansen.cache.DataCache.instance() returns the shared
        %   cache, creating it on first use.
        %
        %   instance(mode) controls lifecycle:
        %       "get"      - (default) return existing, create if needed
        %       "reset"    - delete the shared cache and return []
        %       "nocreate" - return existing or [] without creating
        %
        %   "reset" deletes the existing instance, so any handle held across
        %   a reset becomes invalid: always obtain the cache via instance(),
        %   never store the handle. After "reset" the next "get" creates a
        %   fresh cache. The instance is held in a persistent variable, so a
        %   "clear all" frees the cached memory too. This is intentional for
        %   a cache, and differs from singletons that must survive "clear all".

            arguments
                mode (1,1) string ...
                    {mustBeMember(mode, ["get", "reset", "nocreate"])} = "get"
            end

            persistent singleton

            if mode == "reset"
                % Delete (not just detach) so a lingering reference to the old
                % cache fails fast instead of silently diverging from the
                % shared instance.
                if ~isempty(singleton) && isvalid(singleton)
                    delete(singleton);
                end
                singleton = [];
            end

            if isempty(singleton) && mode == "get"
                singleton = nansen.cache.DataCache();
            end

            obj = singleton;
        end
        
        function reset()
            %reset Reset the DataCache
            nansen.cache.DataCache.instance("reset")
        end

        function key = buildKey(entityType, entityId, variableName)
        %buildKey Build a cache key "entityType:entityId:variableName"
        %
        %   Components should not themselves contain the ":" separator, so
        %   that removeByPrefix can target a single entity unambiguously.

            arguments
                entityType (1,1) string {mustNotContainColon}
                entityId (1,1) string {mustNotContainColon}
                variableName (1,1) string {mustNotContainColon}
            end
            key = entityType + ":" + entityId + ":" + variableName;
        end
    end
end

function mustNotContainColon(value)
    if contains(value, ":")
        throwAsCaller(...
            MException("NANSEN:validator:mustNotContainColon", ...
                'Cache key componentn must not contain colon.'));
    end
end
