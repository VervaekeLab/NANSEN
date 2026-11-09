classdef (Sealed) UserDataLayout
%UserDataLayout Version of the way a user data directory is organised
%
%   CURRENT_VERSION identifies the layout that this code reads and writes.
%   A change that moves or renames anything in the user data directory adds
%   a step to getMigrationSteps and sets CURRENT_VERSION to its Version.
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
%       getFilePath       - Path of the version file in a user data directory
%       read              - Layout version stored in a user data directory
%       write             - Store a layout version in a user data directory
%       remove            - Remove the version file from a user data directory
%       assertSupported   - Check that this code can work with a directory
%       getMigrationSteps - Steps that bring an older directory up to date
%
%   See also nansen.internal.user.NansenUserSession/getCurrentUserDataDirectory,
%   nansen.internal.user.migrateUserDataFolders,
%   nansen.internal.migration.applyMigrationSteps

    properties (Constant)
        FILENAME = "user_data_layout_version.txt"

        % FIRST_VERSION - Layout that moving the data out of MATLAB's
        % preference directory produces. A directory without a version file
        % holds this layout.
        FIRST_VERSION = 1

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

        function write(userDataDirectory, layoutVersion)
        %write Store a layout version in a user data directory
        %
        %   write(userDataDirectory) stores CURRENT_VERSION.
        %
        %   write(userDataDirectory, layoutVersion) stores layoutVersion.

            arguments
                userDataDirectory (1,1) string
                layoutVersion (1,1) double = nansen.internal.user.UserDataLayout.CURRENT_VERSION
            end

            writelines(string(layoutVersion), ...
                nansen.internal.user.UserDataLayout.getFilePath(userDataDirectory))
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

        function assertSupported(userDataDirectory)
        %assertSupported Check that this code can work with a user data directory
        %
        %   Throws NANSEN:UserSession:UserDataLayoutNewer when a newer
        %   version of NANSEN organised the directory, because this code
        %   would look for files in the wrong places and could write over
        %   data that it does not recognise.

            arguments
                userDataDirectory (1,1) string
            end

            import nansen.internal.user.UserDataLayout

            storedVersion = UserDataLayout.read(userDataDirectory);

            if storedVersion > UserDataLayout.CURRENT_VERSION
                error('NANSEN:UserSession:UserDataLayoutNewer', ...
                    ['A newer version of NANSEN organised the data in "%s" ' ...
                     '(layout %d, and this version handles up to layout %d). ' ...
                     'Update NANSEN and start it again.'], ...
                    userDataDirectory, storedVersion, UserDataLayout.CURRENT_VERSION)
            end
        end

        function steps = getMigrationSteps(userDataDirectory) %#ok<INUSD>
        %getMigrationSteps Steps that bring an older user data directory up to date
        %
        %   steps = getMigrationSteps(userDataDirectory) returns the steps
        %   for that directory, in the form that
        %   nansen.internal.migration.applyMigrationSteps takes. The first
        %   step has Version FIRST_VERSION + 1, and the last one has
        %   Version CURRENT_VERSION.

            steps = struct('Version', {}, 'Description', {}, 'Apply', {});
        end
    end
end
