classdef CacheEntry < handle
%CacheEntry Single entry held by a nansen.cache.DataCache
%
%   A CacheEntry is a lightweight handle that bundles a cached value with
%   the bookkeeping the cache needs: its key, its measured size in bytes,
%   and a monotonic access stamp used for least-recently-used eviction.
%
%   It is a handle (rather than a struct) so the cache can bump LastAccess
%   in place on every read without copying the cached Data.
%
%   See also nansen.cache.DataCache

    properties
        Key (1,1) string        % Key the entry is stored under
        Data                    % Cached value (any class)
        Bytes (1,1) double = 0  % Measured size of Data in bytes
        LastAccess (1,1) double = 0  % Monotonic access stamp (for LRU)
    end

    methods
        function obj = CacheEntry(key, data, bytes, lastAccess)
            if nargin == 0
                return
            end
            obj.Key = key;
            obj.Data = data;
            obj.Bytes = bytes;
            obj.LastAccess = lastAccess;
        end
    end
end
