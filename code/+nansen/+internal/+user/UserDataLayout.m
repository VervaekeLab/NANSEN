classdef (Sealed) UserDataLayout
%UserDataLayout Version of the way a user data directory is organised
%
%   CURRENT_VERSION identifies the layout that this code reads and writes.
%   Increase it when a change moves or renames anything in the user data
%   directory.
%
%   A session stores the version in the file user_data_layout_version.txt
%   in the user data directory once it has moved the data there. The file
%   holds the number on its first line. A directory without the file has
%   not been set up by a session.
%
%   A running session compares CURRENT_VERSION with the value it started
%   with. They differ when the code was updated while the session was
%   running, because MATLAB applies a changed class file to objects that
%   already exist.
%
%   UserDataLayout methods:
%       getFilePath - Path of the version file in a user data directory
%       read        - Layout version stored in a user data directory
%       write       - Store the current layout version in a user data directory
%       remove      - Remove the version file from a user data directory
%
%   See also nansen.internal.user.NansenUserSession/getCurrentUserDataDirectory,
%   nansen.internal.user.migrateUserDataFolders

    properties (Constant)
        FILENAME = "user_data_layout_version.txt"
        CURRENT_VERSION = 1
    end

    methods (Access = private)
        function obj = UserDataLayout()
        %UserDataLayout Not used; the class only groups static methods
        end
    end

    methods (Static)

        function filePath = getFilePath(userDataDirectory)
        %getFilePath Path of the version file in a user data directory

            arguments
                userDataDirectory (1,1) string
            end

            filePath = fullfile(userDataDirectory, ...
                nansen.internal.user.UserDataLayout.FILENAME);
        end

        function layoutVersion = read(userDataDirectory)
        %read Layout version stored in a user data directory
        %
        %   layoutVersion = read(userDataDirectory) returns the number on
        %   the first line of the version file, or 0 when there is no file
        %   or that line is not a number.

            arguments
                userDataDirectory (1,1) string
            end

            layoutVersion = 0;

            filePath = nansen.internal.user.UserDataLayout.getFilePath(userDataDirectory);
            if ~isfile(filePath); return; end

            lines = readlines(filePath, "EmptyLineRule", "skip");
            if ~isempty(lines) && ~isnan(str2double(lines(1)))
                layoutVersion = str2double(lines(1));
            end
        end

        function write(userDataDirectory)
        %write Store the current layout version in a user data directory

            arguments
                userDataDirectory (1,1) string
            end

            import nansen.internal.user.UserDataLayout

            writelines(string(UserDataLayout.CURRENT_VERSION), ...
                UserDataLayout.getFilePath(userDataDirectory))
        end

        function remove(userDataDirectory)
        %remove Remove the version file from a user data directory

            arguments
                userDataDirectory (1,1) string
            end

            filePath = nansen.internal.user.UserDataLayout.getFilePath(userDataDirectory);
            if isfile(filePath)
                delete(filePath)
            end
        end
    end
end
