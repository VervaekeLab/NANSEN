classdef MetaTableCacheInvalidationTest < matlab.unittest.TestCase
    % MetaTableCacheInvalidationTest - Cache invalidation on entry edits
    %
    %   Regression coverage for issue #101: editEntries must keep the
    %   metaObject cache consistent with the entries table, while the
    %   reverse-sync path (a live metaObject updating its own backing row)
    %   must not delete the object the caller is holding.
    %
    %   Regression coverage for issue #104: cached meta objects mirror the
    %   table's column set (struct objects from the @table2struct fallback),
    %   so adding or removing a table variable must invalidate the cache.
    %
    %   These tests are intentionally self-contained: they build a MetaTable
    %   backed by a lightweight MetaObjectStub metaObject and do not
    %   require a configured project.
    %
    %   Run tests:
    %       runtests('nansen.unittest.metadata.MetaTableCacheInvalidationTest')

    methods (Test)
        function testEditEntriesInvalidatesMetaObjectCache(testCase)
            % editEntries must invalidate the cached metaObject so the next
            % getMetaObjects call reflects the edit.
            mt = testCase.createObservableItemMetaTable();

            cachedItem = mt.getMetaObjects(1); % Prime the cache
            testCase.assertClass(cachedItem, ...
                'nansen.unittest.metadata.helper.MetaObjectStub');

            mt.editEntries(1, 'Value', 9999);

            rebuiltItem = mt.getMetaObjects(1);
            testCase.verifyEqual(rebuiltItem.Value, 9999, ...
                'getMetaObjects returned a stale cached object after editEntries');

            % The stale handle should have been invalidated, not silently
            % kept alive with pre-edit data.
            testCase.verifyFalse(isvalid(cachedItem));
        end

        function testEditEntriesWithInvalidateCacheFalseKeepsCache(testCase)
            % Opting out of invalidation leaves the cached object in place
            % (used by the reverse-sync path to avoid deleting a live object).
            mt = testCase.createObservableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            mt.editEntries(1, 'Value', 9999, 'InvalidateCache', false);

            testCase.verifyTrue(isvalid(cachedItem), ...
                'Cached object was deleted despite InvalidateCache=false');
            sameItem = mt.getMetaObjects(1);
            testCase.verifyTrue(sameItem == cachedItem, ...
                'A new object was built despite InvalidateCache=false');
        end

        function testObservablePropertySyncKeepsMetaObjectAlive(testCase)
            % Editing a live cached metaObject's property syncs into the
            % entries table without deleting the object the caller holds.
            mt = testCase.createObservableItemMetaTable();

            item = mt.getMetaObjects(1);
            item.Value = 4242;

            testCase.verifyTrue(isvalid(item), ...
                'Live metaObject was deleted by its own property-set sync');
            testCase.verifyEqual(mt.entries.Value(1), 4242, ...
                'Property change did not sync back into the entries table');
        end

        function testAddTableVariableRebuildsCachedObjects(testCase)
            % Adding a column must invalidate the cache so the next
            % getMetaObjects call reflects the new column set (issue #104).
            mt = testCase.createStructBackedMetaTable();

            cached = mt.getMetaObjects(1:3); % Prime cache with old column set
            testCase.assertTrue(isstruct(cached));
            testCase.assertFalse(isfield(cached, 'NewVar'));

            mt.addTableVariable('NewVar', 0);

            rebuilt = mt.getMetaObjects(1:3);
            testCase.verifyTrue(isfield(rebuilt, 'NewVar'), ...
                'getMetaObjects served stale cached structs after a column was added');
        end

        function testRemoveTableVariableRebuildsCachedObjects(testCase)
            % Removing a column must invalidate the cache so the next
            % getMetaObjects call reflects the new column set (issue #104).
            mt = testCase.createStructBackedMetaTable();
            mt.addTableVariable('NewVar', 0);

            cached = mt.getMetaObjects(1:3); % Prime cache including NewVar
            testCase.assertTrue(isfield(cached, 'NewVar'));

            mt.removeTableVariable('NewVar');

            rebuilt = mt.getMetaObjects(1:3);
            testCase.verifyFalse(isfield(rebuilt, 'NewVar'), ...
                'getMetaObjects served stale cached structs after a column was removed');
        end

        function testAddTableVariableAfterPartialCacheDoesNotError(testCase)
            % Regression for issue #104: when only some rows are cached,
            % getMetaObjects merges cached structs with freshly built ones.
            % If a column is added between the two builds, the field sets
            % must still align (no struct-field mismatch in
            % utility.insertIntoArray).
            mt = testCase.createStructBackedMetaTable();
            mt.getMetaObjects(1:2); % Cache a subset against the old column set

            mt.addTableVariable('NewVar', 0);

            rebuilt = mt.getMetaObjects(1:3); % Previously threw in insertIntoArray
            testCase.verifyEqual(numel(rebuilt), 3);
            testCase.verifyTrue(isfield(rebuilt, 'NewVar'));
        end

        function testDestroyingCachedObjectEvictsItFromCache(testCase)
            % A cached object carries a cache-eviction listener, so
            % destroying it removes it from the cache and the next
            % getMetaObjects rebuilds a valid object rather than returning a
            % deleted handle.
            mt = testCase.createObservableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            delete(cachedItem);

            rebuilt = mt.getMetaObjects(1);
            testCase.verifyTrue(isvalid(rebuilt), ...
                'Cache returned a stale invalid handle after the cached object was destroyed');
        end

        function testDestroyingUncachedObjectDoesNotEvictCachedObject(testCase)
            % An object fetched with UseCache=false shares its ID with the
            % cached object for the same row but is not itself cached, so it
            % carries no cache-eviction listener. Destroying it must not
            % disturb the live cached object with the same ID.
            mt = testCase.createObservableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);                    % cached
            duplicate  = mt.getMetaObjects(1, 'UseCache', false); % same ID, uncached
            testCase.assertFalse(cachedItem == duplicate, ...
                'Expected UseCache=false to build a distinct object');

            delete(duplicate);

            rebuilt = mt.getMetaObjects(1);
            testCase.verifyTrue(rebuilt == cachedItem, ...
                'Destroying an uncached duplicate evicted the cached object');
        end

        function testRoutineCacheFlowsAreWarningFree(testCase)
            % The cache-member-missing warning must fire only on a genuine
            % cache/members desync, never during routine invalidation, reset,
            % column changes, or direct destruction of a cached object.
            mt = testCase.createObservableItemMetaTable();

            % editEntries invalidates (deletes) the cached object.
            mt.getMetaObjects(1);
            testCase.verifyWarningFree(@() mt.editEntries(1, 'Value', 111));

            % resetMetaObjectCache deletes every cached object.
            mt.getMetaObjects(1:3);
            testCase.verifyWarningFree(@() mt.resetMetaObjectCache());

            % addTableVariable resets the cache as part of a column change.
            mt.getMetaObjects(1:3);
            testCase.verifyWarningFree(@() mt.addTableVariable('Extra', 0));

            % Directly destroying a cached object evicts it via its listener.
            item = mt.getMetaObjects(1);
            testCase.verifyWarningFree(@() delete(item));
        end
    end

    methods (Access = private)
        function mt = createObservableItemMetaTable(~)
            % Build a MetaTable backed by MetaObjectStub metaObjects.
            itemIds = {'item_001'; 'item_002'; 'item_003'};
            values = [10; 20; 30];
            entries = table(itemIds, values, ...
                'VariableNames', {'itemID', 'Value'});

            mt = nansen.metadata.MetaTable(entries, ...
                'MetaTableClass', 'nansen.unittest.metadata.helper.MetaObjectStub', ...
                'MetaTableIdVarname', 'itemID');
        end

        function mt = createStructBackedMetaTable(~)
            % Build a MetaTable with no item class so meta objects are
            % created via the @table2struct fallback. Each meta object is a
            % struct whose field set mirrors the current column set.
            itemIds = {'item_001'; 'item_002'; 'item_003'};
            values = [10; 20; 30];
            entries = table(itemIds, values, ...
                'VariableNames', {'itemID', 'Value'});

            mt = nansen.metadata.MetaTable(entries, ...
                'MetaTableIdVarname', 'itemID');
        end
    end
end
