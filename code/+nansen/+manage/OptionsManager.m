classdef OptionsManager < handle
%nansen.manage.OptionsManager Class for managing toolbox options.
% 
%   This class provides an interface for storing and retrieving preset 
%   options for algorithms and methods that are part of the nansen package.
%
%   This class can be used in combination with any function or class
%   that requires a set of options/parameters to run, but there are some
%   special ways to implement a function or a class to provide increased
%   functionality. These are described in the examples (2 & 3) below.
%
%   Options presets are saved to the directory which is returned by
%   calling "nansen.localpath('custom_options')". See nansen.localpath for
%   instructions on how to change this path.
%
%   USAGE: 
%       optManager = nansen.manage.OptionsManager(fcnName, defOpts)
%          creates an options manager object for the function with the
%          specified function name (fcnName) and set of default options 
%          (defOptions).
%
%       optsA = optManager.getOptions('my_options_1')
%       optsB = optManager.getOptions('my_options_2')
%
%       optsC = optsB; 
%       optsC.someParameter = newValue;
%
%       optManager.setOptions(optsC, 'my_options_3')
%
%   INPUTS:
%       fcnName (char) : Name of function (if the function is part of a 
%           package, the full package name must be included).
%       defOpts (struct) : A struct containing options. Fieldnames specify
%           the options/parameter names. The struct can have two levels, 
%           see structEditor.App for more info. 
%           
%   EXAMPLES:
%       1) The simplest use case is to create an options manager for any
%          existing function or class. Note: The first time the options
%          manager is created, a set of options must also be given. On
%          subsequent use, if options are not given, they are selected from
%          the stored options file.
%   
%       2) A function can be created to have default options. Any function
%          that returns a struct of options when called with no inputs is
%          considered a method which has default options in the context of
%          the options manager (See ... for example). 
%
%       3) Any subclass that implements the nansen.mixin.HasOptions class
%          also has a set of default options which are detected by the
%          options manager. 
%
%   OUTPUT:
%       The options manager object contains the following properties
%       
%       FunctionName: Name of function for the current options manager instance 
%       Options : The set of options which are currently selected
%       OptionsName : The name of the currently selected name of options


  
%     A preset option is a set of options that are defined in a special
%     class.
%     A custom option is a set of options that are saved to a predefined
%     file location
%     A modified option is a set of options that are modified from one of
%     the above. This option type is only stored in this class in a
%     transient manner.
    
        
    % TODO:
    %  *[ ] Make this more intuitive! I.e whats difference between default,
    %       preset and custom...? When to use what?
    %
    %  *[ ] Are original options saved at all??? No. => They should be...
    %  *[ ] If options are saved for the first time, tag the original as
    %       default...
    %   [ ] Add a star (*) next to default options in the list of names... 
    %   [x] Add function for sticking a preset tab onto the options struct.
    %   [x] Add callback for handling ui changes on the preset tab.
    %
    %   [v] Add transient custom options (modified) (i.e if user edits some options)
    %   [v] Options should have a name, description and date.
    %
    %   [ ] Use method for editing settings externally. Improve method? I.e
    %       is it straight forward to use it w.r.t different presets?
    %   [ ] Make sure correct preset is selected from the list (when
    %       editing presets)
    %   [ ] Tag presets with default and factory (or something similar).
    %       I.e default is the one which is used by default whereas factory
    %       is the one which is preconfigured, or initial. Really dont know
    %       how to find best names for these two cases, both feel like
    %       default...
    %   [ ] Method (gui) for inspecting and removing presets
    %   [ ] createCustomOptionsFilePath should be static.

    
    properties (SetAccess = private)
        FunctionName char       % Name of function (or class) 
        Options struct          % Current set of options
        OptionsName char        % Name of current set of options
    end
    
