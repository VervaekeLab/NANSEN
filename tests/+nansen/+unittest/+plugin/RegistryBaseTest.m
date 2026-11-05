classdef RegistryBaseTest < matlab.unittest.TestCase
%RegistryBaseTest Unit tests for nansen.plugin.base.Registry.
%
%   Tests source pinning, middle-tier ordering, removeSource from any slot,
%   reconcile event emission, and precedence-based dedup.

    properties
        TempDir (1,1) string  % Temporary directory root for test sources
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = string(tempname());
            mkdir(testCase.TempDir)
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'))
        end
    end

    methods (Test)

        function testEmptyRegistryListReturnsEmpty(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            entries = reg.list();
            testCase.verifyEmpty(entries)
        end

        function testPinTopSingleSlot(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            dirB = testCase.makeSourceDir('B', {'Beta'});

            reg.pinTop("src-a", dirA);
            reg.reconcile();
            testCase.verifyEqual([reg.list().PluginId], "Alpha")

            % Replacing the top slot should switch to the new source
            reg.pinTop("src-b", dirB);
            reg.reconcile();
            testCase.verifyEqual([reg.list().PluginId], "Beta")
        end

        function testPinBottomSingleSlot(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            dirB = testCase.makeSourceDir('B', {'Beta'});

            reg.pinBottom("src-a", dirA);
            reg.reconcile();
            testCase.verifyEqual([reg.list().PluginId], "Alpha")

            reg.pinBottom("src-b", dirB);
            reg.reconcile();
            testCase.verifyEqual([reg.list().PluginId], "Beta")
        end

        function testMiddleTierOrderedAppend(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            dirB = testCase.makeSourceDir('B', {'Beta'});
            dirC = testCase.makeSourceDir('C', {'Gamma'});

            reg.addSource("src-a", dirA);
            reg.addSource("src-b", dirB);
            reg.addSource("src-c", dirC);
            reg.reconcile();

            ids = [reg.list().PluginId];
            testCase.verifyEqual(ids, ["Alpha", "Beta", "Gamma"])
        end

        function testAddSourceErrorsOnDuplicateId(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dir1 = testCase.makeSourceDir('X1', {'P1'});
            dir2 = testCase.makeSourceDir('X2', {'P2'});
            reg.addSource("dup-id", dir1);
            testCase.verifyError(@() reg.addSource("dup-id", dir2), ...
                'NANSEN:Registry:DuplicateSourceId')
        end

        function testRemoveSourceFromMiddle(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            dirB = testCase.makeSourceDir('B', {'Beta'});
            reg.addSource("src-a", dirA);
            reg.addSource("src-b", dirB);
            reg.reconcile();

            reg.removeSource("src-a");
            reg.reconcile();
            ids = [reg.list().PluginId];
            testCase.verifyEqual(ids, "Beta")
        end

        function testRemoveSourceFromTop(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            reg.pinTop("top", dirA);
            reg.reconcile();
            testCase.verifyNumElements(reg.list(), 1)

            reg.removeSource("top");
            reg.reconcile();
            testCase.verifyEmpty(reg.list())
        end

        function testRemoveSourceFromBottom(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirB = testCase.makeSourceDir('B', {'Beta'});
            reg.pinBottom("bottom", dirB);
            reg.reconcile();
            testCase.verifyNumElements(reg.list(), 1)

            reg.removeSource("bottom");
            reg.reconcile();
            testCase.verifyEmpty(reg.list())
        end

        function testRemoveUnknownSourceIsNoop(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            reg.addSource("src-a", dirA);
            reg.reconcile();

            % Should not error
            reg.removeSource("nonexistent");
            reg.reconcile();
            testCase.verifyNumElements(reg.list(), 1)
        end

        function testPrecedenceTopWinsOverMiddleAndBottom(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();

            % Same plugin id 'Alpha' in all three tiers
            dirTop    = testCase.makeSourceDir('Top',    {'Alpha'}, struct('Source', 'top'));
            dirMiddle = testCase.makeSourceDir('Middle', {'Alpha'}, struct('Source', 'middle'));
            dirBottom = testCase.makeSourceDir('Bottom', {'Alpha'}, struct('Source', 'bottom'));

            reg.pinBottom("bottom", dirBottom);
            reg.addSource("middle", dirMiddle);
            reg.pinTop("top", dirTop);
            reg.reconcile();

            entries = reg.list();
            testCase.verifyNumElements(entries, 1)
            testCase.verifyEqual(entries.Source, "top")
        end

        function testReconcileEmitsPluginAddedOnNew(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});

            addedCount = 0;
            addlistener(reg, 'PluginAdded', @(~,~) incr());

            reg.addSource("src-a", dirA);
            reg.reconcile();
            testCase.verifyEqual(addedCount, 1)

            function incr(); addedCount = addedCount + 1; end
        end

        function testReconcileEmitsPluginRemovedOnMissing(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});

            removedCount = 0;
            addlistener(reg, 'PluginRemoved', @(~,~) incr());

            reg.addSource("src-a", dirA);
            reg.reconcile();

            reg.removeSource("src-a");
            reg.reconcile();
            testCase.verifyEqual(removedCount, 1)

            function incr(); removedCount = removedCount + 1; end
        end

        function testReconcileEmitsPluginRegistryReconciled(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            reconciledCount = 0;
            addlistener(reg, 'PluginRegistryReconciled', @(~,~) incr());

            reg.reconcile();
            reg.reconcile();
            testCase.verifyEqual(reconciledCount, 2)

            function incr(); reconciledCount = reconciledCount + 1; end
        end

        function testGetReturnsCorrectEntry(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha', 'Beta'});
            reg.addSource("src-a", dirA);
            reg.reconcile();

            alpha = reg.get("Alpha");
            testCase.verifyEqual(alpha.PluginId, "Alpha")
        end

        function testGetReturnsEmptyForUnknownId(testCase)
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            entry = reg.get("DoesNotExist");
            testCase.verifyEmpty(entry)
        end

        function testListScansSourcesAfterAddSource(testCase)
        %testListScansSourcesAfterAddSource list scans a source added since the last lookup
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            dirB = testCase.makeSourceDir('B', {'Beta'});

            reg.addSource("src-a", dirA);
            testCase.verifyEqual([reg.list().PluginId], "Alpha")

            reg.addSource("src-b", dirB);
            testCase.verifyEqual([reg.list().PluginId], ["Alpha", "Beta"])
        end

        function testListScansSourcesAfterRemoveSource(testCase)
        %testListScansSourcesAfterRemoveSource list drops a source removed since the last lookup
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            dirB = testCase.makeSourceDir('B', {'Beta'});
            reg.addSource("src-a", dirA);
            reg.addSource("src-b", dirB);
            reg.list();

            reg.removeSource("src-a");
            testCase.verifyEqual([reg.list().PluginId], "Beta")
        end

        function testGetScansSourcesAfterChange(testCase)
        %testGetScansSourcesAfterChange get scans a source added since the last lookup
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});

            reg.pinBottom("bottom", dirA);
            alpha = reg.get("Alpha");
            testCase.verifyEqual(alpha.PluginId, "Alpha")
        end

        function testLookupsScanOncePerChange(testCase)
        %testLookupsScanOncePerChange Lookups without a change in between reuse the last scan
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            reconciledCount = 0;
            addlistener(reg, 'PluginRegistryReconciled', @(~,~) incr());

            reg.addSource("src-a", dirA);
            reg.list();
            reg.get("Alpha");
            reg.resolve("Alpha");
            testCase.verifyEqual(reconciledCount, 1)
            testCase.verifyFalse(reg.IsStale)

            function incr(); reconciledCount = reconciledCount + 1; end
        end

        function testRemovingUnknownSourceKeepsEntriesCurrent(testCase)
        %testRemovingUnknownSourceKeepsEntriesCurrent Removing no source needs no new scan
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            reg.addSource("src-a", dirA);
            reg.list();

            reg.removeSource("nonexistent");
            testCase.verifyFalse(reg.IsStale)
        end

        function testListenerThatListsGetsNewEntries(testCase)
        %testListenerThatListsGetsNewEntries A PluginAdded listener can call list
        %
        %   The entries are stored before the events fire, so list in a
        %   listener returns them and does not start another scan.
            reg = nansen.unittest.plugin.helper.ConcreteRegistry();
            dirA = testCase.makeSourceDir('A', {'Alpha'});
            reg.addSource("src-a", dirA);

            listedIds = string.empty;
            reconciledCount = 0;
            addlistener(reg, 'PluginAdded', @(~,~) recordListedIds());
            addlistener(reg, 'PluginRegistryReconciled', @(~,~) incr());

            reg.list();
            testCase.verifyEqual(listedIds, "Alpha")
            testCase.verifyEqual(reconciledCount, 1)

            function recordListedIds(); listedIds = [reg.list().PluginId]; end
            function incr(); reconciledCount = reconciledCount + 1; end
        end
    end

    methods (Access = private)
        function dirPath = makeSourceDir(testCase, name, pluginIds, extraFields)
        %makeSourceDir Create a temp directory that scanSource will read.
        %
        %   The ConcreteRegistry's scanSource reads a plugins.mat file written
        %   by this helper.
            if nargin < 4
                extraFields = struct();
            end
            dirPath = fullfile(testCase.TempDir, name);
            mkdir(dirPath)

            plugins = struct('PluginId', {}, 'Source', {});
            for i = 1:numel(pluginIds)
                s = struct('PluginId', string(pluginIds{i}), 'Source', string(name));
                fields = fieldnames(extraFields);
                for f = 1:numel(fields)
                    fieldValue = extraFields.(fields{f});
                    if ischar(fieldValue) || isstring(fieldValue)
                        fieldValue = string(fieldValue);
                    end
                    s.(fields{f}) = fieldValue;
                end
                plugins(end+1) = s; %#ok<AGROW>
            end
            save(fullfile(dirPath, 'plugins.mat'), 'plugins')
        end
    end
end
