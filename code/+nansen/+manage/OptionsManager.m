classdef OptionsManager < handle
    
    % A general manager for options of any function / method that has some
    % configuration options. This class is used for accessing preset and 
    % custom options as well as modified options.
    %
    % A preset option is a set of options that are defined in a special
    % class.
    % A custom option is a set of options that are saved to a predefined
    % file location
    % A modified option is a set of options that are modified from one of
    % the above. This option type is only stored in this class in a
    % transient manner.
    
        
    % Questions: 
    %   [ ] Rename to preset manager?
    
    % TODO:
    %  *[ ] Make this more intuitive! I.e whats difference between default,
    %       preset and custom...? When to use what?
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
    %
    %
    
    properties (Constant)
    
    end
    
    properties 
        FunctionName
    end
    
    properties
        HasPresets = false
        Options
    end
    
    properties (Dependent)
        % These properties are dependent in order for them to be updated
        % from file whenever they are accessed.
        PresetOptionNames 
        CustomOptionNames
    end
    
    properties (Access = private, Hidden)
        PresetOptionsDirectoryPath % Path to directory containing preset options
        CustomOptionsFilePath   % Filepath where custom options as saved
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
    
    methods 
        function obj = OptionsManager(fcnName, defaultOpts)
        
            obj.FunctionName = fcnName;
            
            if nargin == 2
                obj.Options = defaultOpts;
            elseif nargin < 2 || isempty(defaultOpts)
                
                opts = obj.checkDefaultOptions();
                if isa(opts, 'struct')
                    obj.Options = opts;
                end
                
                % Currently done within check for preset options...
                % Does not include functions, only packages with an Options
                % class.
            end
            
            obj.checkForPresetOptions()
            
            obj.CustomOptionsFilePath = obj.createCustomOptionsFilePath();
        
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
            
            if nargout == 1
                clear optionsName
            end
            
        end
        
        function S = getDefault(obj)
            
            defaultName = obj.getDefaultOptionsName();
            S = obj.getOptions(defaultName);
            
        end
        
        function setDefault(obj, optionsName)
        %setDefault Set (flag) options with given name as default
        
            savePath = obj.createCustomOptionsFilePath();
                
            DefaultOptionsName = optionsName;
            if isfile(savePath)
                save(savePath, 'DefaultOptionsName', '-append')
            else
                save(savePath, 'DefaultOptionsName')
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
            savePath = obj.createCustomOptionsFilePath();
            
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
            loadPath = obj.createCustomOptionsFilePath();
            
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
            
            filePath = obj.createCustomOptionsFilePath();
            
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
            s = what( fullfile(folderNames{:}) );
            
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
                
                optsClassName = [obj.FunctionName, '.Options'];
                
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
    
    
    methods % (Access = private) ??
        
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
            
            optionsFilePath = obj.createCustomOptionsFilePath();
            
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

        function pathStr = createCustomOptionsFilePath(obj)
            % Todo: make static.
            rootPath = nansen.localpath('custom_options');

            fileName = strrep(obj.FunctionName, '.', '_');
            
            % Remove nansen from filename
            fileName = strrep(fileName, 'nansen_', '');
            
            pathStr = fullfile(rootPath, [fileName, '.mat']);

        end
                             
        function pathStr = createCustomOptionsFilePath2(obj)
            
            rootPath = nansen.localpath('custom_options');

            splitName = strsplit(obj.FunctionName, '.');
            
            if numel(splitName) > 1
                dirPath = fullfile(rootPath, splitName{1:end-1});
                if ~exist(dirPath, 'dir');     mkdir(dirPath);     end
                splitName = splitName(end);
            else
                dirPath = rootPath;
            end
            
            pathStr = fullfile(dirPath, [splitName{1}, '.mat']);

        end
        
    end

    
    methods (Static)
        
        
        
    end


    
end

