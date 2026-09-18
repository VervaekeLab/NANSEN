classdef RemoteFileSourceFake < nansen.dataio.RemoteFileSource
%RemoteFileSourceFake - A source of online files that writes a known file instead of downloading
%
%   An empty file counts as online only. download writes a .mat file that
%   holds the variable OnlineData with the value DownloadedValue, so a test
%   can check that loading returns the downloaded content.

    properties (Constant)
        DownloadedValue = magic(3)
    end

    methods
        function obj = RemoteFileSourceFake(rootPath)
            obj@nansen.dataio.RemoteFileSource(rootPath)
        end

        function tf = isOnlineOnly(~, filePath)
            fileInfo = dir(filePath);
            tf = fileInfo.bytes == 0;
        end

        function download(~, filePath)
            OnlineData = nansen.unittest.session.helper.RemoteFileSourceFake.DownloadedValue;
            save(filePath, 'OnlineData')
        end
    end
end
