classdef SubfieldLayoutTest < matlab.unittest.TestCase
%SubfieldLayoutTest Vertical order of nested struct fields in the struct editor
%
%   The tests read control positions from a hidden editor. Run tests:
%       runtests('nansen.unittest.structeditor.SubfieldLayoutTest')

    methods (Test, TestTags="Graphical")

        function testSubfieldsAppearInFieldOrder(testCase)
            data = struct('Before', 'a', ...
                'Group', struct('Inner1', 'b', 'Inner2', 'c', 'Inner3', 'd'), ...
                'After', 'e');
            editor = testCase.createEditor(data);

            yPositions = testCase.getYPositions(editor, ...
                ["Before", "Group.Inner1", "Group.Inner2", "Group.Inner3", "After"]);

            testCase.verifyTrue(all(diff(yPositions) < 0))
        end

        function testSkippedSubfieldKeepsOrderOfOthers(testCase)
            data = struct('Before', 'a', ...
                'Group', struct('Inner1', 'b', 'Hidden_', 'internal', 'Inner2', 'c'));
            editor = testCase.createEditor(data);

            yPositions = testCase.getYPositions(editor, ...
                ["Before", "Group.Inner1", "Group.Inner2"]);

            testCase.verifyTrue(all(diff(yPositions) < 0))
        end
    end

    methods (Access = private)

        function editor = createEditor(testCase, data)
            editor = structeditor.App(data, 'Visible', 'off');
            testCase.addTeardown(@delete, editor)
        end
    end

    methods (Static, Access = private)

        function yPositions = getYPositions(editor, tags)
            yPositions = zeros(size(tags));
            for iTag = 1:numel(tags)
                control = findall(editor.Figure, 'Type', 'uicontrol', 'Tag', tags(iTag));
                yPositions(iTag) = control.Position(2);
            end
        end
    end
end
