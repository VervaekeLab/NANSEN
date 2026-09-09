classdef ConformStructToTemplateTest < matlab.unittest.TestCase
    %ConformStructToTemplateTest Unit tests for utility.data.conformStructToTemplate
    %
    %   Each test states one way jsondecode changes the shape of a struct,
    %   and asserts that the shape is restored. The inputs are produced by
    %   an actual json round trip rather than hand written, so the tests
    %   fail if jsondecode changes behaviour.
    %
    %   Run tests:
    %       runtests('nansen.unittest.data.ConformStructToTemplateTest')

    methods (Access = private)

        function decoded = roundTrip(~, value)
        %roundTrip Send a value through json and back, as saving would
            decoded = jsondecode(jsonencode(value));
        end
    end

    methods (Test)

        % ----------------------------------------------------------------
        % Struct array shape
        % ----------------------------------------------------------------

        function testColumnStructArrayBecomesRow(testCase)
            template = struct('Name', '', 'Value', 0);
            items = struct('Name', {'a', 'b'}, 'Value', {1, 2});

            decoded = testCase.roundTrip(items);
            testCase.assertEqual(size(decoded), [2 1], ...
                'Precondition: jsondecode returns a column struct array.')

            conformed = utility.data.conformStructToTemplate(decoded, template);

            testCase.verifyEqual(size(conformed), [1 2])
            testCase.verifyEqual({conformed.Name}, {'a', 'b'})
        end

        function testEmptyArrayRegainsItsFieldNames(testCase)
            % An empty json array decodes to [], which carries no fields.
            % Code that validates items against fieldnames needs them back.
            template = struct('Name', '', 'Value', 0);

            conformed = utility.data.conformStructToTemplate([], template);

            testCase.verifyClass(conformed, 'struct')
            testCase.verifyEmpty(conformed)
            testCase.verifyEqual(fieldnames(conformed), {'Name'; 'Value'})
        end

        function testCellOfStructsIsFlattened(testCase)
            % A heterogeneous json array decodes to a cell of scalar structs.
            template = struct('Name', '', 'Value', 0);
            decoded = {struct('Name', 'a', 'Value', 1), struct('Name', 'b')};

            conformed = utility.data.conformStructToTemplate(decoded, template);

            testCase.verifyEqual(size(conformed), [1 2])
            testCase.verifyEqual(conformed(2).Value, 0, ...
                'A field the item lacks should be filled from the template.')
        end

        function testSingleItemStaysAnArray(testCase)
            template = struct('Name', '', 'Value', 0);

            conformed = utility.data.conformStructToTemplate( ...
                testCase.roundTrip(struct('Name', 'only', 'Value', 1)), template);

            testCase.verifyEqual(size(conformed), [1 1])
            testCase.verifyEqual(conformed.Name, 'only')
        end

        % ----------------------------------------------------------------
        % Field shape
        % ----------------------------------------------------------------

        function testEmptyCellSurvivesAsCell(testCase)
            % The damaging case: an empty cell decodes to [], so code that
            % expects a cell array of strings gets a double instead.
            template = struct('IgnoreList', {{}});

            decoded = testCase.roundTrip(struct('IgnoreList', {{}}));
            testCase.assertClass(decoded.IgnoreList, 'double', ...
                'Precondition: an empty cell decodes to [].')

            conformed = utility.data.conformStructToTemplate(decoded, template);

            testCase.verifyClass(conformed.IgnoreList, 'cell')
            testCase.verifyEmpty(conformed.IgnoreList)
        end

        function testPopulatedCellBecomesRow(testCase)
            template = struct('IgnoreList', {{}});

            conformed = utility.data.conformStructToTemplate( ...
                testCase.roundTrip(struct('IgnoreList', {{'temp', 'backup'}})), template);

            testCase.verifyEqual(conformed.IgnoreList, {'temp', 'backup'})
        end

        function testNumericColumnBecomesRow(testCase)
            template = struct('SubfolderLevel', []);

            conformed = utility.data.conformStructToTemplate( ...
                testCase.roundTrip(struct('SubfolderLevel', [1 2])), template);

            testCase.verifyEqual(conformed.SubfolderLevel, [1 2])
        end

        function testEmptyNumericStaysEmpty(testCase)
            template = struct('SubfolderLevel', []);

            conformed = utility.data.conformStructToTemplate( ...
                testCase.roundTrip(struct('SubfolderLevel', [])), template);

            testCase.verifyEmpty(conformed.SubfolderLevel)
        end

        function testLogicalIsRestored(testCase)
            template = struct('IsFolder', true);

            conformed = utility.data.conformStructToTemplate( ...
                testCase.roundTrip(struct('IsFolder', false)), template);

            testCase.verifyClass(conformed.IsFolder, 'logical')
            testCase.verifyFalse(conformed.IsFolder)
        end

        function testMissingCharBecomesEmptyChar(testCase)
            % A json null decodes to [], which is not a char vector.
            template = struct('Expression', '');

            conformed = utility.data.conformStructToTemplate( ...
                struct('Expression', []), template);

            testCase.verifyClass(conformed.Expression, 'char')
            testCase.verifyEmpty(conformed.Expression)
        end

        % ----------------------------------------------------------------
        % Nesting and pass-through
        % ----------------------------------------------------------------

        function testNestedStructArrayIsConformed(testCase)
            % The shape of a data location item: a nested struct array
            % whose own fields include a cell.
            template = struct('Name', '', 'SubfolderStructure', ...
                struct('Type', '', 'IgnoreList', {{}}));
            item = struct('Name', 'Rawdata', 'SubfolderStructure', ...
                struct('Type', {'Subject', 'Session'}, 'IgnoreList', {{}, {'temp'}}));

            conformed = utility.data.conformStructToTemplate( ...
                testCase.roundTrip(item), template);

            nested = conformed.SubfolderStructure;
            testCase.verifyEqual(size(nested), [1 2])
            testCase.verifyClass(nested(1).IgnoreList, 'cell')
            testCase.verifyEmpty(nested(1).IgnoreList)
            testCase.verifyEqual(nested(2).IgnoreList, {'temp'})
        end

        function testNestedEmptyStructArrayUsesTemplateFields(testCase)
            % RootPath is declared as an empty struct array of key/value
            % pairs, so the template for its items has no example element.
            template = struct('RootPath', struct('Key', {}, 'Value', {}));

            conformed = utility.data.conformStructToTemplate( ...
                struct('RootPath', []), template);

            testCase.verifyClass(conformed.RootPath, 'struct')
            testCase.verifyEmpty(conformed.RootPath)
            testCase.verifyEqual(fieldnames(conformed.RootPath), {'Key'; 'Value'})
        end

        function testUndeclaredFieldsArePreserved(testCase)
            % Uuid is added by the catalog, not by getBlankItem, so it must
            % survive a field it is not declared in.
            template = struct('Name', '');
            decoded = struct('Name', 'a', 'Uuid', 'abc-123');

            conformed = utility.data.conformStructToTemplate(decoded, template);

            testCase.verifyEqual(conformed.Uuid, 'abc-123')
        end

        function testEnumerationFieldIsLeftAlone(testCase)
            % A data location Type is restored by the catalog itself, from
            % the char the file holds. This must not interfere.
            template = struct('Type', nansen.config.dloc.DataLocationType('processed'));

            conformed = utility.data.conformStructToTemplate( ...
                struct('Type', 'recorded'), template);

            testCase.verifyEqual(conformed.Type, 'recorded')
        end
    end
end
