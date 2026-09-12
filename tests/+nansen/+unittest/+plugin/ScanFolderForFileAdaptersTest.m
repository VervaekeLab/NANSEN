classdef ScanFolderForFileAdaptersTest < matlab.unittest.TestCase
%ScanFolderForFileAdaptersTest Unit tests for scanFolderForFileAdapters
%
%   Covers nansen.plugin.fileadapter.internal.scanFolderForFileAdapters,
%   which decides what the "Import File Adapter > From Folder" action copies
%   into a project. It must handle both a folder holding several adapters
%   and a folder that is itself a single adapter.
%
%   The scanner only tests whether the files that identify an adapter exist,
%   so the fixtures below create empty files.
%
%   Run tests:
%       runtests('nansen.unittest.plugin.ScanFolderForFileAdaptersTest')

    methods (Access = private)

        function items = scanFolder(~, folderPath)
        %scanFolder Call the function under test
            items = nansen.plugin.fileadapter.internal.scanFolderForFileAdapters(folderPath);
        end

        function rootPath = createRootFolder(testCase)
        %createRootFolder Make an empty temporary folder to build fixtures in
            import matlab.unittest.fixtures.TemporaryFolderFixture

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            rootPath = char(fixture.Folder);
        end

        function folderPath = createFolder(testCase, parentPath, folderName)
        %createFolder Make a subfolder and assert it was created
            folderPath = fullfile(parentPath, folderName);
            mkdir(folderPath)
            testCase.assertTrue(isfolder(folderPath))
        end

        function filePath = createFile(testCase, folderPath, fileName)
        %createFile Make an empty file and assert it was created
            filePath = fullfile(folderPath, fileName);
            fileId = fopen(filePath, 'w');
            testCase.assertNotEqual(fileId, -1, ...
                sprintf('Could not create fixture file "%s"', filePath))
            fclose(fileId);
        end

        function folderPath = createClassFolder(testCase, parentPath, className, methodFileNames)
        %createClassFolder Make a class folder holding a classdef file
        %
        %   methodFileNames names the method files to place beside the
        %   classdef file. Pass an empty cell array for a class that defines
        %   its methods inside the classdef file.
            folderPath = testCase.createFolder(parentPath, ['@', className]);
            testCase.createFile(folderPath, [className, '.m']);
            for i = 1:numel(methodFileNames)
                testCase.createFile(folderPath, methodFileNames{i});
            end
        end

        function verifySingleItem(testCase, items, expectedSourcePath, expectedDestName)
        %verifySingleItem Assert that exactly one adapter was found
            testCase.assertNumElements(items, 1)
            testCase.verifyEqual(items.sourcePath, expectedSourcePath)
            testCase.verifyEqual(items.destName, expectedDestName)
        end
    end

    methods (Test)

        % ----------------------------------------------------------------
        % A folder that is itself a single adapter
        % ----------------------------------------------------------------

        function testSelectedClassFolderIsImportedAsOneItem(testCase)
            % Regression: scanning into the selected class folder split it
            % into its individual m-files, so the classdef file was copied
            % into the project without its methods.
            rootPath = testCase.createRootFolder();
            classFolder = testCase.createClassFolder(rootPath, 'MyAdapter', {'read.m'});

            items = testCase.scanFolder(classFolder);

            testCase.verifySingleItem(items, classFolder, '@MyAdapter')
        end

        function testSelectedClassFolderWithoutMethodFilesIsImported(testCase)
            % A class may define its methods inside the classdef file, so
            % the class folder holds no read.m / write.m / view.m.
            rootPath = testCase.createRootFolder();
            classFolder = testCase.createClassFolder(rootPath, 'MyAdapter', {});

            items = testCase.scanFolder(classFolder);

            testCase.verifySingleItem(items, classFolder, '@MyAdapter')
        end

        function testSelectedFunctionAdapterFolderIsImportedAsOneItem(testCase)
            % The same applies to a function based adapter, identified by
            % its fileadapter.json rather than by a classdef file.
            rootPath = testCase.createRootFolder();
            adapterFolder = testCase.createFolder(rootPath, '+MatFile');
            testCase.createFile(adapterFolder, 'fileadapter.json');
            testCase.createFile(adapterFolder, 'read.m');

            items = testCase.scanFolder(adapterFolder);

            testCase.verifySingleItem(items, adapterFolder, '+MatFile')
        end

        function testTrailingFileSeparatorIsAccepted(testCase)
            % The destination name is derived from the folder name, which
            % must survive a path that ends with a file separator.
            rootPath = testCase.createRootFolder();
            classFolder = testCase.createClassFolder(rootPath, 'MyAdapter', {});

            items = testCase.scanFolder([classFolder, filesep]);

            testCase.assertNumElements(items, 1)
            testCase.verifyEqual(items.destName, '@MyAdapter')
        end

        % ----------------------------------------------------------------
        % A folder holding several adapters
        % ----------------------------------------------------------------

        function testClassFolderInScannedFolderIsFound(testCase)
            rootPath = testCase.createRootFolder();
            classFolder = testCase.createClassFolder(rootPath, 'MyAdapter', {'read.m'});

            items = testCase.scanFolder(rootPath);

            testCase.verifySingleItem(items, classFolder, '@MyAdapter')
        end

        function testClassFolderWithoutMethodFilesInScannedFolderIsFound(testCase)
            % Regression: a subfolder used to qualify only when it held
            % fileadapter.json or one of read.m / write.m / view.m, so a
            % class folder with its methods inside the classdef file was
            % skipped entirely.
            rootPath = testCase.createRootFolder();
            classFolder = testCase.createClassFolder(rootPath, 'MyAdapter', {});

            items = testCase.scanFolder(rootPath);

            testCase.verifySingleItem(items, classFolder, '@MyAdapter')
        end

        function testPackageFolderWithJsonKeepsItsPrefix(testCase)
            rootPath = testCase.createRootFolder();
            adapterFolder = testCase.createFolder(rootPath, '+MatFile');
            testCase.createFile(adapterFolder, 'fileadapter.json');

            items = testCase.scanFolder(rootPath);

            testCase.verifySingleItem(items, adapterFolder, '+MatFile')
        end

        function testUnprefixedFolderGetsPackagePrefix(testCase)
            % A plain folder name has to become a package folder to be
            % loadable from the project namespace.
            rootPath = testCase.createRootFolder();
            adapterFolder = testCase.createFolder(rootPath, 'MatFile');
            testCase.createFile(adapterFolder, 'read.m');

            items = testCase.scanFolder(rootPath);

            testCase.verifySingleItem(items, adapterFolder, '+MatFile')
        end

        function testLooseMFileIsFound(testCase)
            rootPath = testCase.createRootFolder();
            adapterFile = testCase.createFile(rootPath, 'LooseAdapter.m');

            items = testCase.scanFolder(rootPath);

            testCase.verifySingleItem(items, adapterFile, 'LooseAdapter.m')
        end

        function testAdaptersOfEveryKindAreFoundTogether(testCase)
            rootPath = testCase.createRootFolder();
            testCase.createClassFolder(rootPath, 'ClassWithMethodFiles', {'read.m'});
            testCase.createClassFolder(rootPath, 'ClassOnly', {});
            packageFolder = testCase.createFolder(rootPath, '+MatFile');
            testCase.createFile(packageFolder, 'fileadapter.json');
            testCase.createFile(rootPath, 'LooseAdapter.m');

            items = testCase.scanFolder(rootPath);

            testCase.verifyEqual(sort({items.destName}), ...
                {'+MatFile', '@ClassOnly', '@ClassWithMethodFiles', 'LooseAdapter.m'})
        end

        % ----------------------------------------------------------------
        % Entries that are not adapters
        % ----------------------------------------------------------------

        function testFolderWithoutAdapterFilesIsIgnored(testCase)
            % An ordinary folder of m-files is not an adapter, even though
            % it holds m-files that would qualify at the top level.
            rootPath = testCase.createRootFolder();
            notesFolder = testCase.createFolder(rootPath, 'notes');
            testCase.createFile(notesFolder, 'todo.m');

            items = testCase.scanFolder(rootPath);

            testCase.verifyEmpty(items)
        end

        function testClassFolderWithoutClassdefFileIsIgnored(testCase)
            % A class folder is only loadable together with the classdef
            % file that shares its name.
            rootPath = testCase.createRootFolder();
            classFolder = testCase.createFolder(rootPath, '@MyAdapter');
            testCase.createFile(classFolder, 'read.m');

            items = testCase.scanFolder(rootPath);

            testCase.verifyEmpty(items)
        end

        function testEmptyFolderYieldsNoItems(testCase)
            rootPath = testCase.createRootFolder();

            items = testCase.scanFolder(rootPath);

            testCase.verifyEmpty(items)
            testCase.verifyEqual(sort(fieldnames(items)), {'destName'; 'sourcePath'})
        end
    end
end
