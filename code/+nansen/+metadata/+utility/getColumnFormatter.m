function [formatterFcnHandle, varNames] = getColumnFormatter(varNames, tableClass, scope)
%getColumnFormatter Get function handle for table column formatter/renderer
%
%   formatterFcnHandle = getColumnFormatter() return function
%   handles for all available column formatters. 
%
%   formatterFcnHandle = getColumnFormatter(varNames) return function
%   handles for all column formatters that match the given list of variable 
%   names (varNames).
%
%   formatterFcnHandle = getColumnFormatter(varNames, tableClass, scope) 
%   looks in the specified scope. Scope can be 'builtin' (for nansen 
%   builtin table variables), 'project' (for current project). Default is 
%   to look in both scopes. The project scope takes precedence over the 
%   builtin scope, so if a column formatter exists both in the builtins
%   and in the project, the project's column formatter is returned.
% 
%   A column formatter is any class that inherits from the 
%   nansen.metadata.abstract.TableVariable class
    

% Todo. Turn this into an enumeration class similar to
% uiw.enum.TableColumnFormat?
% Right now this is constantly being triggered on mouseover. Should only
% have to be called if table changes...


    % Set default variables.
    if nargin < 1 || isempty(varNames); varNames = {}; end
    if nargin < 2 || isempty(tableClass); tableClass = 'session'; end
    if nargin < 3 || isempty(scope); scope = {'project', 'builtin'}; end
    
    if ~isa(scope, 'cell'); scope = {scope}; end

    rootFolderPath = cell(size(scope));

    % Get root paths for scopes.
    for i = 1:numel(scope)
        switch scope{i}
            case 'builtin'
                rootFolderPath{i} = fullfile(nansen.rootpath, '+metadata', '+tablevar');
            case 'project'
                projPath = nansen.localpath('Custom Metatable Variable', 'current');
                rootFolderPath{i} = fullfile(projPath, ['+', lower(tableClass)]);
        end
    end
          
    % All builtin tablevars is in one folder. Keep following in case this 
    % will be changed in a future update...
    %rootFolderPath = fullfile(rootFolderPath, ['+', lower(tableClass)]);
    
    % List .m files in these folders
    [mFiles, fileNames] = utility.path.listFiles(rootFolderPath, '.m');
    fileNames = strrep(fileNames, '.m', ''); % Remove file extension
    
    % Filter by variable names
    if ~isempty(varNames)
        [fileNames, iA] = intersect(fileNames, varNames, 'stable');
        mFiles = mFiles(iA);
    end

    % Remove duplicates
    [fileNames, iA] = unique(fileNames, 'stable');
    mFiles =  mFiles(iA);

    % Build function handles
    fcnNames = cellfun(@utility.path.abspath2funcname, mFiles, 'uni', 0);
    fcnHandles = cellfun(@str2func, fcnNames, 'uni', 0);

    % Check if .m files contain class derived from nansen.metadata.abstract.TableVariable
    isValid = false(size(fcnHandles));
    for i = 1:numel(fcnHandles)
        fcnResult = fcnHandles{i}();
        isValid(i) = isa(fcnResult, 'nansen.metadata.abstract.TableColumnFormatter');
    end

    formatterFcnHandle = fcnHandles(isValid);
    if nargout == 2
        varNames = fileNames(isValid);
    else
        clear varNames
    end
end


% %     for i = 1:numel(fcnHandles)
% %         mc = meta.class.fromName(fcnNames{i});
% %         if ~isempty(mc)
% %             isValid(i) = any( strcmp({mc.SuperclassList.Name},  'nansen.metadata.abstract.TableVariable' ));
% %         end
% %     end
