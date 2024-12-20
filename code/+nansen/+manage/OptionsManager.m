classdef OptionsManager < handle
%nansen.manage.OptionsManager Class for managing toolbox options.
%
%   This class provides an interface for storing and retrieving preset
%   options for algorithms and methods that are part of the nansen package.
%
%   This class can be used in combination with any function or class
%   that requires a set of options/parameters to run, but there are some
%   special ways to implement a function or a class to provide increased
%   functionality. These are described in the examples 2 & 3 below.
%
%   Options presets are saved to the directory which is returned by
%   calling "nansen.localpath('custom_options')". See nansen.localpath for
%   instructions on how to change this path.
%
%   USAGE:
%       optManager = nansen.manage.OptionsManager(fcnName, defOptions)
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
%           i.e each field of the struct could be a substruct (this is
%           useful for a big set of options, to divide them into
%           categories; see structEditor.App for more info).
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
%   PROPERTIES:
%       The options manager object contains the following properties
%
%       FunctionName: Name of function for the current options manager instance
%       Options : The set of options which are currently selected
%       OptionsName : The name of the currently selected name of options

%     A PRESET option is a set of options that are predefined for a
%     function or method. The preset options can be defined in different
%     ways. See OptionsManager/getFunctionType. Todo: document more
%
%     A CUSTOM option is a set of options that are customized from presets
%     by the user and saved to file for later use from the optionsmanager.
%
%     A MODIFIED option is a set of options that are modified from one of
%     the above. This option type is only stored in this class in a
%     transient manner, and the user has to manually save them to retain
%     them across sessions.
%
%     A DEFAULT option is the option set which is used by default. The
%     initial choice is always the first set of preset options, but the
%     user can change which option set to use by default.
%
%     Note: The default options are automatically selected when an instance
%     of options manager is created. If an options set is edited, it will
%     be selected and remain selected until another options set is selected
%     or a new OptionsManager instance is recreated.
        
    % TODO:
    %
    %   [ ] Create an OptionsSet class. This class should look like the
    %   struct returned by getEmptyOptionsSet, and have functionality for
    %   more streamlined interfacing with options sets.
    %
    %   [ ] method to validate options against preset options... I.e if new
    %   parameters are added to a preset, these should be migrated to all
    %   available options sets.
    %
    %   [ ] Make sure correct option set is selected from the list (when
    %       editing options sets)
    %
    %   [ ] Method (gui) for inspecting and removing customized options
    %       Use same interface as projectmanager etc.
    %
    %   [ ] Create enum for function idx types. (UI4)
    %
    %   [ ] Method for updating the options file if preset options have
    %       been redefined. This should be a manual action the user should
    %       consciously make for each options collection
    %
    %   [v] Add formatName method
    %   [ ] Add unformatName method
    %
    %   [ ] Methods for comparing options with archived options. Should
    %       ignore parameters tagged with transient....
    %
    %   [v] Save options sets for project tasks to the project folder?
    
