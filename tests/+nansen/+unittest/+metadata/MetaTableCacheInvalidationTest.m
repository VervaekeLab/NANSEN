classdef MetaTableCacheInvalidationTest < matlab.unittest.TestCase
    %MetaTableCacheInvalidationTest Cache repair for MetaTable metaObjects.
    %
    %   These tests cover the cache contract for table-to-object edits:
    %   MetadataEntity objects refresh in place, unsupported cache entries
    %   fall back to drop-and-rebuild, and removed rows still delete cached
    %   handles.
    %
    %   Run tests:
    %       runtests('nansen.unittest.metadata.MetaTableCacheInvalidationTest')

    methods (Test)
        function testEditEntriesRefreshesMetadataEntityInPlace(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            mt.editEntries(1, 'Value', 9999);

            refreshedItem = mt.getMetaObjects(1);
            testCase.verifyTrue(refreshedItem == cachedItem);
            testCase.verifyTrue(isvalid(cachedItem));
            testCase.verifyEqual(cachedItem.Value, 9999);
        end

        function testEditEntriesWithRefreshCacheFalseSkipsRefresh(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            mt.editEntries(1, 'Value', 9999, RefreshCache=false);

            sameItem = mt.getMetaObjects(1);
            testCase.verifyTrue(sameItem == cachedItem);
            testCase.verifyTrue(isvalid(cachedItem));
            testCase.verifyEqual(cachedItem.Value, 10);
            testCase.verifyEqual(mt.entries.Value(1), 9999);
        end

        function testReplaceDataColumnRefreshesMetadataEntitiesInPlace(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItems = mt.getMetaObjects(1:3);
            newValues = [101; 102; 103];
            mt.replaceDataColumn('Value', newValues);

            refreshedItems = mt.getMetaObjects(1:3);
            testCase.verifyTrue(all(refreshedItems == cachedItems));
            testCase.verifyTrue(all(isvalid(cachedItems)));
            testCase.verifyEqual([cachedItems.Value]', newValues);
        end

        function testMergeEntriesRefreshesMetadataEntityInPlace(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            sourceEntries = mt.entries;
            sourceMembers = mt.members;
            sourceEntries.Value(1) = 777;

            wasMerged = mt.mergeEntries(sourceEntries, sourceMembers);

            refreshedItem = mt.getMetaObjects(1);
            testCase.verifyTrue(wasMerged);
            testCase.verifyTrue(refreshedItem == cachedItem);
            testCase.verifyTrue(isvalid(cachedItem));
            testCase.verifyEqual(cachedItem.Value, 777);
        end

        function testObservablePropertySyncKeepsMetadataEntityAlive(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            cachedItem.Value = 4242;

            testCase.verifyTrue(isvalid(cachedItem));
            testCase.verifyEqual(mt.entries.Value(1), 4242);
        end

        function testAddTableVariableAddsDynamicPropertyInPlace(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            testCase.assertFalse(isprop(cachedItem, 'NewVar'));

            mt.addTableVariable('NewVar', 0);

            refreshedItem = mt.getMetaObjects(1);
            testCase.verifyTrue(refreshedItem == cachedItem);
            testCase.verifyTrue(isvalid(cachedItem));
            testCase.verifyTrue(isprop(cachedItem, 'NewVar'));
            testCase.verifyEqual(cachedItem.NewVar, 0);
        end

        function testRemoveTableVariableRemovesDynamicPropertyInPlace(testCase)
            mt = testCase.createRefreshableItemMetaTable();
            mt.addTableVariable('NewVar', 0);

            cachedItem = mt.getMetaObjects(1);
            testCase.assertTrue(isprop(cachedItem, 'NewVar'));

            mt.removeTableVariable('NewVar');

            refreshedItem = mt.getMetaObjects(1);
            testCase.verifyTrue(refreshedItem == cachedItem);
            testCase.verifyTrue(isvalid(cachedItem));
            testCase.verifyFalse(isprop(cachedItem, 'NewVar'));
        end

        function testRemoveClassDefinedVariableKeepsClassProperty(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            mt.removeTableVariable('Value');

            refreshedItem = mt.getMetaObjects(1);
            testCase.verifyTrue(refreshedItem == cachedItem);
            testCase.verifyTrue(isvalid(cachedItem));
            testCase.verifyTrue(isprop(cachedItem, 'Value'));
        end

        function testStructBackedAddTableVariableRebuildsCache(testCase)
            mt = testCase.createStructBackedMetaTable();

            cached = mt.getMetaObjects(1:3);
            testCase.assertTrue(isstruct(cached));
            testCase.assertFalse(isfield(cached, 'NewVar'));

            mt.addTableVariable('NewVar', 0);

            rebuilt = mt.getMetaObjects(1:3);
            testCase.verifyTrue(isfield(rebuilt, 'NewVar'));
        end

        function testStructBackedRemoveTableVariableRebuildsCache(testCase)
            mt = testCase.createStructBackedMetaTable();
            mt.addTableVariable('NewVar', 0);

            cached = mt.getMetaObjects(1:3);
            testCase.assertTrue(isfield(cached, 'NewVar'));

            mt.removeTableVariable('NewVar');

            rebuilt = mt.getMetaObjects(1:3);
            testCase.verifyFalse(isfield(rebuilt, 'NewVar'));
        end

        function testStructBackedPartialCacheAfterAddDoesNotError(testCase)
            mt = testCase.createStructBackedMetaTable();

            mt.getMetaObjects(1:2);
            mt.addTableVariable('NewVar', 0);

            rebuilt = mt.getMetaObjects(1:3);
            testCase.verifyEqual(numel(rebuilt), 3);
            testCase.verifyTrue(isfield(rebuilt, 'NewVar'));
        end

        function testStructBackedEditEntriesRebuildsCache(testCase)
            mt = testCase.createStructBackedMetaTable();

            cached = mt.getMetaObjects(1);
            testCase.assertTrue(isstruct(cached));
            testCase.assertEqual(cached.Value, 10);

            mt.editEntries(1, 'Value', 9999);

            rebuilt = mt.getMetaObjects(1);
            testCase.verifyEqual(rebuilt.Value, 9999);
        end

        function testNonMetadataEntityHandleFallsBackToDelete(testCase)
            mt = testCase.createObservableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            mt.editEntries(1, 'Value', 9999);

            rebuiltItem = mt.getMetaObjects(1);
            testCase.verifyFalse(isvalid(cachedItem));
            testCase.verifyEqual(rebuiltItem.Value, 9999);
        end

        function testRemoveEntriesDeletesCachedMetadataEntity(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            mt.removeEntries(mt.members{1});

            testCase.verifyFalse(isvalid(cachedItem));
        end

        function testRefreshFailureWarnsAndDeletesCachedMetadataEntity(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            testCase.verifyWarning( ...
                @() mt.editEntries(1, 'NonnegativeValue', -1), ...
                'NANSEN:MetaTable:MetaObjectRefreshFailed');

            testCase.verifyFalse(isvalid(cachedItem));
        end

        function testDestroyingCachedObjectEvictsItFromCache(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            delete(cachedItem);

            rebuiltItem = mt.getMetaObjects(1);
            testCase.verifyTrue(isvalid(rebuiltItem));
        end

        function testDestroyingUncachedObjectDoesNotEvictCachedObject(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            cachedItem = mt.getMetaObjects(1);
            duplicate = mt.getMetaObjects(1, 'UseCache', false);
            testCase.assertFalse(cachedItem == duplicate);

            delete(duplicate);

            rebuiltItem = mt.getMetaObjects(1);
            testCase.verifyTrue(rebuiltItem == cachedItem);
        end

        function testRoutineCacheFlowsAreWarningFree(testCase)
            mt = testCase.createRefreshableItemMetaTable();

            mt.getMetaObjects(1);
            testCase.verifyWarningFree(@() mt.editEntries(1, 'Value', 111));

            mt.getMetaObjects(1:3);
            testCase.verifyWarningFree(@() mt.resetMetaObjectCache());

            mt.getMetaObjects(1:3);
            testCase.verifyWarningFree(@() mt.addTableVariable('Extra', 0));

            cachedItem = mt.getMetaObjects(1);
            testCase.verifyWarningFree(@() delete(cachedItem));
        end
    end

    methods (Access = private)
        function mt = createRefreshableItemMetaTable(~)
            itemIds = {'item_001'; 'item_002'; 'item_003'};
            values = [10; 20; 30];
            nonnegativeValues = [1; 2; 3];
            entries = table(itemIds, values, nonnegativeValues, ...
                'VariableNames', {'itemID', 'Value', 'NonnegativeValue'});

            mt = nansen.metadata.MetaTable(entries, ...
                'MetaTableClass', 'nansen.unittest.metadata.helper.RefreshableTestItem', ...
                'MetaTableIdVarname', 'itemID');
        end

        function mt = createObservableItemMetaTable(~)
            itemIds = {'item_001'; 'item_002'; 'item_003'};
            values = [10; 20; 30];
            entries = table(itemIds, values, ...
                'VariableNames', {'itemID', 'Value'});

            mt = nansen.metadata.MetaTable(entries, ...
                'MetaTableClass', 'nansen.unittest.metadata.helper.MetaObjectStub', ...
                'MetaTableIdVarname', 'itemID');
        end

        function mt = createStructBackedMetaTable(~)
            itemIds = {'item_001'; 'item_002'; 'item_003'};
            values = [10; 20; 30];
            entries = table(itemIds, values, ...
                'VariableNames', {'itemID', 'Value'});

            mt = nansen.metadata.MetaTable(entries, ...
                'MetaTableIdVarname', 'itemID');
        end
    end
end
