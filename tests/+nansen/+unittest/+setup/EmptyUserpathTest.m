classdef EmptyUserpathTest < matlab.unittest.TestCase
%EmptyUserpathTest Handling of an empty userpath by nansen_install
%
%   Calling the real userpath with an argument changes a setting that MATLAB
%   saves between sessions, so a stub replaces it. The stub keeps userpath's
%   documented behaviour: the folder must exist when it is set, and an
%   empty userpath is returned as empty char.
%
%   Run tests:
%       runtests('nansen.unittest.setup.EmptyUserpathTest')

    properties (Constant, Access = private)
        UserpathKey = 'EmptyUserpathTestValue'
        IgnoreSetKey = 'EmptyUserpathTestIgnoreSet'
    end

    properties (Access = private)
        Folder (1,1) string = missing
    end

    methods (TestClassSetup)
        function stubMatlabFunctions(testCase)
        %stubMatlabFunctions Shadow userpath
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture

            stubFolder = string(testCase.applyFixture(TemporaryFolderFixture).Folder);
            writelines([ ...
                "function value = userpath(newValue)"; ...
                "    if nargin == 0"; ...
                "        value = getappdata(groot, '" + testCase.UserpathKey + "');"; ...
                "        return"; ...
                "    end"; ...
                "    assert(isfolder(newValue), 'MATLAB:userpath:invalidInput', 'Folder must exist.')"; ...
                "    if ~getappdata(groot, '" + testCase.IgnoreSetKey + "')"; ...
                "        setappdata(groot, '" + testCase.UserpathKey + "', char(newValue))"; ...
                "    end"; ...
                "end"], fullfile(stubFolder, "userpath.m"))
            testCase.applyFixture(PathFixture(stubFolder))

            testCase.addTeardown(@rmappdata, groot, testCase.UserpathKey)
            testCase.addTeardown(@rmappdata, groot, testCase.IgnoreSetKey)
        end
    end

    methods (TestMethodSetup)
        function resetState(testCase)
            setappdata(groot, testCase.UserpathKey, '')
            setappdata(groot, testCase.IgnoreSetKey, false)

            testCase.assertFalse(startsWith(which("userpath"), matlabroot), ...
                "The tests must not reach MATLAB's userpath function.")

            testCase.Folder = string( ...
                testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
        end
    end

    methods (Test)
        function setsUserpathAndCreatesFolders(testCase)
            output = testCase.applyFolder(testCase.Folder, @(~) true);

            expectedUserpath = fullfile(testCase.Folder, "MATLAB");
            testCase.verifyEqual(string(userpath()), expectedUserpath)
            testCase.verifyTrue(isfolder(fullfile(expectedUserpath, "Nansen")))
            testCase.verifySubstring(output, char(expectedUserpath))
        end

        function defaultAddonFolderIsUsableAfterwards(testCase)
            testCase.applyFolder(testCase.Folder, @(~) true);

            testCase.verifyEqual(string(nansen.config.addons.getDefaultAddonFolder()), ...
                fullfile(testCase.Folder, "MATLAB", "Nansen", "Add-Ons"))
        end

        function existingFolderIsNotConfirmed(testCase)
            mkdir(fullfile(testCase.Folder, "MATLAB", "Nansen"))

            testCase.applyFolder(testCase.Folder, @failIfCalled);

            testCase.verifyEqual(string(userpath()), fullfile(testCase.Folder, "MATLAB"))
        end

        function surroundingSpaceIsIgnored(testCase)
            testCase.applyFolder("  " + testCase.Folder + " ", @(~) true);

            testCase.verifyEqual(string(userpath()), fullfile(testCase.Folder, "MATLAB"))
        end

        function decliningLeavesUserpathEmpty(testCase)
            testCase.verifyError(@() testCase.applyFolder(testCase.Folder, @(~) false), ...
                'NANSEN:SetUserpathAborted')

            testCase.verifyEmpty(userpath())
            testCase.verifyFalse(isfolder(fullfile(testCase.Folder, "MATLAB")))
        end

        function emptyAnswerAborts(testCase)
            testCase.verifyError(@() testCase.applyFolder("  ", @failIfCalled), ...
                'NANSEN:SetUserpathAborted')

            testCase.verifyEmpty(userpath())
        end

        function relativeFolderIsRejectedBeforeCreatingAnything(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(testCase.Folder))

            testCase.verifyError(@() testCase.applyFolder("relative/folder", @failIfCalled), ...
                'NANSEN:Setup:UserpathFolderNotAbsolute')

            testCase.verifyEmpty(userpath())
            testCase.verifyFalse(isfolder(fullfile(testCase.Folder, "relative")))
        end

        function reportsUserpathThatDidNotTakeEffect(testCase)
            setappdata(groot, testCase.IgnoreSetKey, true)

            testCase.verifyError(@() testCase.applyFolder(testCase.Folder, @(~) true), ...
                'NANSEN:Setup:UserpathNotSet')
        end

        function batchModeStopsWithInstruction(testCase)
            try
                nansen.internal.setup.resolveEmptyUserpath(IsBatchMode=true)
                testCase.verifyFail("Expected an error in batch mode.")
            catch exception
                testCase.verifyEqual(exception.identifier, 'NANSEN:Setup:EmptyUserpathInBatchMode')
                testCase.verifySubstring(exception.message, 'userpath("')
            end
        end
    end

    methods (Access = private)
        function output = applyFolder(~, folder, confirmCreateFolder) %#ok<INUSD>
        %applyFolder Set the userpath and return the printed message
            output = evalc("nansen.internal.setup.setUserpathFromFolder(folder, confirmCreateFolder)");
        end
    end
end

function isConfirmed = failIfCalled(folder) %#ok<STOUT>
    error('EmptyUserpathTest:UnexpectedConfirmation', 'Did not expect to confirm "%s".', folder)
end