% %     properties (Access = private)
% %         % Todo: Create a class for retrieving presets.
% %         PresetOptionFinder nansen.manage.PresetOptionFinder
% %     end
   
    properties (Constant, Hidden)
        SAVE_MODE = 'single_file' %'multiple_files' % 'multiple_files', 'single_file'
    end

    properties (SetAccess = private)
        FunctionName char       % Name of function (or class)
        FunctionType char
    end
    
    properties (SetAccess = private)
        OptionsName char        % Name of current set of options (Not needed when implementing options as OptionSet)
        Options struct          % Current set of options % make dependent (on what??? file...)
    end
    
    properties (Hidden)
        FilePath                % Filepath where options sets are saved.
    end

    properties (Dependent, SetAccess = private)
        AvailableOptionSets     % Names of all options (not edited), formatted
    end
    
    properties (Dependent, Hidden) % Available options names
        % These properties are dependent in order for them to be updated
        % from file whenever they are accessed.
        
        AllOptionNames          % Names of all options (not edited), unformatted
        PresetOptionNames       % Names of available preset options (created by developer)
        CustomOptionNames       % Names of available custom options (created by user)
        EditedOptionNames       % Names of available edited options (edited by user)
    end
    
    properties (Access = private, Hidden)
        HasPresets = false         % Boolean flag, does preset options exist for this function/method?
        FunctionTypeIdx            % Type of function (see examples 1-3)
    end
    
    properties (Access = private, Hidden) % Keepers of options sets
        PresetOptions_ = nansen.manage.OptionsManager.getEmptyOptionsSet()
        CustomOptions_ = nansen.manage.OptionsManager.getEmptyOptionsSet()
        ModdedOptions_ = nansen.manage.OptionsManager.getEmptyOptionsSet()
    end
    
    events
        OptionsChanged % Is this needed / will I have use for this????
    end
    
    methods % Constructor
        
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
        
            % Assign inputs to appropriate properties:
            obj.FunctionName = fcnName;
            
            if nargin >= 2 && ~isempty(opts)
                obj.Options = opts;
            end
            
            if nargin == 3 && ~isempty(optsName)
                obj.OptionsName = optsName;
            else
                %obj.OptionsName = 'Default'; % Remove?
            end
            
            % Assign filepath for file with options for this function:
            obj.FilePath = obj.createFilePath();
            
            % Determine what type of function is provided (ref examples)
            obj.FunctionTypeIdx = obj.getFunctionType(fcnName);
            
            if obj.FunctionTypeIdx == 0 && isempty(obj.Options)
                error(['Options must be provided when creating an ', ...
                    'options manager for this function for the first time.'])
            end
            
            % Todo: This needs more work. I.e need to combine presets with
            % options inherited from superclasses....!
            obj.findPresetOptions()
            
            % Check if options file exists for the given function
            switch obj.SAVE_MODE
                case 'single_file'
                    if isfile(obj.FilePath)
                        obj.synchOptionsFromFile()
                    else
                        obj.initializeOptionsFile()
                    end
                case 'multiple_files'
                    error('Not implemented yet')
            end
            
            if ~isempty(obj.OptionsName)
                obj.validateProvidedOptions()
            end
            
            if isempty(obj.Options)
                obj.assignDefaultOptions()
            end
        end
    end
    
    methods (Static)
        
        function name = unformatName(name)
            name = nansen.manage.OptionsManager.unformatDefaultName(name);
            name = nansen.manage.OptionsManager.unformatPresetName(name);
        end
        
        function name = formatDefaultName(name)
        %formatDefaultName Format default options name for display
            %name = strcat('>', name, '<');
            name = strcat(name, ' (Default)');
        end
        
        function name = unformatDefaultName(name)
        %unformatDefaultName Unformat default options name for display
            name = strrep(name, ' (Default)', '');
        end
        
        function names = formatPresetNames(names)
        %formatPresetNames Format preset options name for display
            names = cellfun(@(name) sprintf('[%s]', name), names, 'uni', 0);
        end
        
        function name = unformatPresetName(name)
        %unformatDefaultName Unformat preset options name
            name = strrep(name, '[', '');
            name = strrep(name, ']', '');
        end
        
        function names = formatEditedNames(names)
        %formatPresetNames Format preset options name for display
            %names = cellfun(@(name) sprintf('%s (Modified)', name), names, 'uni', 0);
        end
        
        function folderPath = getOptionsDirectory(location)
        %getOptionsDirectory Folder where options sets are saved.
            
            if nargin < 1; location = 'local'; end
        
            switch location
                case 'project'
                    project = nansen.getCurrentProject();
                    folderPath = project.getCustomOptionsFolder();
                case 'local'
                    folderPath = nansen.localpath('custom_options');
            end
        end
        
        function [name, descr] = getCustomOptionsName()
        %getCustomOptionsName Open dialog to get options name and description
            
            dlgTitle =  'Save Options As';
            dlgPrompt = {'Name for customized options:', ...
                'Description (optional):'};
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
    end
    
    methods (Access = public)
        
        function [S, optionsName] = getOptions(obj, optionsName)
            
            if nargin < 2 || isempty(optionsName)
                optionsName = obj.getReferenceOptionsName('Default');
            end
            
            optionsName = obj.unformatDefaultName(optionsName);
            optionsName = obj.unformatPresetName(optionsName);
            
            if obj.isPreset(optionsName)
                S = obj.getPresetOptions(optionsName);
                
            elseif obj.isCustom(optionsName)
                S = obj.loadCustomOptions(optionsName);
                     
            elseif obj.isModified(optionsName)
                S = obj.getModifiedOptions(optionsName);
            else
                S = struct;
                warning('No options were found')
            end
            
            if nargout == 0
                obj.Options = S;
                obj.OptionsName = optionsName;
                clear S optionsName
            elseif nargout == 1
                clear optionsName
            end
        end
        
        function setOptions(obj, optionsName, options)
            % Todo: Create this method
            
            optionsName = obj.unformatDefaultName(optionsName);
            optionsName = obj.unformatPresetName(optionsName);
            
            if any(strcmp(obj.AllOptionNames, optionsName))
                obj.OptionsName = optionsName;
                obj.Options = obj.getOptions(optionsName);
            else
                error('not implemented yet')
            end
        end
    end
    
    methods (Access = public)
        
        function wasAborted = edit(obj)
        %edit Interactively edit current options using structeditor app
        
        % Todo: Combine with editOptions method.
        
            name = strsplit(obj.FunctionName, '.');
            
            if numel(name) > 2
                name = name(end-1:end);
                name = [strjoin(name, '.')];
            else
                name = obj.FunctionName;
            end
            
            %titleStr = sprintf('Edit options for %s', name);
            
            sEditor = structeditor(obj.Options, 'OptionsManager', obj, 'Title', name);
            sEditor.waitfor()
            wasAborted = sEditor.wasCanceled;
            
            if wasAborted
                obj.Options = sEditor.dataOrig;
            else
                obj.Options = sEditor.dataEdit;
            end
            
            delete(sEditor)
            
            if ~nargout
                clear wasAborted
            end
        end
        
        function hOptionsEditor = openOptionsEditor(obj, optionsName, optsStruct)
        %openOptionsEditor Open options editor for current options.
        
            if nargin < 2 || isempty(optionsName)
                optionsName = obj.OptionsName;
            end
            
            if nargin < 3 || isempty(optsStruct)
                optsStruct = obj.getOptions(optionsName);
            end
            
            methodName = strsplit( obj.FunctionName, '.');
            methodName = methodName{end};
        
            titleStr = obj.getEditorTitle(methodName);
            promptStr = sprintf('Set parameters for %s:', methodName);
            
            hOptionsEditor = structeditor(optsStruct, ...
                'OptionsManager', obj, ...
                'Title', titleStr, ...
                'Prompt', promptStr );
            
            hOptionsEditor.changeOptionsSelectionDropdownValue(optionsName);
            
        end
        
        function [optsName, optsStruct, wasAborted] = editOptions(obj, optsName, optsStruct)
        %editOptions Interactively edit options using structeditor app
        
            if nargin < 2
                if isempty(obj.OptionsName)
                    optsName = obj.getReferenceOptionsName('Default');
                else
                    optsName = obj.OptionsName;
                end
                    
                if ~isempty(optsName)
                    optsStruct = obj.getOptions(optsName);
                else
                    optsName = obj.listPresetOptions();
                    optsStruct = obj.getOptions(optsName);
                end
            elseif nargin == 2
                optsStruct = obj.getOptions(optsName);
            end
            
            optsName = obj.unformatName(optsName);
            
            sEditor = obj.openOptionsEditor(optsName, optsStruct);
            sEditor.waitfor()
            
            wasAborted = sEditor.wasCanceled;

            if sEditor.wasCanceled
                optsStruct = sEditor.dataOrig;
            else
                optsStruct = sEditor.dataEdit;
                optsName = sEditor.currentOptionsName;
            end

            % Clear modified options!
            transientOptionNames = obj.EditedOptionNames;
            obj.resetModifiedOptions()

            if ~any(strcmp(transientOptionNames, optsName))
                obj.Options = optsStruct;
                obj.OptionsName = optsName;
            end
            
            if nargout == 2
                clear wasAborted
            elseif nargout == 1
                clear optsStruct wasAborted
            elseif nargout == 0
                clear optsStruct optsName wasAborted
            end
        end

        function givenName = saveCustomOptions(obj, opts, name)
        %saveCustomOptions Save a set of custom options.
        %
        % This method opens a dialog where user can enter a name and a
        % description for the options set.
        
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
            
            if isempty(name); return; end
                        
            % Check that name does not exist already
            if obj.isPreset(name) || obj.isCustom(name)
                errordlg('This name is already in use')
                return
            end
            
            newOpts = obj.createOptionsStructForSaving(opts, name, descr);
            newOpts.Type = 'Custom';
            
            obj.saveOptions(newOpts)
            
            % Add options to private property
            if isempty(obj.CustomOptions_)
                obj.CustomOptions_ = newOpts;
            else
                obj.CustomOptions_(end+1) = newOpts;
            end
            
            givenName = name;

            if ~nargout
                clear givenName
            end
        end
        
        function S = getDefaultOptions(obj)
            
            defaultName = obj.getReferenceOptionsName('Default');
            S = obj.getOptions(defaultName);
            
            if ~nargout
                obj.Options = S;
                obj.OptionsName = defaultName;
                clear S
            end
        end
        
        function name = getReferenceOptionsName(obj, referenceType)
        %getReferenceOptionsName Get name of reference options
        %
        %   Reference options can be either "Default" or "Preferred". The
        %   default options are the options that are hardcoded for a
        %   specific function, while the preferred can be the default or
        %   a set of user customized options that are marked as preferred.
        
            name = '';

            varName = obj.getReferenceTypeVarname(referenceType);
            
            % The name of the reference options sets are saved in the
            % options file.
            if isfile(obj.FilePath)
                S = load(obj.FilePath);
                
                if isfield(S, varName)
                    name = S.(varName);
                end
                
            else % This error should never occur...
                error('Options file does not exist for this function')
            end
        end
        
        % Todo: Remove. Todo: Is it faster to use whos, or just load?
        function name = getPreferredOptionsName(obj)
            
            name = ''; % Initialize to empty char.
                        
            if isfile(obj.FilePath)
                
                S = load(obj.FilePath);
                
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

            else
                % This should not happen
                error('This is an unexpected error')
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
        
        function names = getAllOptionNames(obj)
            names = [obj.PresetOptionNames, obj.CustomOptionNames];
        end
      % % Methods for dealing with modified options.
        
        function appendModifiedOptions(obj, opts, name)
        %appendModifiedOptions Save modified options for later use
        %
        %   % Transient options...
        
            ind = find( strcmp(obj.EditedOptionNames, name) );
            optsEntry = obj.createOptionsStructForSaving(opts, name, '');
            
            if isempty(ind)
                % Append new entry
                obj.ModdedOptions_(end+1) = optsEntry;
            else
                % Replace existing opts.
                obj.ModdedOptions_(ind) = optsEntry;
            end
        end
        
        function removeModifiedOptions(obj, name)
            
            ind = find( strcmp(obj.EditedOptionNames, name) );
            
            if ~isempty(ind)
                obj.ModdedOptions_(ind) = [];
            end
        end

        function S = getModifiedOptions(obj, optionsName)
            
            isMatch = strcmp(obj.EditedOptionNames, optionsName);
            S = obj.ModdedOptions_(isMatch).Options;
            
        end
        
        function resetModifiedOptions(obj)
        %resetModifiedOptions Reset the modified options struct array
            obj.ModdedOptions_ = obj.getEmptyOptionsSet();
        end
        
        function removeCustomOptions(obj, name)
                            
            S = load(obj.FilePath);
            
            name = obj.unformatDefaultName(name);
            
            loadedOptionsNames = {S.OptionsEntries.Name};
            idx = find( strcmp(loadedOptionsNames, name) );

            if isempty(idx)
                error('No options set found matching the name "%s"', name)
            end
            
            assertMsg = 'The options to remove must be a custom options set';
            assert(strcmp(S.OptionsEntries(idx).Type, 'Custom'), assertMsg)

            S.OptionsEntries(idx) = [];
            save(obj.FilePath, '-struct', 'S', '-append')

            obj.refreshCustomOptions()
        end
        
        function updatePresets(obj)
        %updatePresets Update preset option sets from definitions
        %
        %   hOptionsManager.updatePresets() will update the saved preset
        %   based on the most recent preset definitions.
        %
        %   Note: The preset option sets that are provided by this class
        %   will be those that are originally saved the first time an
        %   object of this class was created. If the preset definitions
        %   change (developers changed the source code) the presets will
        %   not be automatically updated in the options manager. This must
        %   be manually done by the user (you) using this method.
        %   Be aware that updating the presets mean that running
        %   functions/methods with those updated presets may produce
        %   different end results, than running the same function methods
        %   with original functions/methods. So if earlier data is analysed
        %   with older preset definition and current data is analysed with
        %   newer preset definitions, results might not be consistent.
        
            error('This method is not implemented yet.')
        
        end
    end
    
    methods % Set/get
        
        function set.FunctionName(obj, newValue)
            msg = 'FunctionName must be a character vector';
            assert(ischar(newValue), msg)
            obj.FunctionName = newValue;
        end
        
        function names = get.AvailableOptionSets(obj)
            names = obj.listDisplayableOptionsNames();
        end
        
        function names = get.AllOptionNames(obj)
            names = [obj.PresetOptionNames, obj.CustomOptionNames];
        end
        
        function names = get.PresetOptionNames(obj)
            names = obj.listPresetNames();
        end
        
        function names = get.CustomOptionNames(obj)
             names = obj.listCustomNames();
        end
        
        function names = get.EditedOptionNames(obj)
             names = obj.listEditedNames();
        end

        function functionType = get.FunctionType(obj)
            AVAILABLE_TYPES = {'Function', 'Function', 'Class', 'Toolbox'}; % SessionTask
            functionType = AVAILABLE_TYPES{obj.FunctionTypeIdx};
        end
    end
    
    methods (Access = private)
        
        function assignDefaultOptions(obj)
            
            optsName = obj.getReferenceOptionsName('Default');
            
            obj.Options = obj.getOptions(optsName);
            obj.OptionsName = optsName;
            
        end
        
        function tf = hasOptions(obj, optionsName)
            tf = obj.isPreset(optionsName) || obj.isCustom(optionsName);
        end
        
        function tf = isPreset(obj, optionsName)
            tf = any( strcmp(obj.PresetOptionNames, optionsName) );
        end
        
        function tf = isCustom(obj, optionsName)
            tf = any( strcmp(obj.CustomOptionNames, optionsName) );
        end
        
        function tf = isModified(obj, optionsName)
            tf = any( strcmp(obj.EditedOptionNames, optionsName) );
        end
        
        function validateProvidedOptions(obj)
            
            % Are options already assigned and do they match with any of
            % the preset or custom options?
            
            isMatched = strcmp(obj.PresetOptionNames, obj.OptionsName);
            if any(isMatched)
                isOptionsValid = isequal( obj.Options, obj.PresetOptions_(isMatched).Options );
                assertMsg = sprintf(['A preset option with the name ', ...
                    '%s already exist, but the options do not match'], ...
                    obj.OptionsName);
                assert(isOptionsValid, assertMsg)
            end
            
            isMatched = strcmp(obj.CustomOptionNames, obj.OptionsName);
            if any(isMatched)
                isOptionsValid = isequal( obj.Options, obj.CustomOptions_(isMatched).Options );
                assertMsg = sprintf(['A custom options set with the name ', ...
                    '%s already exist, but the options do not match'], ...
                    obj.OptionsName);
                assert(isOptionsValid, assertMsg)
            end
        end
        
        function updatedOpts = updateOptionsFromReference(obj, newOpts, refOpts)
            
            % Note:
            %   Adds fields if they are not present already. This is
            %   relevant if more options were added to a method
            %
            %   Updates the value of configuration fields. Todo: Should
            %   update from relevant preset. I.e a custom options set is
            %   derived from a preset options set.
            %
            %   Todo: Remove fields that have become obsolete.

            isAllSubstruct = all( structfun(@(s) isstruct(s), refOpts) );
            
            if isAllSubstruct
                subfields = fieldnames(refOpts);

                updatedOpts = newOpts;

                for i = 1:numel(subfields)
                    
                    thisField = subfields{i};

                    if isfield(newOpts, thisField)
                        updatedOpts.(thisField) = obj.addMissingFieldsFromReference(...
                            newOpts.(thisField), refOpts.(thisField) );
                    else
                        updatedOpts.(thisField) = refOpts.(thisField);
                    end
                end

            else
                updatedOpts = obj.addMissingFieldsFromReference(newOpts, refOpts);
            end
        end
        
        function s = addMissingFieldsFromReference(~, s, sRef)
                        
            fieldNamesRef = fieldnames(sRef);
            for i = 1:numel(fieldNamesRef)
                thisField = fieldNamesRef{i};

                % Add field if it is not present
                if ~isfield(s, thisField)
                    s.(thisField) = sRef.(thisField);

                % Update configuration fields
                elseif strcmp(thisField(end), '_')
                    s.(thisField) = sRef.(thisField);
                end
            end
        end
        
        % Todo:
