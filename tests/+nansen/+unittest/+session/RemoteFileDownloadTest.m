classdef RemoteFileDownloadTest < matlab.unittest.TestCase
%RemoteFileDownloadTest - Tests for loading data files that are stored online
%
%   The mock project gets the variable OnlineData, whose file in the first
%   session is an empty placeholder. The project preference
%   RemoteFileSource names RemoteFileSourceFake, which counts empty files
%   as online and downloads by writing a known .mat file.
%
%   Run tests:
%       runtests('nansen.unittest.session.RemoteFileDownloadTest')

    properties (Constant)
        VariableName = 'OnlineData'
        SourceClassName = 'nansen.unittest.session.helper.RemoteFileSourceFake'
    end

    properties
        Project
        Session
        FilePath char
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
            testCase.Project = nansen.getCurrentProject();

            % The new item copies the fields of the mock project's item,
            % which has fields that a default item lacks, and the model
            % holds its items in one struct array
            variableModel = testCase.Project.VariableModel;
            item = variableModel.Data(1);
            item.VariableName = testCase.VariableName;
            item.Uuid = nansen.util.getuuid();
            item.DataLocation = 'MockData';
            item.FilePathPattern = '';
            item.FileNameExpression = 'online_data';
            item.FileType = '.mat';
            item.FileAdapter = 'Default';
            variableModel.insertItem(item);
            variableModel.save()

            sessionTable = testCase.Project.MetaTableCatalog.getMasterMetaTable('session');
            % The models are passed as the app passes them
            testCase.Session = sessionTable.getMetaObjects(1, ...
                'DataLocationModel', testCase.Project.DataLocationModel, ...
                'VariableModel', variableModel);
            testCase.FilePath = fullfile(testCase.Session.getSessionFolder('MockData'), ...
                'online_data.mat');
        end
    end

    methods (TestMethodSetup)
        function createPlaceholder(testCase)
            fclose(fopen(testCase.FilePath, 'w'));
        end

        function removeSourceAfterTest(testCase)
            testCase.addTeardown(@() testCase.Project.setRemoteFileSource(""))
            testCase.addTeardown(@() testCase.Project.setAutoDownloadRemoteFiles(false))
        end
    end

    methods (Test)
        function testLoadDataDownloadsWhenAutoDownloadIsOn(testCase)
            testCase.setSourcePreferences(true)

            data = testCase.Session.loadData(testCase.VariableName);

            testCase.verifyEqual(data, nansen.unittest.session.helper.RemoteFileSourceFake.DownloadedValue)
        end

        function testLoadDataErrorsWhenAutoDownloadIsOff(testCase)
            testCase.setSourcePreferences(false)

            testCase.verifyError(@() testCase.Session.loadData(testCase.VariableName), ...
                'NANSEN:Session:FileIsOnlineOnly')
            fileInfo = dir(testCase.FilePath);
            testCase.verifyEqual(fileInfo.bytes, 0)
        end

        function testDownloadDataFileDownloadsPlaceholder(testCase)
            testCase.setSourcePreferences(false)

            testCase.Session.downloadDataFile(testCase.VariableName)

            data = testCase.Session.loadData(testCase.VariableName);
            testCase.verifyEqual(data, nansen.unittest.session.helper.RemoteFileSourceFake.DownloadedValue)
        end

        function testLoadDataWithoutSourceReportsEmptyFile(testCase)
            % A project without a source treats an empty file as before
            testCase.verifyError(@() testCase.Session.loadData(testCase.VariableName), ...
                'NANSEN:Session:EmptyFile')
        end

        function testDownloadDataFileWithoutSourceErrors(testCase)
            testCase.verifyError(@() testCase.Session.downloadDataFile(testCase.VariableName), ...
                'NANSEN:Session:NoRemoteFileSource')
        end

        function testSetRemoteFileSourceRejectsOtherClass(testCase)
            testCase.verifyError(@() testCase.Project.setRemoteFileSource("nansen.metadata.type.Session"), ...
                'NANSEN:Project:InvalidRemoteFileSource')
        end
    end

    methods (Access = private)
        function setSourcePreferences(testCase, isAutoDownload)
            testCase.Project.setRemoteFileSource(testCase.SourceClassName)
            testCase.Project.setAutoDownloadRemoteFiles(isAutoDownload)
        end
    end
end
