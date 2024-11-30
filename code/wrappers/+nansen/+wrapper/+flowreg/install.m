% Add flowreg folders to path and run the make script.

flowregdir = fileparts( which('set_path') );
[~, dirname] = fileparts(flowregdir);

assert( strcmp(dirname, 'flow_registration'), ...
    'Could not locate the directory containing the flow_registration toolbox')

addpath(fullfile(flowregdir, 'core'));
addpath(fullfile(flowregdir, 'util'));
addpath(fullfile(flowregdir, 'util', 'io'));

run(fullfile(flowregdir, 'core', 'make.m'));