%     Todo
%     properties (Hidden)
%         CurrentOptionSelection        
%     end
    
    properties (Hidden)
        FilePath        
    end

    properties (Dependent) % Available options names
        % These properties are dependent in order for them to be updated
        % from file whenever they are accessed.
        PresetOptionNames       % Names of available preset options (created by developer)
        CustomOptionNames       % Names of available preset options (created by user)
    end 
    
    properties (Access = private, Hidden)
        FunctionType               % Type of function (see examples 1-3)
        HasPresets = false         % Boolean flag, does preset options exist for this function/method?
        PresetOptionsDirectoryPath % Path to directory containing preset options
        CustomOptionsFilePath      % Filepath where custom options as saved
    end
    
    properties (Access = private, Hidden)
        PresetOptionNames_
        PresetOptions_
        
        CustomOptionNames_
        CustomOptions_
        
        ModdedOptionNames_ = {} % Transient options (These are never saved)
        ModdedOptions_ = {}
    end
    
    events
        OptionsChanged % Is this needed / will I have use for this????
    end
    
    methods % Structor
        
        function obj = OptionsManager(fcnName, opts, optsName)
        %OptionsManager Constructor of options manager
        %
        %   h = OptionsManager(functionName) creates a options manager
        %     instance for a function specified by functionName. 
        %
        %   h = OptionsManager(functionName, opts) creates a options 
        %     manager instance and assigns a set of options. 
        %        
        %   h = OptionsManager(functionName, opts, optsName) creates an 
        %     options manager with a set of options with a custom name. 
        
        %   First, the constructor checks if an options file exists for a
        %   function of the given name. If yes, it collects info about
        %   which option presets are available. 
        %
        %   If no options file exists, the constructor checks if the given
        %   function exists, and then checks if default options exist for
        %   the function.
        

            % Return a blank instance if no input arguments are given.
            if ~nargin
                return
            end
        
            
            % Assign the function name 
            obj.FunctionName = fcnName;
            obj.assignFilePath()
            
            % Determine what type of function is provided (ref examples)
            obj.FunctionType = obj.getFunctionType(fcnName);
            
            % Assign options and options name if they are provided.
            if nargin >= 2 && ~isempty(opts)
                obj.Options = opts;
            end
            
            if nargin == 3 && ~isempty(optsName)
                obj.OptionsName = optsName;
            else
                obj.OptionsName = 'Default';
            end
            
            
            % Check if options file exists for the given function
            if isfile(obj.FilePath)
                if isempty(obj.Options)
                    obj.getDefaultOptions()
                else
                    % Check if provided options already exist...
                    if obj.hasOptions(obj.OptionsName)
                        %warning('This option preset already exists, retrieving existing preset')
                        obj.getOptions(obj.OptionsName)
                        
                    % Save custom options to file
                    else
                        obj.saveCustomOptions(obj.Options, obj.OptionsName, false)
                    end
                    
                end
            else
                obj.initializeOptionPresetFile()
            end

            % Todo: This needs more work. I.e need to combine presets with
            % options inherited from superclasses....!
            %obj.checkForPresetOptions()
            
        end
        
    end
    
    methods (Access = public)
        
        function [S, optionsName] = getOptions(obj, optionsName)
            
            if nargin < 2 || isempty(optionsName)
                optionsName = obj.getDefaultOptionsName();
            end
            
            if isempty(optionsName) || strcmp(optionsName, 'Original')
                S = obj.Options();
                
            elseif obj.isPreset(optionsName)
                S = obj.getPresetOptions(optionsName);
                
            elseif obj.isCustom(optionsName)
                S = obj.loadCustomOptions(optionsName);
                     
            elseif obj.isModified(optionsName)
                S = obj.getModifiedOptions(optionsName);
            end
            
            if nargout == 0
                obj.Options = S;
                obj.OptionsName = optionsName;
                clear S optionsName
            elseif nargout == 1
                clear optionsName
            end
            
        end
        
        function setOptions(obj, options, optionsName)
            
        end
        
    end
    
    
    methods (Access = public)
        
        function edit(obj)

            name = strsplit(obj.FunctionName, '.');
            
            if numel(name) > 2
                name = name(end-1:end);
                name = ['...', strjoin(name, '.')];
            else
                name = obj.FunctionName;
            end
            
            
            sEditor = structeditor(obj.Options, 'OptionsManager', obj, 'Title', name);
            sEditor.waitfor()

            if sEditor.wasCanceled
                obj.Options = sEditor.dataOrig;
            else
                obj.Options = sEditor.dataEdit;
            end
            
            delete(sEditor)
            
        end
        
        function [optsName, optsStruct] = editOptions(obj, optsName, optsStruct)
                           
            if nargin < 2
                optsName = obj.getDefaultOptionsName();
                if ~isempty(optsName)
                    optsStruct = obj.getOptions(optsName);
                else
                    optsName = obj.listPresetOptions();
                    optsStruct = obj.getOptions(optsName);
                end
            elseif nargin == 2
                optsStruct = obj.getOptions(optsName);
            end
            
            sEditor = structeditor(optsStruct, 'OptionsManager', obj);
            sEditor.setPresetDropdownValueToName(optsName);
            
            sEditor.waitfor()

            if sEditor.wasCanceled
                optsStruct = sEditor.dataOrig;
            else
                optsStruct = sEditor.dataEdit;
            end
            
            optsName = sEditor.currentPresetName;
            
            if nargout == 1
                clear optsStruct
            elseif nargout == 0
                clear optsStruct optsName
            end
            
        end

        function S = getDefaultOptions(obj)
            
            defaultName = obj.getDefaultOptionsName();
            S = obj.getOptions(defaultName);
            
            if ~nargout
                obj.Options = S;
                obj.OptionsName = defaultName;
                clear S
            end
            
        end
        
        function setDefault(obj, optionsName)
        %setDefault Set (flag) options with given name as default
            
            DefaultOptionsName = optionsName;
            if isfile(obj.FilePath)
                save(obj.FilePath, 'DefaultOptionsName', '-append')
            else
                save(obj.FilePath, 'DefaultOptionsName')
            end
            
        end
        
      % % Methods for dealing with custom options.
       
        function [name, descr] = getCustomOptionsName(obj)
            
            dlgTitle =  'Save Options As';
            dlgPrompt = {'Please enter name for saving custom options', ...
                'Please enter description (optional)'};
            dims = [1,45; 2,41];

            finished = false;
            
            while ~finished
                answer = inputdlg(dlgPrompt, dlgTitle, dims);
                
                if isempty(answer)
                    name = '';
                    descr = '';
                    finished = true;
                else
                    name = answer{1};
                    descr = answer{2};
                    finished = true;
