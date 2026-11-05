classdef PathUtilTest < matlab.unittest.TestCase
    %PathUtilTest Unit tests for nansen.util.path utilities.
    %
    %   Covers changeFilenameExtension, which must replace only the
    %   extension of the file name and never alter folder names, and the
    %   path predicates stripTrailingSeparator, isSamePath and isSubPath.
    %
    %   Run tests:
    %       runtests('nansen.unittest.util.PathUtilTest')

    methods (Test)

        % ----------------------------------------------------------------
        % changeFilenameExtension - ordinary use
        % ----------------------------------------------------------------

        function testExtensionIsReplaced(testCase)
            % The extension is swapped and the rest of the path is kept.
            inputPath = fullfile('/data', 'proj', 'settings.mat');
            expected = fullfile('/data', 'proj', 'settings.json');

            actual = nansen.util.path.changeFilenameExtension(inputPath, '.json');

            testCase.verifyEqual(actual, expected);
        end

        function testLeadingDotOnNewExtensionIsOptional(testCase)
            % Callers may pass the extension with or without a leading dot.
            inputPath = fullfile('/data', 'settings.mat');
            expected = fullfile('/data', 'settings.json');

            testCase.verifyEqual( ...
                nansen.util.path.changeFilenameExtension(inputPath, 'json'), expected);
            testCase.verifyEqual( ...
                nansen.util.path.changeFilenameExtension(inputPath, '.json'), expected);
        end

        function testReturnsCharacterVector(testCase)
            % The return type is char, matching how callers build paths.
            actual = nansen.util.path.changeFilenameExtension('settings.mat', 'json');

            testCase.verifyClass(actual, 'char');
        end

        % ----------------------------------------------------------------
        % changeFilenameExtension - folder names must not be rewritten
        % ----------------------------------------------------------------

        function testFolderContainingDottedExtensionIsPreserved(testCase)
            % Regression: a substring replacement over the whole path
            % rewrote parent folders that contain the old extension, so
            % "archive.mat.backup" silently became "archive.json.backup".
            folderPath = fullfile('/data', 'archive.mat.backup');
            inputPath = fullfile(folderPath, 'settings.mat');

            actual = nansen.util.path.changeFilenameExtension(inputPath, '.json');

            testCase.verifyEqual(fileparts(actual), folderPath);
            testCase.verifyEqual(actual, fullfile(folderPath, 'settings.json'));
        end

        function testFolderContainingExtensionLettersIsPreserved(testCase)
            % Regression: replacing the bare letters "mat" rewrote folders
            % such as "matlab" or "automation".
            folderPath = fullfile('/data', 'matlab', 'automation');
            inputPath = fullfile(folderPath, 'settings.mat');

            actual = nansen.util.path.changeFilenameExtension(inputPath, '.json');

            testCase.verifyEqual(fileparts(actual), folderPath);
        end

        function testFolderSharingTheInputExtensionIsPreserved(testCase)
            % The folder ends with the same extension as the file, which is
            % the worst case for a substring replacement.
            folderPath = fullfile('/data', 'stack.tif');
            inputPath = fullfile(folderPath, 'frame.tif');

            actual = nansen.util.path.changeFilenameExtension(inputPath, '.raw');

            testCase.verifyEqual(actual, fullfile(folderPath, 'frame.raw'));
        end

        % ----------------------------------------------------------------
        % changeFilenameExtension - edge cases
        % ----------------------------------------------------------------

        function testOnlyFinalExtensionIsReplaced(testCase)
            % A file name may contain dots; only the last one is the
            % extension.
            inputPath = fullfile('/data', 'my.file.name.mat');

            actual = nansen.util.path.changeFilenameExtension(inputPath, '.json');

            testCase.verifyEqual(actual, fullfile('/data', 'my.file.name.json'));
        end

        function testFilenameWithoutFolderIsSupported(testCase)
            % A bare file name has no folder part to preserve.
            actual = nansen.util.path.changeFilenameExtension('settings.mat', '.json');

            testCase.verifyEqual(actual, 'settings.json');
        end

        function testExtensionIsAppendedWhenInputHasNone(testCase)
            % An input without an extension gains one.
            inputPath = fullfile('/data', 'settings');

            actual = nansen.util.path.changeFilenameExtension(inputPath, '.json');

            testCase.verifyEqual(actual, fullfile('/data', 'settings.json'));
        end

        function testEmptyInputIsRejected(testCase)
            % Empty text is not a usable path or extension.
            testCase.verifyError( ...
                @() nansen.util.path.changeFilenameExtension('', '.json'), ...
                'MATLAB:validators:mustBeNonempty');
            testCase.verifyError( ...
                @() nansen.util.path.changeFilenameExtension('settings.mat', ''), ...
                'MATLAB:validators:mustBeNonempty');
        end

        % ----------------------------------------------------------------
        % stripTrailingSeparator
        % ----------------------------------------------------------------

        function testTrailingSeparatorsAreRemoved(testCase)
            % Every trailing separator goes, so equal folders compare equal.
            folderPath = fullfile(filesep, 'data', 'projects');

            actual = nansen.util.path.stripTrailingSeparator( ...
                [folderPath, filesep, filesep]);

            testCase.verifyEqual(actual, folderPath);
        end

        function testRootKeepsItsSeparator(testCase)
            % A path consisting only of a separator is the root.
            actual = nansen.util.path.stripTrailingSeparator(filesep);

            testCase.verifyEqual(actual, filesep);
        end

        function testDriveRootKeepsItsSeparator(testCase)
            % Z: alone names the current folder on drive Z, not its root,
            % and isAbsolutePath rejects it.
            driveRoot = ['Z:', filesep];

            testCase.verifyEqual( ...
                nansen.util.path.stripTrailingSeparator(driveRoot), driveRoot);
            testCase.verifyEqual( ...
                nansen.util.path.stripTrailingSeparator([driveRoot, filesep]), driveRoot);
        end

        function testFolderOnDriveLosesItsSeparator(testCase)
            % Only the root of a drive keeps its separator.
            folderPath = ['Z:', filesep, 'data'];

            actual = nansen.util.path.stripTrailingSeparator([folderPath, filesep]);

            testCase.verifyEqual(actual, folderPath);
        end

        % ----------------------------------------------------------------
        % isSamePath
        % ----------------------------------------------------------------

        function testSamePathIgnoresTrailingSeparator(testCase)
            folderPath = fullfile(filesep, 'data', 'projects');

            testCase.verifyTrue( ...
                nansen.util.path.isSamePath(folderPath, [folderPath, filesep]));
        end

        function testDifferentPathsAreNotSame(testCase)
            testCase.verifyFalse(nansen.util.path.isSamePath( ...
                fullfile(filesep, 'data', 'a'), fullfile(filesep, 'data', 'b')));
        end

        function testSamePathCaseFollowsPlatform(testCase)
            % Default volumes on Windows and macOS do not distinguish case.
            folderPath = fullfile(filesep, 'Data', 'Projects');

            actual = nansen.util.path.isSamePath(folderPath, lower(folderPath));

            testCase.verifyEqual(actual, ispc || ismac);
        end

        % ----------------------------------------------------------------
        % isSubPath
        % ----------------------------------------------------------------

        function testPathInsideParentIsSubPath(testCase)
            parentPath = fullfile(filesep, 'data', 'proj');

            testCase.verifyTrue( ...
                nansen.util.path.isSubPath(fullfile(parentPath, 'a'), parentPath));
            testCase.verifyTrue( ...
                nansen.util.path.isSubPath(fullfile(parentPath, 'a'), [parentPath, filesep]));
        end

        function testParentIsNotInsideItself(testCase)
            parentPath = fullfile(filesep, 'data', 'proj');

            testCase.verifyFalse(nansen.util.path.isSubPath(parentPath, parentPath));
            testCase.verifyFalse( ...
                nansen.util.path.isSubPath([parentPath, filesep], parentPath));
        end

        function testSiblingWithParentPrefixIsNotSubPath(testCase)
            % "/data/project" starts with the characters of "/data/proj".
            testCase.verifyFalse(nansen.util.path.isSubPath( ...
                fullfile(filesep, 'data', 'project'), fullfile(filesep, 'data', 'proj')));
        end

        function testPathInsideRootIsSubPath(testCase)
            % The root keeps its separator, which must not be doubled.
            testCase.verifyTrue( ...
                nansen.util.path.isSubPath(fullfile(filesep, 'data'), filesep));
            testCase.verifyFalse(nansen.util.path.isSubPath(filesep, filesep));
        end

        function testPathInsideDriveRootIsSubPath(testCase)
            driveRoot = ['Z:', filesep];

            testCase.verifyTrue( ...
                nansen.util.path.isSubPath([driveRoot, 'data'], driveRoot));
        end

        function testSubPathCaseFollowsPlatform(testCase)
            parentPath = fullfile(filesep, 'Data', 'Proj');

            actual = nansen.util.path.isSubPath( ...
                fullfile(lower(parentPath), 'a'), parentPath);

            testCase.verifyEqual(actual, ispc || ismac);
        end
    end
end
