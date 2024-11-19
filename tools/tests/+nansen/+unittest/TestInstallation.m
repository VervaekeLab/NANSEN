%% Test class for Nansen Setup
classdef TestInstallation < matlab.unittest.TestCase

    properties
        Folder (1,1) string = missing
        NansenRootPath (1,1) string = missing
    end

    properties (Access = private)
        ForceRun = false
    end
    
    methods 
        function testCase = TestInstallation(forceRun)
            arguments
                forceRun = false
            end
            testCase.ForceRun = forceRun;
        end
    end

    methods (Test)
        function testPath(testCase)
            s = which('nansen');
            assert(~isempty(s), 'Expected NANSEN to be on MATLAB''s search path during testing')
        end

        function testSearchPath(testCase)
            fprintf('SearchPath: %s\n', path)
        end

        function testUserPath(testCase)
            fprintf('Userpath: %s\n', userpath)
        end

        function testInstallDependencies(testCase)
            nansen.internal.setup.installDependencies("SaveUpdatedPath", true)
        end

        function testCreateCatalog(testCase)
            C = Catalog();
        end

        function testPrefdir(testCase)
            fprintf('Nansen prefdir: %s\n', nansen.prefdir)
        end

        function testCase = testOpenWizard(testCase)
            %nansen.setup()
            wizardApp = nansen.app.setup.SetupWizard();
            
            % Go to addons page
            wizardApp.changePage()

            % Go to projects page
            wizardApp.changePage()

            % Todo: Import test project
            % Todo: Create test project
            % wizardApp.changePage()
        end
    end
end

function restorePreferences(originalPathName, backupPathName)


end