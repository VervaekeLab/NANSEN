classdef SessionMethod < nansen.DataMethod
%SessionMethod Abstract class for session methods
%   
%   Classes inheriting SessionMethod should provide a method for use on one
%   or more session objects. The SessionMethod superclass provides some
%   attributes and methods so that methods can be run in different ways, 
%   i.e they can be run directly, or run with configuration mode.

%
%   Notes on implementation:
%       
%       This class should take a SessionObject or an array of
%       SessionObjects as input. If applicable, the second input should be
%       selection of an options alternative, i.e running the method with 
%       a preset configuration.
%       All successive inputs is a list of nvpairs corresponding to
%       parameters.


%   Notes on behavior:
%       If class is called without inputs it should return an "attributes"
%       struct. The struct contains all the class' constant properties in
%       addition to a Parameter field. 
%   
%       The attribute struct contain info that can be used to check how the
%       method can be run. For example, some sessions methods should run
%       one by one session whereas other methods will run a group of
%       sessions as a batch.
%
% 
%       If class instance is run without output, the class' main
%       method/implementation is run directly.
%
%       If instance is created and output is requested, the class' main
%       method is not initialized, and can be initialized at a later time.



    % Questions:
    %
    %   Are there benefits of having alternatives as separate properties as
    %   done in the original implementation in the session browser?
    
    
    % TODO (implemented in options manager):
    % * [ ] Change name of class to SessionTask
    %   [x] methods/functionality for preset options.
    %   [x] append a page in options for saving a preset
    %   [x] create method for getting options based on name.

    
% - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - - 
    
    properties (Abstract, Constant)
        BatchMode                   % char      : 'serial' | 'batch' Should session method accept one (serial) or multiple (batch) session objects?
        % MaxAllowedSessions = inf;     % Todo(?): limit number of sessions...
        % Similar to above, but for performance or other issues??
     end
    
    
    properties 
        SessionObjects          % Array of session objects
        ExternalFcn % remove this...???
        % Parameters % inherited from datamethod
    end
    
    
    properties (Constant, Access = protected)
        VALID_SESSION_CLASS = 'nansen.metadata.type.Session'
    end
    
% - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - - -
  
    methods (Abstract, Static)
    end
    
% %     methods (Abstract) % Todo: Should there be any abstract methods??? Maybe make run abstract... Or maybe figure out how to make sure to call the subclass version of run....?
% %         runMethod(obj)
% %     end
    
    methods % Constructor
        
        function obj = SessionMethod(varargin)
            
            % Todo: Some more input validation? I.e is it possible that
            % varargin is a combination of struct and name value pairs?
            % utility.parsenvpairs already takes care of it if varargin
            % contains a struct in first place, but does not handle
            % additional nv pairs then. Also, maybe not very transparent?
            
            % If no inputs are provides, return an object which can be run
            % later.
            if numel(varargin) == 0
                return
            end
            
            
            % Validate session objects
            message = 'First input must be a valid session object or a list of valid session objects';
            assert(isa(varargin{1}, obj.VALID_SESSION_CLASS), message)
            
            % Assign session objects to properties
            obj.SessionObjects = varargin{1};
            
            % Set session object as data I/O model
            obj.DataIoModel = obj.SessionObjects;
            
            % Parse name-value pairs and assign to parameters property.
            if ~isempty(obj.OptionsManager)
                params = obj.OptionsManager.getOptions;
                %obj.Parameters = utility.parsenvpairs(params, 1, varargin);
                obj.Options = utility.parsenvpairs(params, 1, varargin);
            end
            
            % Check that required variables for this method exist.
            obj.checkRequiredVariables()
            
            % Call the appropriate run method
            if ~nargout
                obj.run()
                clear obj
            end
            
        end
        
    end
    
    methods
        
        function checkRequiredVariables(obj)
        %checkRequiredVariables Check if required variables are available    
            if isempty(obj.DataIoModel)
                error('Nansen:SessionMethod:IoModelMissing', ...
                    'Data I/O Model is missing for method %s', class(obj))
            end
            
            % Alternative to making this abstract in which case subclasses
            % has to implement it...
            if ~isprop(obj, 'RequiredVariables'); return; end
            
            for i = 1:numel(obj.RequiredVariables)
                
                assertionMsg = sprintf(['File for the required data ', ...
                    'variable "%s" is missing'], obj.RequiredVariables{i});
                
                filePath = obj.getDataFilePath(obj.RequiredVariables{i});
                assert(isfile(filePath), assertionMsg)
                
            end
            
        end
        
        function run(obj)
            
            % Todo: How to create a sessionMethod instance from a function?
            % Create a subclass??
            if ~isempty(obj.ExternalFcn)
                sessionObjects = obj.SessionObjects;
                %params = obj.Parameters;
                params = obj.Options;
                
                obj.ExternalFcn(sessionObjects, params)
            else
                obj.runMethod()
            end
        end

        function setup(obj)
                        
            obj.Options = tools.editStruct(obj.Options);
            
        end
        
        function usePreset(obj, presetName)
            
            obj.OptionsManager.setOptions(presetName)
            obj.Options = obj.OptionsManager.getOptions(presetName);
            %obj.Parameters = obj.OptionsManager.getOptions(presetName);
        end
        
    end
    
    methods % Set/get methods
