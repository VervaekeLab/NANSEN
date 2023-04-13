classdef VersionedFile < handle


% Todo:
%   [ ] Create save and load method
%   [ ] Increase version number on save
%   [ ] Methods for determining if file content is dirty.
%       I.e a FileContent property where data is represented. Some issues
%       then when dealing with large data or data that should not be kept
%       in memory?
%   [ ] Resolve what to do if saving to an older version to an updated file
%   [ ] 

%   Questions:
%    - Subclass from a File class?

    properties (Abstract)
        Filepath
    end

    properties (Access = protected)
        VersionNumber
    end

        
    methods (Access = protected)

        function tf = isLatestVersion(obj)
            if isempty(obj.VersionNumber)
                tf = true; 
                return
            end

            S = load(obj.Filepath, 'VersionNumber');
            if isfield(S, 'VersionNumber')
                tf = S.VersionNumber == obj.VersionNumber;
            else
                tf = true;
            end
        end

        function tf = resolveCurrentVersion(obj)
                        
            titleStr = 'Newer version exists';

            msg = ['A newer version of this file exists. ' ...
                'What do you want to do?'];
            
            options = {'Load newer version and drop recent changes', ...
                'Overwrite newer version with this version' };

            answer = questdlg(msg, titleStr, options{:}, options{1});
            switch answer
                case 'Load newer version and drop recent changes'
                    tf = true;
                case 'Overwrite newer version with this version' 
                    tf = false;
            end
        end

    end

end