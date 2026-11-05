classdef MetaTableCellColumnTest < matlab.unittest.TestCase
    %MetaTableCellColumnTest Tests for cell-column assignment in MetaTable.
    %
    %   Covers the assignEntries code path where the current column value
    %   is a cell (the scalar-cell-in-cell convention: each row stores a
    %   1x1 cell wrapping the actual value). Tests verify that plain,
    %   already-wrapped, and doubly-wrapped inputs are all normalised to
    %   a single-wrapped cell in the table without extra nesting.
    %
    %   Run tests:
    %       runtests('nansen.unittest.metadata.MetaTableCellColumnTest')

    methods (Test)

        function testAssignCharToCellColumnWrapsValue(testCase)
            % Assigning a plain char to a cell-column entry wraps it in a
            % cell so the column type stays consistent.
            mt = testCase.createCellColumnMetaTable();
            mt.editEntries(1, 'Tags', 'newtag');
            testCase.verifyEqual(mt.entries{1, 'Tags'}, {'newtag'});
        end

        function testAssignCellToCellColumnDoesNotDoubleWrap(testCase)
            % Assigning a properly-wrapped cell {'value'} stores it as-is.
            % Regression: old try/catch could produce {{'value'}} when the
            % direct assignment happened to succeed before wrapping.
            mt = testCase.createCellColumnMetaTable();
            mt.editEntries(1, 'Tags', {'newtag'});

            result = mt.entries{1, 'Tags'};
            testCase.verifyEqual(result, {'newtag'});
            testCase.verifyFalse(nansen.util.cell.isWrapped(result));
        end

        function testAssignDoubleWrappedCellUnwraps(testCase)
            % A doubly-wrapped input {{'value'}} is unwrapped to {'value'}
            % before storage. Regression: without the isWrapped check the
            % table would store {{'value'}} and subsequent reads would
            % return an extra layer of cell nesting.
            mt = testCase.createCellColumnMetaTable();
            mt.editEntries(1, 'Tags', {{'newtag'}});

            result = mt.entries{1, 'Tags'};
            testCase.verifyEqual(result, {'newtag'});
            testCase.verifyFalse(nansen.util.cell.isWrapped(result));
        end

    end

    methods (Access = private)
        function mt = createCellColumnMetaTable(~)
            itemIds = {'item_001'; 'item_002'; 'item_003'};
            % Each Tags entry is a scalar cell wrapping a char — the
            % convention for cell-type columns in NANSEN MetaTables.
            tags = {{'tag1'}; {'tag2'}; {'tag3'}};
            entries = table(itemIds, tags, ...
                'VariableNames', {'itemID', 'Tags'});

            mt = nansen.metadata.MetaTable(entries, ...
                'MetaTableIdVarname', 'itemID');
        end
    end
end