% %         function s = removeDeprecatedFields(obj, s, sRef)
% %
% %
% %
% %         end
        
        function updateOptionsFromDefault(obj)
                        
            for i = 1:numel(obj.CustomOptions_)
                obj.CustomOptions_(i) = obj.updateOptionsFromReference(...
                    obj.CustomOptions_(i), obj.PresetOptions_(1) );

            end
        end
        
        % % Methods related to preset options. % Create PresetOptionFinder
        % class?
        
        function names = findPresetOptions(obj)
        %findPresetOptions Find preset options for the current object
        %
        %   Find preset options for a function and assign them to the
        %   private property containing preset options. Check whether the
        %   found preset options match provided options or options in file.

            if obj.FunctionTypeIdx == 0
                if isempty(obj.Options)
                    error(['Options must be provided when creating an ', ...
                        'options manager for a function for the first time.'])
                end
                
            elseif obj.FunctionTypeIdx == 1 || obj.FunctionTypeIdx == 2
                optionsEntry = obj.findPresetsFromFunction();
                
            elseif obj.FunctionTypeIdx == 3 || obj.FunctionTypeIdx == 4

                if obj.inheritOptionsFromSuperclass()
                    optionsEntry = obj.getPresetsFromSuperclass();
                elseif obj.hasPresetPackage
                    optionsEntry = obj.findPresetsFromPresetsPackage();
                else
                    optionsEntry = obj.findPresetsFromOptionsMixinClass();
                end
            else
                error('Something went wrong!')
            end
                        
            % Make sure any options are present before continuing.
            if isempty(obj.Options) && isempty(optionsEntry)
                error('Preset options were not found for %s', obj.FunctionName)
            end
            
            % Assign preset options to the corresponding private properties.
            obj.PresetOptions_ = optionsEntry;
            obj.HasPresets = ~isempty(obj.PresetOptions_); % Todo: Make HasPresets dependent

            if nargout
                names = {optionsEntry.Name};
            end
        end
         
        function optionsEntry = findPresetsFromFunction(obj)
        %findPresetsFromFunction Find preset options from a function
        %
        % A function with options should return a struct of options when
        % called with no inputs. Get the struct, and give it the name
        % Default.

            fcnHandle = str2func(obj.FunctionName);
            
            % Return as options entry (struct)
            opts = fcnHandle();
            name = 'Preset Options';
            
            if obj.FunctionTypeIdx == 1
                opts = opts.DefaultOptions; % Session task formatting...
            end
            
            if isempty(obj.OptionsName)
                if isequal(obj.Options, opts)
                    obj.OptionsName = name;
                end
            end
            
            optionsEntry = obj.createOptionsStructForSaving(opts, name, ...
                sprintf('Default preset options for %s', obj.FunctionName) );
            
        end
        
        function optionsEntry = findPresetsFromOptionsMixinClass(obj)
        %findPresetsFromOptionsMixinClass Find preset options from a class
        %
        % A mixin class with options (inheriting from HasOptions) has a
        % getDefaultOptions method which returns a struct of options. Get
        % the struct, and give it the name Default.
        
            fcnName = strcat(obj.FunctionName, '.getDefaultOptions');
            fcnHandle = str2func(fcnName);

            % Return as options entry (struct)
            opts = fcnHandle();
            name = 'Preset Options';
            
            optionsEntry = obj.createOptionsStructForSaving(opts, name, ...
                sprintf('Default preset options for %s', obj.FunctionName) );

        end
        
        function tf = inheritOptionsFromSuperclass(obj)
        %inheritOptionsFromSuperclass Check if function inherits options
        
            tf = false; % null hypothesis, function does not inherit options
            
            superClassNames = superclasses(obj.FunctionName);

            if contains('nansen.mixin.HasOptions', superClassNames)
                mc = meta.class.fromName(obj.FunctionName);
                
                if ~isempty(mc.PropertyList)
                    
                    matchedIdx = strcmp({mc.PropertyList.Name}, 'OptionsManager');
                    if any(matchedIdx)
                        definingClass = mc.PropertyList(matchedIdx).DefiningClass;
                        if strcmp(definingClass.Name, obj.FunctionName)
                            return
                        elseif mc.PropertyList(matchedIdx).Abstract
                            return
                        elseif any(strcmp(superClassNames, definingClass.Name))
                            tf = true;
                        end
                    end
                end
            end
        end
        
        function name = getOptionsDefiningSuperclassName(obj)
            
            mc = meta.class.fromName(obj.FunctionName);
            matchedIdx = strcmp({mc.PropertyList.Name}, 'OptionsManager');
            definingClass = mc.PropertyList(matchedIdx).DefiningClass;
            name =  definingClass.Name;
            
        end
        
        function optionsEntry = getPresetsFromSuperclass(obj)
        %getPresetsFromSuperclass
        
            optManager = eval(sprintf('%s.OptionsManager', obj.FunctionName));
            presetOptionsNames = optManager.PresetOptionNames;
            
            for i = 1:numel(presetOptionsNames)
                
                optsName = presetOptionsNames{i};
                optsStruct = optManager.getOptions(optsName);
                
                optionsEntry(i) = obj.createOptionsStructForSaving(...
                        optsStruct, optsName, '');
            end
        end
        
        function tf = hasPresetPackage(obj)
        %hasPresetPackage Check if current function has a options preset package.
        
            tf = false;
            
            % Find the full path to where the function/package is located
            folderNames =  strsplit(obj.FunctionName, '.');
            s = what( fullfile(folderNames{1:end-1}) );
                        
            if isempty(s)
                return
            elseif numel(s) > 1
                warning('Multiple instances of function "%s" was found on the path.', obj.FunctionName)
                % Note: If this happens when running a job on a parallel
                % pool of workers, it might be necessary to reset the
                % pool(?) by deleting it from Matlab's Job Monitor...
                % (Restarting matlab did not fix it for me)
                s = s(1);
            else
                % All good.
            end

            tf = ~isempty(s.packages) && contains('presets', s.packages);
        end
        
        function optionsEntry = findPresetsFromPresetsPackage(obj)
        %findPresetsFromPresetsPackage Find preset options from a package
        %
        % Use this function if a folder called +presets co-exists with the
        % function of the current OptionsManager instance
            
            % Find the full path to where the function/package is located
            folderNames =  strsplit(obj.FunctionName, '.');
            s = what( fullfile(folderNames{1:end-1}) );
            
            if isempty(s) % This folder is empty... abort.
                error('No preset package was found')
            elseif numel(s) > 1
                 nansen.common.tracelesswarning(...
                     'Multiple instances of NANSEN is on MATLAB''s search path')
                s = s(1);
            end

            % If a presets folder exist, get the existing presets
            if ~isempty(s.packages) && contains('presets', s.packages)
                
                presetDir = fullfile(s.path, '+presets');
                L = dir(fullfile(presetDir, '*.m')); % Find .m files

                % Get full package namespace for presets of current method
                packageName = utility.path.pathstr2packagename(presetDir);

                % Get preset names from the constant property "Name" for
                % each of the classes in the +presets folder
                
                for i = 1:numel(L)
                    % Todo: what if there are other .m files...
                    % Low priority, as probably no one would do that.
                    clsName = strrep(L(i).name, '.m', '');
                    cls = str2func( strjoin({packageName, clsName}, '.') );
                                        
                    hOptions = cls();
                    
                    optionsEntry(i) = obj.createOptionsStructForSaving(...
                        hOptions.getOptions(), hOptions.Name, hOptions.Description); %#ok<AGROW>

                end
            else
                error('No preset package was found')
            end
        end

        function S = getPresetOptions(obj, optionsName)
        %getPresetOptions Get preset option set matching given name
            isMatch = strcmp(obj.PresetOptionNames, optionsName);
            S = obj.PresetOptions_(isMatch).Options;
        end
    end
    
    methods (Access = private) % Methods for listing option set names

        function names = listPresetNames(obj)
        
            if ~isempty( obj.PresetOptions_ )
                names = {obj.PresetOptions_.Name};
            else
                names = {};
            end
        end
        
        function names = listCustomNames(obj)
        
            obj.refreshCustomOptions() % not super scalable...
            
            if ~isempty( obj.CustomOptions_ )
                names = {obj.CustomOptions_.Name};
            else
                names = {};
            end
        end
        
        function names = listEditedNames(obj)
        
            if ~isempty( obj.ModdedOptions_ )
                names = {obj.ModdedOptions_.Name};
            else
                names = {};
            end
        end
        
        function names = listDisplayableOptionsNames(obj)

            names = obj.AllOptionNames;
            
            defaultOptionsName = obj.getReferenceOptionsName('Default');
            isPreferred = strcmp(names, defaultOptionsName);
            
            presetNames = {obj.PresetOptions_.Name};
            isPreset = ismember(names, presetNames);
            
            % Format preset names
            names(isPreset) = obj.formatPresetNames(names(isPreset));
            
            % Format preferred name.
            names(isPreferred) = obj.formatDefaultName(names(isPreferred));
            
        end
    end
    
    methods (Access = private) % Methods for file interaction
        
        function tf = compareOptions(obj, optsA, optsB)
            % Todo
            tf = isequal(optsA, optsB);
        end
        
        function fileName = createFilename(obj)
        %createFilename Create a filename for the file containing presets
            
            if obj.inheritOptionsFromSuperclass()
                fileName = obj.getOptionsDefiningSuperclassName();
            else
                fileName = obj.FunctionName;
            end
            
            fileName = [fileName, '.mat'];
        end
        
        function folderName = createFoldername(obj)
        %createFilename Create a filename for the file containing presets
            
            if obj.inheritOptionsFromSuperclass()
                folderName = obj.getOptionsDefiningSuperclassName();
            else
                folderName = obj.FunctionName;
            end
        end
        
        function filePath = createFilePath(obj)
        %assignFilePath Assign the filepath for the file containing presets

            pathStr = which(obj.FunctionName);
            if contains(pathStr, fullfile('code', 'integrations', 'sessionmethods'))
                location = 'local';
            elseif contains(pathStr, '+nansen')
                location = 'local';
            else
                location = 'project';
            end
            folderPath = obj.getOptionsDirectory(location);
            
            if strcmp(obj.SAVE_MODE, 'single_file')
                fileName = obj.createFilename();
                filePath = fullfile(folderPath, fileName);
            elseif strcmp(obj.SAVE_MODE, 'multiple_files')
                error('Not implemented yet')
                %fileName = obj.createFoldername();
                %filePath = fullfile(folderPath, fileName);
            end
        end
        
        function initializeOptionsFile(obj)
        %initializeOptionsFile Create a optionsfile for current object
        %
        %   This method is used to initialize an options file for the
        %   current optionsmanager instance. If an options set was not
        %   provided on creation, we check if a definition of options exist
        %   in the function/class/toolbox definition.
        
            % Save options to file
            if ~isempty(obj.PresetOptions_)
                
                for i = 1:numel(obj.PresetOptions_)
                    
                    newOpts = obj.PresetOptions_(i);
                    newOpts.Type = 'Preset';
                     
                    obj.saveOptions(newOpts)

                    if i == 1
                        DefaultOptionsName = newOpts.Name;
                        %PreferredOptionsName = newOpts.Name;
                    end
                end
                
            elseif ~isempty(obj.Options)
                obj.saveCustomOptions(obj.Options, obj.OptionsName) %Todo!
                DefaultOptionsName = obj.OptionsName;
                %PreferredOptionsName = obj.OptionsName;
            end

            save(obj.FilePath, 'DefaultOptionsName', '-append')
            %save(obj.FilePath, 'PreferredOptionsName', '-append')

        end
        
        function synchOptionsFromFile(obj)
        %synchOptionsFromFile Synch provided options with options from file.
            
            S = load(obj.FilePath);
            
            % Update preset options from loaded presets.
            isPresetOptions = strcmp( {S.OptionsEntries.Type}, 'Preset' );
            loadedPresetOptions = S.OptionsEntries(isPresetOptions);
                 
            wasPresetOptionsUpdated = false;

            for i = 1:numel(obj.PresetOptions_)
                thisName = obj.PresetOptions_(i).Name;
                iReferenceOpts = obj.PresetOptions_(i).Options;
                
                if any(strcmp({loadedPresetOptions.Name}, thisName))
                    matchIdx = strcmp({loadedPresetOptions.Name}, thisName);
                    
                    iLoadedOpts = loadedPresetOptions(matchIdx).Options;

                    if ~isequal(iLoadedOpts, iReferenceOpts)
                        iLoadedOpts = obj.updateOptionsFromReference(iLoadedOpts, iReferenceOpts);
                        fprintf('Updated options for %s to match to changes in preset options\n', obj.FunctionName)
                        loadedPresetOptions(matchIdx).Options = iLoadedOpts;
                        obj.saveOptions(loadedPresetOptions(matchIdx), true)
                        wasPresetOptionsUpdated = true;
                    end
                    
                    if ~isequal(iLoadedOpts, iReferenceOpts)
                        
                        % Todo: Implement this and make it easy to fix...
                        
