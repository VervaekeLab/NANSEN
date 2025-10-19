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
            projectDir = nansentools.projectdir();
            matbox.installRequirements(projectDir, "AgreeToLicenses", true)

            % Verify that a couple of the requirements are installed
            testCase.verifyTrue( logical(exist('Catalog', 'file')) )
            testCase.verifyTrue( logical(exist('downloadFile', 'file')) )
        end

        function testPrefdir(testCase)
            fprintf('Nansen prefdir: %s\n', nansen.prefdir)
        end
    end

    methods (Test, TestTags="Graphical")
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
