classdef FindInstallationProblemsTest < matlab.unittest.TestCase
    %FindInstallationProblemsTest What counts as missing from an installation
    %
    %   A migration of user data does not start when this check reports a
    %   problem. A folder or toolbox that NANSEN does not need must not be
    %   reported, and one that it needs must not be missed.
    %
    %   Run tests:
    %       runtests('nansen.unittest.FindInstallationProblemsTest')

    properties
        RootFolder (1,1) string
        CodeFolder (1,1) string
        SearchPath (1,:) string
    end

    properties (Constant)
        % Values for the installCheck of a dependency. The first resolves
        % to a file with which, as the check requires.
        FunctionOnThePath = "fullfile"
        FunctionOffThePath = "aFunctionThatIsNotOnThePath"
    end

    methods (TestMethodSetup)
        function createCodeFolder(testCase)
        %createCodeFolder Create a code folder that is on the search path

            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);

            testCase.RootFolder = string(fixture.Folder);
            testCase.CodeFolder = fullfile(testCase.RootFolder, "code");
            mkdir(fullfile(testCase.CodeFolder, "apps"))

            testCase.SearchPath = [testCase.CodeFolder, fullfile(testCase.CodeFolder, "apps")];
        end
    end

    methods (Test)

        function testCompleteInstallationHasNoProblems(testCase)
            problems = testCase.findProblems("required", testCase.FunctionOnThePath);

            testCase.verifyEmpty(problems)
        end

        function testCodeFolderOffThePathIsReported(testCase)
            testCase.SearchPath = testCase.CodeFolder;

            problems = testCase.findProblems("required", testCase.FunctionOnThePath);

            testCase.verifySize(problems, [1, 1])
            testCase.verifySubstring(problems, "apps")
        end

        function testNestedFoldersAreReportedByTheirTopFolder(testCase)
            mkdir(fullfile(testCase.CodeFolder, "external", "fileexchange"))

            problems = testCase.findProblems("required", testCase.FunctionOnThePath);

            testCase.verifyEqual(count(problems, "external"), 1)
            testCase.verifyFalse(contains(problems, "fileexchange"))
        end

        function testFoldersThatNeverGoOnThePathAreIgnored(testCase)
        %testFoldersThatNeverGoOnThePathAreIgnored Only genpath folders count
        %
        %   MATLAB finds these folders through their parent, or does not
        %   look in them at all, so a complete installation does not have
        %   them on the search path.

            for folderName = ["+package", "@SomeClass", "private", "resources"]
                mkdir(fullfile(testCase.CodeFolder, folderName))
            end

            problems = testCase.findProblems("required", testCase.FunctionOnThePath);

            testCase.verifyEmpty(problems)
        end

        function testRequiredToolboxOffThePathIsReported(testCase)
            problems = testCase.findProblems("required", testCase.FunctionOffThePath);

            testCase.verifySize(problems, [1, 1])
            testCase.verifySubstring(problems, "Test toolbox")
        end

        function testOptionalToolboxOffThePathIsIgnored(testCase)
            problems = testCase.findProblems("optional", testCase.FunctionOffThePath);

            testCase.verifyEmpty(problems)
        end

        function testEachKindOfProblemIsReported(testCase)
            testCase.SearchPath = testCase.CodeFolder;

            problems = testCase.findProblems("required", testCase.FunctionOffThePath);

            testCase.verifySize(problems, [1, 2])
        end
    end

    methods (Access = private)

        function problems = findProblems(testCase, requirementLevel, installCheck)
            manifestPath = testCase.writeManifest(requirementLevel, installCheck);

            problems = nansen.internal.setup.findInstallationProblems( ...
                CodeFolder=testCase.CodeFolder, ...
                SearchPath=testCase.SearchPath, ...
                ManifestPaths=manifestPath);
        end

        function manifestPath = writeManifest(testCase, requirementLevel, installCheck)
        %writeManifest Write a dependency manifest that declares one toolbox

            dependency = struct( ...
                "name", "Test toolbox", ...
                "dependencyType", "community-toolbox", ...
                "requirementLevel", requirementLevel, ...
                "installCheck", installCheck);

            manifest = struct( ...
                "x_schema_version", "1.0", ...
                "scope", "core", ...
                "scopeId", "core", ...
                "dependencies", {{dependency}});

            % A struct field can not start with an underscore, and the
            % manifest has to.
            manifestText = replace(jsonencode(manifest), """x_schema", """_schema");

            manifestPath = fullfile(testCase.RootFolder, "dependencies.nansen.json");
            utility.filewrite(char(manifestPath), manifestText)
        end
    end
end
