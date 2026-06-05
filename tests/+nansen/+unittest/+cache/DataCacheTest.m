classdef DataCacheTest < matlab.unittest.TestCase
%DataCacheTest Tests for the nansen.cache.DataCache singleton
%
%   Covers the load-through API, LRU eviction, budget enforcement,
%   per-entity invalidation, key construction and singleton lifecycle.
%
%   Most tests use an isolated DataCache constructed with a small explicit
%   budget so behaviour is deterministic and independent of the shared
%   singleton. The few tests that exercise instance() reset the singleton
%   in setup/teardown so global state never leaks between tests.

    properties (Constant, Access = private)
        % A 1 MiB double array: numel * 8 bytes = 1048576 bytes exactly.
        OneMebibyteDouble = zeros(1, 2^17)
    end

    methods (TestMethodSetup)
        function resetSharedSingleton(testCase)
            nansen.cache.DataCache.instance("reset");
            testCase.addTeardown(@() nansen.cache.DataCache.instance("reset"));
        end
    end

    % --- Load-through API ---

    methods (Test)
        function getOrLoadServesStoredValueOnHit(testCase)
        %getOrLoadServesStoredValueOnHit Cached key is served without loading.
            cache = nansen.cache.DataCache(MaxBytes = 1e7);
            expected = magic(10);
            cache.put("session:a:roi", expected);

            actual = cache.getOrLoad("session:a:roi", ...
                @() error("Loader must not run when the key is cached"));
            testCase.verifyEqual(actual, expected, "Value should round-trip")
        end

        function getOrLoadLoadsOnceThenHits(testCase)
        %getOrLoadLoadsOnceThenHits Loader runs on miss only, not on hit.
            cache = nansen.cache.DataCache(MaxBytes = 1e7);
            callCount = 0;

            first = cache.getOrLoad("session:a:dff", @loader);
            second = cache.getOrLoad("session:a:dff", @loader);

            testCase.verifyEqual(callCount, 1, ...
                "Loader should be called exactly once across two reads")
            testCase.verifyEqual(first, second)

            function out = loader()
                callCount = callCount + 1;
                out = magic(4);
            end
        end

        function peekReadsWithoutCountingOrBumping(testCase)
        %peekReadsWithoutCountingOrBumping peek is a silent, side-effect-free read.
            cache = nansen.cache.DataCache(MaxBytes = 1e7);
            cache.put("session:a:x", magic(8));

            [data, hit] = cache.peek("session:a:x");
            testCase.verifyTrue(hit)
            testCase.verifyEqual(data, magic(8))

            stats = cache.summary();
            testCase.verifyEqual(stats.NumHits, 0, "peek must not count as a hit")
            testCase.verifyEqual(stats.NumMisses, 0, "peek must not count as a miss")
        end

        function peekReturnsCallerDefaultOnMiss(testCase)
        %peekReturnsCallerDefaultOnMiss Caller default removes the need for the hit flag.
            cache = nansen.cache.DataCache(MaxBytes = 1e7);

            value = cache.peek("session:a:absent", 'Unassigned');
            testCase.verifyEqual(value, 'Unassigned')

            cache.put("session:a:x", magic(8));
            value = cache.peek("session:a:x", 'Unassigned');
            testCase.verifyEqual(value, magic(8))

            stats = cache.summary();
            testCase.verifyEqual(stats.NumMisses, 0, "peek must not count as a miss")
        end

        function peekDoesNotProtectFromEviction(testCase)
        %peekDoesNotProtectFromEviction peek must not refresh LRU recency.
            cache = nansen.cache.DataCache(MaxBytes = 3 * 2^20);
            cache.put("session:a:A", testCase.OneMebibyteDouble);
            cache.put("session:a:B", testCase.OneMebibyteDouble);
            cache.put("session:a:C", testCase.OneMebibyteDouble);

            cache.peek("session:a:A");   % must NOT save A from being the LRU
            cache.put("session:a:D", testCase.OneMebibyteDouble);

            testCase.verifyFalse(cache.isKey("session:a:A"), ...
                "peek should not refresh recency, so A stays the LRU victim")
        end

        function emptyDataIsNotCached(testCase)
        %emptyDataIsNotCached Empty value means "not loaded" and is skipped.
            cache = nansen.cache.DataCache(MaxBytes = 1e7);
            cache.put("session:a:empty", []);
            testCase.verifyFalse(cache.isKey("session:a:empty"))
            testCase.verifyEqual(cache.Count, 0)
        end
    end

    % --- Budget and eviction ---

    methods (Test)
        function budgetIsNeverExceededForNumericData(testCase)
        %budgetIsNeverExceededForNumericData CurrentBytes stays within MaxBytes.
            cache = nansen.cache.DataCache(MaxBytes = 3 * 2^20);  % 3 MiB
            for i = 1:6
                cache.put("session:a:v" + i, testCase.OneMebibyteDouble);
                testCase.verifyLessThanOrEqual(cache.CurrentBytes, cache.MaxBytes, ...
                    "CurrentBytes must never exceed the budget")
            end
        end

        function evictsLeastRecentlyUsedEntry(testCase)
        %evictsLeastRecentlyUsedEntry LRU (not least-recently-added) is dropped.
            cache = nansen.cache.DataCache(MaxBytes = 3 * 2^20);  % holds 3 entries
            cache.put("session:a:A", testCase.OneMebibyteDouble);
            cache.put("session:a:B", testCase.OneMebibyteDouble);
            cache.put("session:a:C", testCase.OneMebibyteDouble);

            % Touch A (via a hit) so B becomes the least-recently-used entry.
            cache.getOrLoad("session:a:A", @() error("A is already cached"));

            % Inserting D must evict exactly one entry: B.
            cache.put("session:a:D", testCase.OneMebibyteDouble);

            testCase.verifyTrue(cache.isKey("session:a:A"), "A was used recently")
            testCase.verifyFalse(cache.isKey("session:a:B"), "B was the LRU victim")
            testCase.verifyTrue(cache.isKey("session:a:C"))
            testCase.verifyTrue(cache.isKey("session:a:D"))
        end

        function oversizedItemIsNotCached(testCase)
        %oversizedItemIsNotCached Item larger than the budget is passed through.
            cache = nansen.cache.DataCache(MaxBytes = 2^19);  % 0.5 MiB budget
            testCase.verifyWarning( ...
                @() cache.put("session:a:big", testCase.OneMebibyteDouble), ...
                "NANSEN:DataCache:ItemTooLarge")
            testCase.verifyFalse(cache.isKey("session:a:big"))
            testCase.verifyEqual(cache.CurrentBytes, 0)
        end

        function setBudgetEvictsDownToNewLimit(testCase)
        %setBudgetEvictsDownToNewLimit Shrinking the budget evicts immediately.
            cache = nansen.cache.DataCache(MaxBytes = 4 * 2^20);
            for i = 1:4
                cache.put("session:a:v" + i, testCase.OneMebibyteDouble);
            end
            testCase.assertEqual(cache.Count, 4)

            cache.setBudget(2 * 2^20);
            testCase.verifyLessThanOrEqual(cache.CurrentBytes, cache.MaxBytes)
            testCase.verifyEqual(cache.Count, 2)
        end
    end

    % --- Object byte-sizing ---

    methods (Test)
        function getCacheSizeHookIsUsedForObjects(testCase)
        %getCacheSizeHookIsUsedForObjects A heavy class can report its own footprint.
            cache = nansen.cache.DataCache(MaxBytes = 1e7);
            stub = nansen.unittest.cache.CacheSizeStub(4096);

            cache.put("session:a:obj", stub);

            testCase.verifyEqual(cache.CurrentBytes, 4096, ...
                "measureBytes must trust the object's getCacheSize method")
        end
    end

    % --- Invalidation ---

    methods (Test)
        function removeDropsSingleEntry(testCase)
        %removeDropsSingleEntry remove clears one key and its byte count.
            cache = nansen.cache.DataCache(MaxBytes = 1e7);
            cache.put("session:a:x", magic(20));
            cache.remove("session:a:x");
            testCase.verifyFalse(cache.isKey("session:a:x"))
            testCase.verifyEqual(cache.CurrentBytes, 0)
        end

        function removeByPrefixDropsOneEntityOnly(testCase)
        %removeByPrefixDropsOneEntityOnly Only the matching entity is cleared.
            cache = nansen.cache.DataCache(MaxBytes = 1e7);
            cache.put("session:a:x", magic(8));
            cache.put("session:a:y", magic(8));
            cache.put("session:b:x", magic(8));

            numRemoved = cache.removeByPrefix("session:a:");
            testCase.verifyEqual(numRemoved, 2)
            testCase.verifyFalse(cache.isKey("session:a:x"))
            testCase.verifyFalse(cache.isKey("session:a:y"))
            testCase.verifyTrue(cache.isKey("session:b:x"), ...
                "Other entities must be untouched")
        end

        function clearEmptiesEverything(testCase)
        %clearEmptiesEverything clear removes all entries and zeroes usage.
            cache = nansen.cache.DataCache(MaxBytes = 1e7);
            cache.put("session:a:x", magic(8));
            cache.put("session:b:y", magic(8));
            cache.clear();
            testCase.verifyEqual(cache.Count, 0)
            testCase.verifyEqual(cache.CurrentBytes, 0)
        end
    end

    % --- Key construction ---

    methods (Test)
        function buildKeyUsesEntityTypeIdVariable(testCase)
        %buildKeyUsesEntityTypeIdVariable Key format is type:id:variable.
            key = nansen.cache.DataCache.buildKey("session", "abc123", "dff");
            testCase.verifyEqual(key, "session:abc123:dff")
        end
    end

    % --- Singleton lifecycle ---

    methods (Test)
        function instanceReturnsSameHandle(testCase)
        %instanceReturnsSameHandle Repeated instance() calls share one object.
            first = nansen.cache.DataCache.instance();
            second = nansen.cache.DataCache.instance();
            testCase.verifySameHandle(second, first)
        end

        function instanceResetGivesFreshCache(testCase)
        %instanceResetGivesFreshCache reset drops previously cached data.
            cache = nansen.cache.DataCache.instance();
            cache.put("session:a:x", magic(8));
            testCase.assertTrue(cache.isKey("session:a:x"))

            nansen.cache.DataCache.instance("reset");
            fresh = nansen.cache.DataCache.instance();
            testCase.verifyFalse(fresh.isKey("session:a:x"))
            testCase.verifyEqual(fresh.CurrentBytes, 0)
        end

        function instanceNocreateReturnsEmptyWhenAbsent(testCase)
        %instanceNocreateReturnsEmptyWhenAbsent nocreate never constructs.
            nansen.cache.DataCache.instance("reset");
            existing = nansen.cache.DataCache.instance("nocreate");
            testCase.verifyEmpty(existing)
        end
    end

    % --- Statistics ---

    methods (Test)
        function summaryTracksHitsAndMisses(testCase)
        %summaryTracksHitsAndMisses Hit/miss counters reflect access pattern.
            cache = nansen.cache.DataCache(MaxBytes = 1e7);
            cache.put("session:a:x", magic(8));
            cache.getOrLoad("session:a:x", @() error("hit must not load"));  % hit
            cache.getOrLoad("session:a:y", @() magic(4));                    % miss

            stats = cache.summary();
            testCase.verifyEqual(stats.NumHits, 1)
            testCase.verifyEqual(stats.NumMisses, 1)
            testCase.verifyEqual(stats.HitRate, 0.5, "AbsTol", eps)
        end
    end
end
