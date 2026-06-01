classdef MetaTableCacheInvalidationTest < matlab.unittest.TestCase
    % MetaTableCacheInvalidationTest - Cache invalidation on entry edits
    %
    %   Regression coverage for issue #101: editEntries must keep the
    %   metaObject cache consistent with the entries table, while the
    %   reverse-sync path (a live metaObject updating its own backing row)
    %   must not delete the object the caller is holding.
    %
    %   Regression coverage for issue #104: adding or removing a table
    %   variable changes the column set, so cached meta objects built from
    %   the previous column set (struct objects from the @table2struct
    %   fallback) have a stale shape and must be invalidated.
    %
    %   These tests are intentionally self-contained: they build a MetaTable
    %   backed by a lightweight ObservableTestItem metaObject and do not
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
                'nansen.unittest.metadata.helper.ObservableTestItem');

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
            % Faithful reproduction of issue #104: a partially populated
            % cache (old column set) merged with freshly built structs (new
            % column set) used to throw a struct-field mismatch inside
            % utility.insertIntoArray.
            mt = testCase.createStructBackedMetaTable();
            mt.getMetaObjects(1:2); % Cache a subset against the old column set

            mt.addTableVariable('NewVar', 0);

            rebuilt = mt.getMetaObjects(1:3); % Previously threw in insertIntoArray
            testCase.verifyEqual(numel(rebuilt), 3);
            testCase.verifyTrue(isfield(rebuilt, 'NewVar'));
        end
    end

    methods (Access = private)
        function mt = createObservableItemMetaTable(~)
            % Build a MetaTable backed by ObservableTestItem metaObjects.
            itemIds = {'item_001'; 'item_002'; 'item_003'};
            values = [10; 20; 30];
            entries = table(itemIds, values, ...
                'VariableNames', {'itemID', 'Value'});

            mt = nansen.metadata.MetaTable(entries, ...
                'MetaTableClass', 'nansen.unittest.metadata.helper.ObservableTestItem', ...
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
