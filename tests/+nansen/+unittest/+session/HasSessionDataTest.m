classdef HasSessionDataTest < matlab.unittest.TestCase
%HasSessionDataTest Lazy, display-safe Data access on the HasSessionData mixin
%
%   Verifies that the Data property is visible but initializes lazily on
%   access, never during display (which would otherwise scan disk). Uses a
%   fake host whose empty DataLocationModel makes initialize() abort with a
%   recognizable message ("does not have a DataLocationModel"), so "did
%   initialize run" is observable without needing a project.

    methods (Test)
        function dataPropertyIsVisible(testCase)
        %dataPropertyIsVisible Data is not Hidden, so it appears in display.
            mc = ?nansen.unittest.session.helper.FakeSessionEntity;
            dataProp = findobj(mc.PropertyList, 'Name', 'Data');
            testCase.assertNotEmpty(dataProp, "Data property should exist")
            testCase.verifyFalse(dataProp.Hidden, ...
                "Data should be visible so it appears in the session display")
        end

        function dataAccessReturnsSameSessionData(testCase)
        %dataAccessReturnsSameSessionData obj.Data returns a stable SessionData.
            entity = nansen.unittest.session.helper.FakeSessionEntity();
            firstData = entity.Data;
            secondData = entity.Data;
            testCase.verifyClass(firstData, 'nansen.session.SessionData')
            testCase.verifySameHandle(firstData, secondData)
        end

        function displayShowsDataWithoutInitializing(testCase)
        %displayShowsDataWithoutInitializing Data is shown but not initialized.
            shown = evalc('disp(nansen.unittest.session.helper.FakeSessionEntity())');
            testCase.verifyTrue(contains(shown, "Data"), ...
                "The Data property should be shown in the display")
            testCase.verifyFalse(contains(shown, "does not have"), ...
                "Display must not trigger SessionData initialization")
        end

        function displayKeepsDynamicProperties(testCase)
        %displayKeepsDynamicProperties Dynamic metadata props still appear.
            shown = evalc([ ...
                'e = nansen.unittest.session.helper.FakeSessionEntity(); ' ...
                'addprop(e, ''BrainRegion''); e.BrainRegion = "cortex"; disp(e);']);
            testCase.verifyTrue(contains(shown, "BrainRegion"), ...
                "Dynamic (metadata) properties must still appear in the display")
            testCase.verifyFalse(contains(shown, "does not have"), ...
                "Showing dynamic properties must not initialize Data")
        end

        function accessingDataTriggersInitialize(testCase)
        %accessingDataTriggersInitialize First .Data access runs initialize().
            shown = evalc( ...
                'e = nansen.unittest.session.helper.FakeSessionEntity(); e.Data;');
            testCase.verifyTrue(contains(shown, "does not have"), ...
                "Accessing .Data should trigger lazy initialize")
        end
    end
end
