function name=module(package,mode)
% module : create a package module
%
% This function encapsulates a package directory into a module, simplifying
% function access without altering the MATLAB path.  To understand how
% modules are useful, consider the following multi-directory project.
%    ./main.m         % main routine
%    ./+GUI           % graphical user interface package (functions A, B, ...)
%    ./+GUI/+graphics % low level graphics package (functions 1, 2, ...)
% Package functions are normally accessed with a prefix:
%    [...]=GUI.functionA(...); % function A in GUI package
%    [...]=GUI.functionB(...); % function B in GUI package
%    [...]=GUI.graphics.function1(...); % function 1 in graphics sub-package
%    [...]=GUI.graphics.function2(...); % function 2 in graphics sub-package
% indicating where the function resides with respect to the top of the
% package (highest directory that starts with a '+').  Prefixes are fine
% for top-down access (though they can become quite long) and can be
% eliminated with MATLAB's "import" function, although importing a package
% can create name space confusion without warning.  The bigger problem is
% that prefixes are required for function calls at the same level.  For
% example, functionA must access functionB as 'GUI.functionB' (or import
% the GUI package); similiarly, function1 must access function2 as
% 'GUI.graphics.function2'.  This requirement makes it difficult to use
% standardized libraries in user-developed packages because intra-library
% calls must be modified manually.  Package tree revisions are particularly
% difficult, requiring manual corrections throughout the project.
%
% Modules avoid this unpleasantness by storing functions as handles inside
% a structure.  For example, the following code loads the GUI package into
% a module called 'local' for use in the main routine.
%     local=module('GUI'); % use this from functions in ./
%     [...]=local.functionA(...);
% Sub-packages can also be accessed.
%     local2=module('GUI.graphics');
%     [...]=local2.function1(...);
% Module definitions are location specific. The following code illustrates
% accessing the graphics package from inside the GUI package.
%     graphics=module('graphics'); % use this from functions in ./+GUI
%     [...]=graphics.function1(...);
% When no package is specified, the module is created where it is called.
% This permits function1 to access function2 without knowing anything about
% higher package levels.
%     name=module(); % access calling function's directory (*)
%     [...]=name.function2(...);
% This last example seems trivial, but MATLAB's implementation of packages
% breaks the traditional rule where functions can see other functions
% inside the same directory.
% (*) Modules defined without an explicit package name reference the lowest
% entry point of the package hierarchy, skipping class directories.
%
% Some upfront effort is needed to use modules, so it is recommended only
% for large projects.  Behind the scenes, modules are merely automatic
% constructions of the package prefix, and as such all features that
% support packages (such as classes) should work within modules.  Remember,
% modules are only valid as long as the top package is visible to MATLAB!
% In the preceeding examples, this means the directory containing 'main.m'
% and +GUI must be on the MATLAB path
%
% For situations where similar modules are constantly being created, such
% as graphical user interfaces, it *might* be worthwhile to create
% persistent modules:
%    function some_function(varargin)
%    persistent name
%    if isempty(name)
%       name=module;
%    end
% or use global modules where necessary (standard warnings apply).
% Finally, all calls to package functions should use parenthesis:
%    module_name.function_name(); % always use parenthesis!
% even if the underlying function has no inputs.  Omitting the parenthesis
% will return the function handle instead of evaluating the function.

% created September 3, 2012 by Daniel Dolan (Sandia National Laboratories)

% handle input
if (nargin<1)
    package='';
end

if (nargin<2) || isempty(mode)
    mode='quiet';
    %mode='verbose';
end

% default output
name=struct();

% determine where module is being defined
callstack=dbstack('-completenames');
if numel(callstack)==1
    start=pwd;
else
    start=callstack(2).file;
    start=fileparts(start); % strip off function name
end

% locate top package level
root={};
while numel(start)>0
    [temp,dirname]=fileparts(start);
    if dirname(1)=='+' % package directory
        start=temp;
        root{end+1}=dirname(2:end);
    elseif dirname(1)=='@' % back out of class directories
        start=temp;
    else
        break
    end
end

% Loop collects from end to beginning, so need to flip that list now.
root = fliplr(root);

root=sprintf('%s.',root{:});
package=[root package];
if isempty(package)
    error('ERROR: no package could be found');
elseif package(end)=='.'
    package=package(1:end-1);
end

% link package files to module
target=strrep(package,'.',[filesep '+']);
target=[filesep '+' target];
target=fullfile(start,target);
file=dir(target);
for n=1:numel(file)
    if file(n).isdir
        continue % ignore directories
    end
    [~,function_name,ext]=fileparts(file(n).name);
    if strcmpi(ext,'.m')  || strcmpi(ext,'.p')
        % do nothing
    else
        continue % ignore non-MATLAB files
    end
    name.(function_name)=str2func(sprintf('%s.%s',package,function_name));
end

if strcmpi(mode,'verbose')
    fprintf('Module created from the %s package, located in \n\t%s\n',...
        package,target);
end

end