%         function names = get.PresetOptionNames(obj)
%             % Todo: This should not be a proprty of this class.
%             names = obj.OptionsManager.listPresetOptions();
%         end
    end
    
    
    methods (Static)
    
        function name = getMethodName(sessionMethod)
        %getMethodName Get name of session method    
            
            fcnAttributes = sessionMethod();
            
            if isstruct(fcnAttributes)
                if isfield(fcnAttributes, 'MethodName')
                    name = fcnAttributes.MethodName;
                else
                    fcnNameSplit = strsplit( func2str(sessionMethod), '.' );
                    name = utility.string.varname2label(fcnNameSplit{end});
                end
            elseif isa(fcnAttributes, 'nansen.session.SessionMethod')
                name = fcnAttributes.MethodName;
            end
            
        end
        
        function attributes = setAttributes(varargin)
        %setAttributes Create a struct mimicking an object of this class
        %
        %   Quick setup of a struct that has some of the same fields as an
        %   object of this class. Can be used by functions to give them 
        %   similar functionality as the SessionMethod class
        %
        %   S = nansen.session.SessionMethod.setAttributes(paramStruct) 
        %
        %   S = nansen.session.SessionMethod.setAttributes(paramStruct, kwd, ...)
        %
        %
        %   See also nansen.session.methods.template.SessionMethodFunctionTemplate
        
        
            % Todo: Get all constant properties + parameters from metaclass
            % definition.
            
            %    Include Required variables as attribute
            
            % Fields of output struct with defaults.
            S.BatchMode = 'serial';
            S.IsQueueable = true;
            S.Alternatives = {};

            % Pick out default options from inputs or init to empty struct
            if ~isempty(varargin) && isstruct(varargin{1})
                defaultOpts = varargin{1};
                varargin = varargin(2:end);
            else
                defaultOpts = struct();
            end
            
            S.DefaultOptions = defaultOpts;
         
            % Extract flags from varargin
            flags = {'batch', 'serial', 'queueable', 'unqueueable'};
            [flags, varargin] = utility.splitvararginflags(varargin, flags);
            
            % Check for any name, value pairs in varargin
            [nvPairs, varargin] = utility.getnvpairs(varargin);
            
            S = utility.parsenvpairs(S, 1, nvPairs);

            % Update S from input flags
            if contains('serial', flags)
                S.BatchMode = 'serial';
            end
            
            if contains('batch', flags)
                S.BatchMode = 'batch';
            end
            
            if any( strcmpi('queueable', flags) )
                S.IsQueueable = true;
            end
            
            if any( strcmpi('unqueueable', flags) )
                S.IsQueueable = false;
            end

            % Get name of calling function:
            % Todo: Get this from varargin if provided.
            fcnName = nansen.session.SessionMethod.getCallingFunction();
            fcnNameSplit = strsplit(fcnName, '.');
            S.MethodName = utility.string.varname2label(fcnNameSplit{end});
            
            attributes = S;
            
        end
        
        function attributes = getAttributesFromFunction(fcnName)
            
        end
        
        function attributes = getAttributesFromClass(className)
            
            hfun = str2func(functionName);
            functionName
            
            mc = meta.class.fromName(functionName);
            if ~isempty(mc)
                tic
                allPropertyNames = {mc.PropertyList.Name};
                mConfig = struct;
                propertyNames = {'BatchMode', 'IsManual', 'IsQueueable'};
                for i = 1:numel(propertyNames)
                    thisName = propertyNames{i};
                    isMatch = strcmp(allPropertyNames, propertyNames{i});
                    mConfig.(thisName) = mc.PropertyList(isMatch).DefaultValue;
                end
                toc
            end
            
            try
                tic;mConfig = hfun();toc % Call with no input should give configs
            catch % Get defaults it there are no config:
                mConfig = nansen.session.SessionMethod.setAttributes();
            end
            
            
            
        end
        
    end
        
    methods (Static, Access = private)
        
        function name = getCallingFunction()

            % Skip two first entries (current function and class
            % method that requests caller)
            st = dbstack(2, '-completenames');
            
            if isempty(st)
                name = '';
                return
            end

            % Determine the full name (including package prefixes) for the
            % calling function
            fullFilepath = st(1).file;
            splitFilePath = strsplit(fullFilepath, filesep);

            isPackage = strncmp(splitFilePath, '+', 1);
            folderNames = strrep(splitFilePath, '+', '');
            
            name = strjoin( [folderNames(isPackage), {st(1).name} ], '.');

        end
        
    end
        

        
end