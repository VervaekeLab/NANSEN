classdef VersionedFileTest < matlab.unittest.TestCase
%VersionedFileTest Unit tests for the files written by VersionedFile.save
%
%   Run tests:
%       runtests('nansen.unittest.metadata.VersionedFileTest')

    properties
        TestFolder (1,1) string
        TargetPath (1,1) string
        TempPath (1,1) string
        BackupPath (1,1) string
    end

    methods (TestMethodSetup)
        function createTestFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            folderFixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.TestFolder = folderFixture.Folder;
            testCase.TargetPath = fullfile(testCase.TestFolder, "table.mat");
            testCase.TempPath = fullfile(testCase.TestFolder, "table.tempsave.mat");
            testCase.BackupPath = fullfile(testCase.TestFolder, "table.backup.mat");
        end
    end

    methods (Test)
        function testSuccessfulSaveLeavesBackupAndNoTempFile(testCase)
            file = nansen.unittest.metadata.helper.VersionedFileFake(testCase.TargetPath);
            file.Data = 1;

            wasSaved = file.save();

            testCase.verifyTrue(wasSaved);
            testCase.verifyTrue(isfile(testCase.TargetPath));
            testCase.verifyTrue(isfile(testCase.BackupPath));
            testCase.verifyFalse(isfile(testCase.TempPath));
            testCase.verifyEqual(load(testCase.BackupPath), load(testCase.TargetPath));
        end

        function testSecondSaveReplacesBackup(testCase)
            file = nansen.unittest.metadata.helper.VersionedFileFake(testCase.TargetPath);
            file.Data = 1;
            file.save();

            file.Data = 2;
            file.save(true);

            backup = load(testCase.BackupPath);
            testCase.verifyEqual(backup.Data, 2);
            testCase.verifyEqual(backup.VersionNumber, int64(2));
            testCase.verifyFalse(isfile(testCase.TempPath));
        end

        function testReadOnlyBackupIsReplaced(testCase)
            file = nansen.unittest.metadata.helper.VersionedFileFake(testCase.TargetPath);
            file.Data = 1;
            file.save();
            testCase.makeReadOnly(testCase.BackupPath);

            file.Data = 2;
            testCase.verifyWarningFree(@() file.save(true));

            backup = load(testCase.BackupPath);
            testCase.verifyEqual(backup.Data, 2);
        end

        function testFolderNameContainingMat(testCase)
            folderPath = fullfile(testCase.TestFolder, "tables.mat.archive");
            mkdir(folderPath)

            testCase.verifySaveWritesBesideTarget(folderPath, "table");
        end

        function testFileNameContainingMat(testCase)
            testCase.verifySaveWritesBesideTarget(testCase.TestFolder, "table.matrix");
        end

        function testSuccessfulSaveConsumesLeftoverTempFile(testCase)
            leftoverValue = 99;
            save(testCase.TempPath, "leftoverValue")
            file = nansen.unittest.metadata.helper.VersionedFileFake(testCase.TargetPath);
            file.Data = 1;

            file.save();

            testCase.verifyFalse(isfile(testCase.TempPath));
            backup = load(testCase.BackupPath);
            testCase.verifyEqual(backup.Data, 1);
            testCase.verifyFalse(isfield(backup, "leftoverValue"));
        end

        function testFailedCopyKeepsTempFileAndReportsIt(testCase)
            file = nansen.unittest.metadata.helper.VersionedFileFake(testCase.TargetPath);
            file.Data = 1;
            file.save();

            % copyfile without its "f" option does not replace a read-only file
            testCase.makeReadOnly(testCase.TargetPath);
            file.Data = 2;

            try
                file.save(true);
                testCase.verifyFail("Expected the save to fail on the read-only target file.");
            catch ME
                testCase.verifyEqual(ME.identifier, 'NANSEN:VersionedFile:SaveFailed');
                testCase.verifySubstring(string(ME.message), testCase.TempPath);
            end

            tempFile = load(testCase.TempPath);
            testCase.verifyEqual(tempFile.Data, 2);
            backup = load(testCase.BackupPath);
            testCase.verifyEqual(backup.Data, 1);
        end

        function testFailedRenameWarnsAndReportsSuccessfulSave(testCase)
            file = nansen.unittest.metadata.helper.VersionedFileFake(testCase.TargetPath);
            file.Data = 1;
            file.AfterMarkClean = @() delete(testCase.TempPath);

            wasSaved = testCase.verifyWarning(@() file.save(), ...
                "NANSEN:VersionedFile:BackupNotUpdated");

            testCase.verifyTrue(wasSaved);
            testCase.verifyTrue(file.isClean());
            target = load(testCase.TargetPath);
            testCase.verifyEqual(target.Data, 1);
        end
    end

    methods (Access = private)
        function makeReadOnly(testCase, filePath)
            fileattrib(filePath, "-w");
            testCase.addTeardown(@() fileattrib(filePath, "+w"));
        end

        function verifySaveWritesBesideTarget(testCase, folderPath, fileName)
            targetPath = fullfile(folderPath, fileName + ".mat");
            file = nansen.unittest.metadata.helper.VersionedFileFake(targetPath);

            file.save();

            testCase.verifyTrue(isfile(targetPath));
            testCase.verifyTrue(isfile(fullfile(folderPath, fileName + ".backup.mat")));
            testCase.verifyFalse(isfile(fullfile(folderPath, fileName + ".tempsave.mat")));
        end
    end
end