% %                         functionLink = sprintf('See <a href="matlab: open(''nansen.manage.OptionsManager/updatePresets'')">updatePresets</a> for more info.');
% %                         warnMsg = sprintf(['The preset OptionsSet "%s" has been ', ...
% %                             'modified and is different from \nthe originally saved ', ...
% %                             'preset OptionsSet. %s\n'], thisName, functionLink);
% %                         warning('Nansen:OptionsManager:PresetChanged', warnMsg) %#ok<SPWRN>
                    end
                        
                    obj.PresetOptions_(i) = loadedPresetOptions(matchIdx);
                else
                    obj.saveOptions(obj.PresetOptions_(i))
                end
            end
            
            % Get custom options from file.
            isCustomOptions = strcmp( {S.OptionsEntries.Type}, 'Custom' );
            
            if any(isCustomOptions)
                loadedCustomOptions = S.OptionsEntries(isCustomOptions);
            
                if wasPresetOptionsUpdated
                    for i = 1:numel(loadedCustomOptions)
                        loadedCustomOptions(i).Options = obj.updateOptionsFromReference(...
                            loadedCustomOptions(i).Options, obj.PresetOptions_(1).Options);
                        obj.saveOptions(loadedCustomOptions(i), true)
                    end
                end

                obj.CustomOptions_ = loadedCustomOptions;
            end
            
            % Save provided options or match them against loaded...
            if ~isempty(obj.Options)
                if isempty(obj.OptionsName)
                    for i = 1:numel(obj.PresetOptions_)
                        if isequal(obj.PresetOptions_(i).Options, obj.Options)
                            obj.OptionsName = obj.PresetOptions_(i).Name;
                            return
                        end
                    end
                    
                    for i = 1:numel(obj.CustomOptions_)
                        if isequal(obj.CustomOptions_(i).Options, obj.Options)
                            obj.OptionsName = obj.CustomOptions_(i).Name;
                            return
                        end
                    end
                        
                    obj.saveCustomOptions(obj.Options)
                    
                elseif obj.hasOptions(obj.OptionsName)
                    opts = obj.getOptions(obj.OptionsName);
                    
                    assertMsg = 'Provided options already exist but are different from previously saved options, aborting...';
                    
                    isEqual = obj.compareOptions(opts, obj.Options);

                    if ~isEqual && (isempty(opts) || isempty(fieldnames(opts)))
                        warning('Not implemented yet, forgot if this is necessary')
                        %return %1st time initialization
                    end

                    assert(isEqual, assertMsg)
                end
            end
        end
        
        function saveOptions(obj, newOptionsSet, doReplace)
        %saveOptions Save an options set to file for current instance
        %
        %   saveOptions(obj, newOptionsSet) saves the newOptionsSet to
        %   file. newOptionsSet is a struct with the following fields:
        %
        %   Name, Type, Description, Options, DateCreatedNum, DateCreated
        %
        %   See also OptionsManager/createOptionsStructForSaving
        
            if nargin < 3; doReplace = false; end

            % Get filepath
            savePath = obj.FilePath;
            if ~isfolder(fileparts(savePath))
                mkdir(fileparts(savePath))
            end
            if isfile(savePath)
                S = load(savePath);
            
                isMatch = strcmp({S.OptionsEntries.Name}, newOptionsSet.Name);
                if any(isMatch) && doReplace
                    S.OptionsEntries(isMatch) = newOptionsSet;
                elseif any(isMatch) && ~doReplace
                    errMsg = sprintf('Option preset with name "%s" already exists, aborted.', newOptionsSet.Name);
                    errordlg(errMsg)
                    error(errMsg) %#ok<SPERR>
                else
                    S.OptionsEntries(end+1) = newOptionsSet;
                end
                save(savePath, '-struct', 'S', '-append')
            else
                S = struct;
                S.OptionsEntries = newOptionsSet;
                save(savePath, '-struct', 'S')
            end
        end
        
        function savePresetOptions(obj, opts, name, descr)
        %savePresetOptions Save a set of preset options.

            if obj.isPreset(name)
                errordlg('This name is already in use')
                return
            end
            
            if obj.isCustom(name)
                errordlg('This name is already used for a custom options set')
                return
            end
            
            newOpts = obj.createOptionsStructForSaving(opts, name, descr);
            newOpts.Type = 'Preset';
                     
            obj.saveOptions(newOpts)
            
        end
        
        function S = loadCustomOptions(obj, optionsName)
            loadPath = obj.FilePath;
            
            S = load(loadPath, 'OptionsEntries');
            isMatched = strcmp(optionsName, {S.OptionsEntries.Name});
            S = S.OptionsEntries(isMatched).Options;
        end
        
        function refreshCustomOptions(obj)
        %refreshCustomOptions Assign custom options from file to object
                    
            if isfile(obj.FilePath)
                S = load(obj.FilePath);
                
                if isfield(S, 'OptionsEntries')
                    
                    isCustom = strcmp({S.OptionsEntries.Type}, 'Custom');
                    
                    if ~any(isCustom)
                        obj.CustomOptions_ = obj.getEmptyOptionsSet();
                    else
                        obj.CustomOptions_ = S.OptionsEntries(isCustom);
                    end
                end
            end
        end
    end
    
    methods (Static, Access = private)
        
        function editorTitleStr = getEditorTitle(functionName)
        %getEditorTitle Get title for options editor
        
            methodName = '';
            
            mc = meta.class.fromName( functionName );
            if ~isempty(mc)
                if any(strcmp({mc.PropertyList.Name}, 'MethodName'))
                    isMatch = strcmp({mc.PropertyList.Name}, 'MethodName');
                    propertyItem = mc.PropertyList(isMatch);
                    if propertyItem.HasDefault
                        methodName = propertyItem.DefaultValue;
                    end
                end
            end
            
            if isempty(methodName)
                methodName = strsplit( functionName, '.');
                methodName = methodName{end};
            end
            
            editorTitleStr = sprintf('Options Editor (%s)', methodName);
            
        end
        
        function varName = getReferenceTypeVarname(referenceType)
        %getReferenceTypeVarname Get variable name for given reference type
        %
        %   Reference type can be "Default"
        
            validTypes = {'Default'};
            referenceType = validatestring(referenceType, validTypes);
            varName = strcat(referenceType, 'OptionsName');
        end
        
        function S = createOptionsStructForSaving(opts, name, descr)
        %createOptionsStructForSaving Create a struct of options for saving
        %
        %   The struct contains the following fields:
        %
        %       Name            : Name of this options set
        %       Type            : Type of this options set (Preset or Custom)
        %       Description     : Description of this options set
        %       Options         : The actual options as a struct
        %       DateCreatedNum  : Date and time when options set was
        %                         created as a serial date number
        %       DateCreated     : Date and time when options set was
        %                         created as a formatted string
        
            if nargin < 2 || isempty(name)
                error('Name must be provided when saving options')
            end
            
            if nargin < 3
                descr = '';
            end
        
            % Create struct object for custom options
            t = now();
            
            S = struct();
            S.Name = name;
            S.Type = '';
            S.Description = descr;
            S.Options = opts;
            S.DateCreatedNum = t;
            S.DateCreated = datestr(t, 'yyyy.mm.dd - HH:MM:SS');
            
        end
        
        function S = getEmptyOptionsSet()
        %getEmptyOptionsSet Get an empty struct for an options set.
        %
        %   The resulting struct contains the same fields as a struct
        %   returned by createOptionsStructForSaving. This should probably
        %   be objectified...
        
            S = struct( 'Name', {}, 'Type', {}, 'Description', {}, ...
                'Options', {}, 'DateCreatedNum', {}, 'DateCreated', {} );
        end
        
        function fcnType = getFunctionType(functionName)
        %getFunctionType Determine function type for the given functionname
        %
        % A function in the Nansen Toolbox can be written according to
        % specific templates, and each template has a certain way to define
        % options. This method determines which template (function type)
        % the function with the given function name was created from.
        %
        %   Available Function Types:
        %
        %       0 : The function does not match a template
        %       1 : Function that returns options and session task attributes
        %       2 : Function which returns a struct of options when called
        %           with no inputs.
        %       3 : Class inheriting the HasOptions mixin class.
        %       4 : External toolbox / package wrapper
                    
        % Sorry, This is a mess..
        
            fcnType = 0;

            if exist(functionName, 'class')
                
                superClassNames = superclasses(functionName);

                if contains('nansen.mixin.HasOptions', superClassNames)
                    fcnType = 3;
                elseif contains('nansen.wrapper.abstract.OptionsAdapter', superClassNames)
                    fcnType = 4;
                end
                
            else
                
                try
                    fcnHandle = str2func(functionName);
                    S = fcnHandle();
                    if ~isempty(S) && isstruct(S)
                        if isfield(S, 'DefaultOptions') % Session task function...
                            fcnType = 1;
                        else
                            fcnType = 2;
                        end
                    end
                    
                catch ME
                    switch ME.identifier
                        case 'MATLAB:scriptNotAFunction'
                            return

                        case {'MATLAB:TooManyOutputs', 'MATLAB:minrhs'}
                            % Function returns options and session task attributes
                            fcnType = 1;
                            
                        otherwise
                            return
                    end
                end
            end
        
            if fcnType == 0
                errorMsg = sprintf('The provided function "%s" does not exist on path', functionName);
                error(errorMsg)
            end
        end
    end
end