% %                 else
% %                     h = msgbox('Name must be a valid variable name');
% %                     uiwait(h)
                end
            end
            
        end
        
        function givenName = saveCustomOptions(obj, opts, name, isDefault)
            
            % For external functions to know which name was given during saving
            givenName = ''; % Nothing is saved yet
            
            if nargin < 2
                opts = obj.Options;
            end
            
            if nargin < 3
                [name, descr] = obj.getCustomOptionsName();
            else
                descr = '';
            end
            
            if nargin < 4
                isDefault = false;
            end
            
            if isempty(name); return; end
                        
            % Todo: Test that name does not exist already
            if obj.isPreset(name) || obj.isCustom(name)
                errordlg('This name is already in use')
                return
            end
            
            % Get filepath
            savePath = obj.FilePath;
            
            % Create struct object for custom options
            t = now();
            customOpts = struct();
            customOpts.Name = name;
            customOpts.Description = descr;
            customOpts.Options = opts;
            customOpts.DateCreatedNum = t;
            customOpts.DateCreated = datestr(t, 'yyyy.mm.dd - HH:MM:SS');
            
            if isfile(savePath)
                S = load(savePath);
                S.CustomOptions(end+1) = customOpts;
                save(savePath, '-struct', 'S', '-append')
            else
                S.CustomOptions = customOpts;
                save(savePath, '-struct', 'S')
                DefaultOptionsName = name;
                save(savePath, 'DefaultOptionsName', '-append')
            end
            
            givenName = name;

% %             S.(name) = opts;
% %             
% %             % Save with variable names...
% %             if isfile(savePath)
% %                 save(savePath, '-struct', 'S', '-append')
% %             else
% %                 save(savePath, '-struct', 'S')
% %             end
            
            if isDefault
                DefaultOptionsName = name;
                save(savePath, 'DefaultOptionsName', '-append')
            end
            
            if ~nargout
                clear givenName
            end
            
        end
        
        function S = loadCustomOptions(obj, optionsName)
            loadPath = obj.FilePath;
            
            S = load(loadPath, 'CustomOptions');
            isMatched = strcmp(optionsName, {S.CustomOptions.Name});
            
            S = S.CustomOptions(isMatched).Options;
            
        end
        
      % % Methods for dealing with modified options.
        
        function storeModifiedOptions(obj, opts, name)
        %storeModifiedOptions Save modified options for later use          
        %
        %   % Transient options... 
        
            ind = find( strcmp(obj.ModdedOptionNames_, name) );  
            
            if isempty(ind)
                obj.ModdedOptionNames_{end+1} = name;
                obj.ModdedOptions_{end+1} = opts;
            else
                obj.ModdedOptions_{ind} = opts;
            end

        end
        
        function removeModifiedOptions(obj, name)
            
            ind = find( strcmp(obj.ModdedOptionNames_, name) );  
            if isempty(ind)
                obj.ModdedOptionNames_(ind) = [];
                obj.ModdedOptions_(ind) = [];
            end
        end
        
        function S = getModifiedOptions(obj, optionsName)
            
            isMatch = strcmp(obj.ModdedOptionNames_, optionsName);
            S = obj.ModdedOptions_{isMatch};
            
        end
        
        function resetModifiedOptions(obj)
            
            obj.ModdedOptionNames_ = {};
            obj.ModdedOptions_ = {};
        end
        
      % % Methods for dealing with default options.
        
        function name = getDefaultOptionsName(obj)
            
            filePath = obj.FilePath();
            
            name = ''; % Initialize to empty char.
            
            if isfile(filePath)
                
                S = load(filePath);
                
                if isfield(S, 'DefaultOptionsName')
                    name = S.DefaultOptionsName;
                end
                
