classdef PathUtilTest < matlab.unittest.TestCase
    %PathUtilTest Unit tests for nansen.util.path utilities.
    %
    %   Covers changeFilenameExtension, which must replace only the
    %   extension of the file name and never alter folder names.
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
    end
end
