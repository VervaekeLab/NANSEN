classdef TabOrderTest < matlab.unittest.TestCase
%TabOrderTest Order in which the Tab key visits the struct editor's controls
%
%   The Tab key visits a panel's controls from the last to the first element
%   of Children. The tests read that order from a hidden editor.
%
%   Run tests:
%       runtests('nansen.unittest.structeditor.TabOrderTest')

    methods (Test, TestTags="Graphical")

        function testRowsAreVisitedFromTopToBottom(testCase)
            data = struct('First', 'a', 'Second', 'b', 'Third', 'c');

            controls = testCase.getControlsInTabOrder(data, 'First');

            testCase.verifyEqual({controls.Tag}, {'First', 'Second', 'Third'})
            yPositions = testCase.getPositions(controls, 2);
            testCase.verifyTrue(all(diff(yPositions) < 0))
        end

        function testSplitInputIsVisitedFromLeftToRight(testCase)
            data = struct('Before', 'a', 'Size', [1, 2, 3], 'After', 'b');

            controls = testCase.getControlsInTabOrder(data, 'Before');

            testCase.verifyEqual({controls.Tag}, ...
                {'Before', 'Size', 'Size', 'Size', 'After'})
            xPositions = testCase.getPositions(controls(2:4), 1);
            testCase.verifyTrue(all(diff(xPositions) > 0))
        end

        function testBrowseButtonFollowsItsInputField(testCase)
            data = struct('Before', 'a', 'FilePath', '', 'After', 'b');

            controls = testCase.getControlsInTabOrder(data, 'Before');

            testCase.verifyEqual({controls.Tag}, ...
                {'Before', 'FilePath', 'FilePath', 'After'})
            testCase.verifyEqual(controls(2).Style, 'edit')
            testCase.verifyEqual(controls(3).Style, 'pushbutton')
        end

        function testStructFieldsAreVisitedFromTopToBottom(testCase)
            data = struct('Before', 'a', ...
                'Group', struct('Inner1', 'b', 'Inner2', 'c'), 'After', 'd');

            controls = testCase.getControlsInTabOrder(data, 'Before');

            testCase.verifyLength(controls, 4)
            yPositions = testCase.getPositions(controls, 2);
            testCase.verifyTrue(all(diff(yPositions) < 0))
        end
    end

    methods (Access = private)

        function controls = getControlsInTabOrder(testCase, data, firstFieldName)
            editor = structeditor.App(data, 'Visible', 'off');
            testCase.addTeardown(@delete, editor)

            firstControl = findall(editor.Figure, 'Type', 'uicontrol', 'Tag', firstFieldName);
            children = flip(firstControl.Parent.Children);
            controls = children(isgraphics(children, 'uicontrol'));
        end
    end

    methods (Static, Access = private)

        function values = getPositions(controls, dimension)
            positions = vertcat(controls.Position);
            values = positions(:, dimension);
        end
    end
end