% %                 S =  whos( '-file', filePath );
% %                 names = {S.name};
% %                 
% %                 if contains('DefaultOptionsName', names)
% %                 
% %                     S = load(filePath, 'DefaultOptions');
% %                     name = S.DefaultOptions;
% %                 end

            else % todo! better initialization needed.
                if isempty(obj.PresetOptionNames_)
                    names = obj.listPresetOptions();
                else
                    names = obj.PresetOptionNames_; 
                end
                name = names{1};
            end
            
        end
        
    end
    
    methods % Set/get
        
        function names = get.PresetOptionNames(obj)
             names = obj.listPresetOptions();
        end
        
        function names = get.CustomOptionNames(obj)
             names = obj.listCustomOptions();
        end
    end
    
    methods (Access = private)
        
        function tf = hasOptions(obj, optionsName)
            tf = obj.isPreset(optionsName) || obj.isCustom(optionsName);
        end
        
        function tf = isPreset(obj, optionsName)
            tf = any( strcmp(optionsName, obj.PresetOptionNames) );
        end
        
        function tf = isCustom(obj, optionsName)
            tf = any( strcmp(optionsName, obj.CustomOptionNames) );
        end
        
        function tf = isModified(obj, optionsName)
            tf = any( strcmp(optionsName, obj.ModdedOptionNames_) );
        end
        
        function S = checkDefaultOptions(obj)
            
            try
                fcnHandle = str2func(obj.FunctionName);
                S = fcnHandle();
            catch 
                S = struct();
            end
            
        end
        
        function checkForPresetOptions(obj)
        %checkForPresetOptions Check if preset options are available
        %
        %   Note: This assumes that there is a package called +presets in
        %   the same location where the function/toolbox of the current
        %   OptionsManager instance is located.
               
        %   Note: This only works when the FunctionName points to a package
        %   that contains a +presets folder.
        
            % Find the full path to where the function/package is located
            folderNames =  strsplit(obj.FunctionName, '.');
            s = what( fullfile(folderNames{1:end-1}) );
            
            if isempty(s)
                return
            end
            
            % If a presets folder exist, save the directory path
            if ~isempty(s.packages) && contains('presets', s.packages)
                
                obj.HasPresets = true;
                
                % Assign pathstr to presets directory to property
                presetDir = fullfile(s.path, '+presets');
                obj.PresetOptionsDirectoryPath = presetDir;
                
            else % Can we get the default options???
                
                classParentDir = strjoin(folderNames(1:end-1), '.');
                if ~isempty(classParentDir)
                    optsClassName = [classParentDir, '.Options'];
                else
                    return
                end
                
                if exist(optsClassName, 'class') == 8
                    optsClassFcn = str2func(optsClassName);
                    obj.Options = optsClassFcn().getOptions();
                end
                
            end
            
        end
        
        function S = getPresetOptions(obj, optionsName)
        
            isMatch = strcmp(obj.PresetOptionNames_, optionsName);
            hOpt = obj.PresetOptions_{isMatch};
            
            S = hOpt.getOptions();
            
        end
        
    end
    
    methods (Access = private)
        
        function names = listAllOptionNames(obj)
            names = [obj.listPresetOptions, ...
                obj.listCustomOptions];
        end
        
        function names = listPresetOptions(obj)
        %listPresetOptions List names of preset options
        %
        %   Return a list of names for preset options if the current
        %   instance has presets available.
        
            if obj.HasPresets

                presetDir = obj.PresetOptionsDirectoryPath;
                
                L = dir(fullfile(presetDir, '*.m'));

                % Get full package namespace for presets of current method
                folderNames = strsplit(presetDir, filesep);
                isPackage = strncmp(folderNames, '+', 1);
                folderNames = strrep(folderNames, '+', '');
                packageName = strjoin(folderNames(isPackage), '.');

                % Get preset names from the constant property "Name" for
                % each of the classes in the +presets folder
                [names, hOpts] = deal( cell(1, numel(L)) );
                
                
                for i = 1:numel(L)
                    % Todo: what if there aobj.re other .m files...
                    clsName = strrep(L(i).name, '.m', '');
                    
                    cls = str2func( strjoin({packageName, clsName}, '.') );
                                        
                    hOpts{i} = cls();
                    names{i} = hOpts{i}.Name;                    
                end
                
                % Save to private properties
                obj.PresetOptionNames_ = names;
                obj.PresetOptions_ = hOpts;
                
            else
                names = {'Original'};
                %names = {}; 
            end
            

            
        end
        
        function names = listCustomOptions(obj)
            
            names = {}; % Initialize to empty cell
            
            optionsFilePath = obj.FilePath;
            
            if isfile(optionsFilePath)
                
                S = load(optionsFilePath);
                
                if isfield(S, 'CustomOptions')
                    names = {S.CustomOptions.Name};
                    
                    obj.CustomOptionNames_ = names;
                    obj.CustomOptions_ = S.CustomOptions;
                end
            end
            

