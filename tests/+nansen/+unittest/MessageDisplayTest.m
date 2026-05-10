classdef MessageDisplayTest < matlab.unittest.TestCase

    methods (Test, TestTags="Graphical")
        function testModernProgressDialogForUiFigure(testCase)
            hFigure = uifigure('Visible', 'on');
            figureCleanup = onCleanup(@() delete(hFigure));

            messageDisplay = nansen.MessageDisplay(hFigure);
            hDialog = messageDisplay.wait('Testing progress dialog', ...
                'Title', 'MessageDisplay Test');
            dialogCleanup = onCleanup(@() delete(hDialog));

            testCase.verifyClass(hDialog, 'matlab.ui.dialog.ProgressDialog')

            messageDisplay.updateProgress(hDialog, 0.5, 'Halfway');
            testCase.verifyEqual(hDialog.Value, 0.5, 'AbsTol', eps)

            clear dialogCleanup figureCleanup
        end
    end
end
