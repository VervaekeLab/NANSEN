%% Test class for Nansen Setup
classdef TestInstallation < matlab.unittest.TestCase

    properties
        Folder (1,1) string = missing
        NansenRootPath (1,1) string = missing
    end

    methods (TestClassSetup)

        function clearEverything(testCase)
            close all force
            clear all
            clear classes
        end

        function setup(testCase)
            testCase.Folder = testCase.createTemporaryFolder();
            testCase.NansenRootPath = nansen.rootpath;
        end

        function setupTemporaryUserPath(testCase)
            currentUserpath = userpath();
            userpath(testCase.Folder)
            testCase.addTeardown(@userpath, currentUserpath)
        end

        function resetSearchPath(testCase)
            searchPathStr = path;
            restoredefaultpath()
            testCase.addTeardown(@path, searchPathStr)
        end

        function clearPreferences(testCase)
            %nansenPreferenceFolderPath = fullfile(prefdir, 'Nansen');
            %backupPath = fullfile(prefdir, 'Nansen-Test-Backup');
        end

        function addNansenToPath(testCase)
            testCase.applyFixture(...
                matlab.unittest.fixtures.PathFixture(...
                    testCase.NansenRootPath, "IncludingSubfolders",true));

            % testCase.applyFixture(...
            %     matlab.unittest.fixtures.PathFixture(...
            %         testCase.NansenRootPath, "IncludingSubfolders",true));
        end
    end

    methods (Test)
        function testPath(testCase)
            s = which('nansen');
            if isempty(s)
                disp( 'nansen not on path')
            else
                disp( s )
            end
        end

        function testUserPath(testCase)
            fprintf('Userpath: %s\n', userpath)
        end

        function testInstallDependencies(testCase)
            nansen.internal.setup.installDependencies("SaveUpdatedPath", true)
        end

        function testCreateCatalog(testCase)
            C = Catalog();
            disp(C)
        end

        function testSetup(testCase)
            nansen.setup()
        end

        function testSearchPath(testCase)
            fprintf('SearchPath: %s\n', path)
        end

        function testPrefdir(testCase)
            fprintf('Nansen prefdir: %s\n', nansen.prefdir)
        end
    end
end

function restorePreferences(originalPathName, backupPathName)


end