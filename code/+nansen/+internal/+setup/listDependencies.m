function dependencies = listDependencies(flag)
%listDependencies - List the dependencies for NANSEN
    
    % if nargin < 1; flag = 'required'; end
    % flag = validatestring(flag, {'required', 'all'}, 1);

    rootPath = fullfile(nansen.rootpath, 'code', 'resources', 'dependencies');
    jsonStr = fileread( fullfile(rootPath, 'fex_submissions.json') );
    
    dependencies = struct2table( jsondecode(jsonStr) );
end