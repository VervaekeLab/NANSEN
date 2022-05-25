% Add flowreg folders to path and run the make script.

flowregdir = fileparts( which('set_path') );
[~, dirname] = fileparts(flowregdir);

assert( strcmp(dirname, 'flow_registration'), ...
    'Could not located the directory containing the flow_registration toolbox')

addpath(fullfile(flowregdir, 'core'));
addpath(fullfile(flowregdir, 'util'));
addpath(fullfile(flowregdir, 'util', 'io'));

try
    run(fullfile(flowregdir, 'core', 'make.m'));

catch ME
    switch ME.identifier
        case 'MATLAB:mex:NoCompilerFound_link_Win64'
            minGwLink = 'https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/submissions/52848/versions/22/download/mlpkginstall';
                        
            % Download the file containing the mingw addon
            tempFilepath = [tempname, '.mlpkginstall'];
            tempFilepath = websave(tempFilepath, minGwLink);            
            matlab.addons.install(tempFilepath);
            delete(tempFilepath) 
            
            run(fullfile(flowregdir, 'core', 'make.m'));
    end
end