% %             % Old version:
% %             if isfile(optionsFilePath)
% %                 S =  whos( '-file', optionsFilePath );
% %                 names = {S.name};
% %             else
% %                 names = {};
% %             end

        end
        
    end
    
    
    methods (Access = protected) % Methods for file interaction
        
        function fileName = createFilename(obj)
        %createFilename Create a filename for the file containing presets
        
            % fileName = strrep(obj.FunctionName, '.', '_');
            fileName = obj.FunctionName;
            % Remove nansen from filename ?
            % fileName = strrep(fileName, 'nansen_', '');
            
            fileName = [fileName, '.mat'];
        end
        
        function assignFilePath(obj)
        %assignFilePath Assign the filepath for the file containing presets

            folderPath = obj.getPresetOptionsDirectory();
            fileName = obj.createFilename();
            
            obj.FilePath = fullfile(folderPath, fileName);
            
        end
        
        function initializeOptionPresetFile(obj)
            
            if obj.FunctionType == 0
                error('The provided function does not exist on path and there is no preset option file. Aborting...')
            
            elseif obj.FunctionType == 1
                if isempty(obj.Options)
                    error('Options must be provided when creating an options manager for a function for the first time.')
                end
                
            elseif obj.FunctionType == 2
                if isempty(obj.Options)
                    fcnHandle = str2func(obj.FunctionName);
                    obj.Options = fcnHandle();
                    obj.OptionsName = 'Default';
                end
                
            elseif obj.FunctionType == 3
                if isempty(obj.Options)
                    fcnName = strcat(obj.FunctionName, '.getDefaultOptions');
                    fcnHandle = str2func(fcnName);

                    obj.Options = fcnHandle();
                    obj.OptionsName = 'Default';
                end
                
            elseif obj.FunctionType == 4
                if isempty(obj.Options)
                    fcnName = strcat(obj.FunctionName, '.getDefaults');
                    fcnHandle = str2func(fcnName);

                    obj.Options = fcnHandle();
                    obj.OptionsName = 'Default';
                end
                
            end

            if isempty(obj.Options)
                error('Default options were not found for %s', obj.FunctionName)
            end
            
            % Save options to file
            obj.saveCustomOptions(obj.Options, obj.OptionsName, true)
            
        end
    end
    
    methods (Static)
        
        function folderPath = getPresetOptionsDirectory()
            folderPath = nansen.localpath('custom_options');
        end
        
        function fcnType = getFunctionType(functionName)
            
            fcnType = 0;

            if exist(functionName, 'class')
                
                superClassNames = superclasses(functionName);
                if contains('nansen.mixin.HasOptions', superClassNames)
                    fcnType = 3;
                elseif contains('nansen.module.abstract.OptionsAdapter', superClassNames)
                    fcnType = 4;
                end
                
            else
                
                try
                    fcnHandle = str2func(functionName);
                    S = fcnHandle();
                    if ~isempty(S) && isstruct(S)
                        fcnType = 2;
                    end
                    
                catch ME
                    switch ME.identifier
                        case 'MATLAB:scriptNotAFunction'
                            return

                        case {'MATLAB:TooManyOutputs', 'MATLAB:minrhs'}
                            % Function returns many outputs?
                            fcnType = 1;
                            
                        otherwise
                            return
                    end
                    
                end
                
            end
                

        end

    end

end

