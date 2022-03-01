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
%
%       If class instance is run without output, the class' main
%       method/implementation is run directly.
%
%       If instance is created and output is requested, the class' main
%       method is not initialized, and can be initialized at a later time.


% Preset options/parameters.
%
%   Default / premade 
%   User edited/custom
%       
%   Save as variable - value or variable struct
%       variable = struct('Params', [], 'IsDefault', [])



    % Questions:
    %
    %   Whats the benefits of having alternatives as separate properties as
    %   done in the original implementation in the session browser?
    
    
    % TODO (implemented in options manager):
    % * [ ] Change name of class to SessionTask
    %   [x] methods/functionality for preset options.
    %   [x] append a page in options for saving a preset
    %   [x] create method for getting options based on name.
    
    
% - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - - 
    
    properties (Abstract, Constant)
        %MethodName
        BatchMode               % char      : 'serial' | 'batch'
        %IsQueueable             % logical   : true | false
        % maxAllowedSessions = inf;
        %OptionsManager
    end
    
    
    properties 
        SessionObjects          % Array of session objects
        %Options                 % Todo: Keep only Options or Parameters
        ExternalFcn % remove this...???
        Parameters
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
                obj.Parameters = utility.parsenvpairs(params, [], varargin);
            end
            
            % Call the appropriate run method
            if ~nargout
                obj.run()
                clear obj
            end
            
        end
        
    end
    
    methods
        
        function run(obj)

            % Todo: How to create a sessionMethod instance from a function?
            % Create a subclass??
            if ~isempty(obj.ExternalFcn)
                sessionObjects = obj.SessionObjects;
                params = obj.Parameters;
                
                obj.ExternalFcn(sessionObjects, params)
            else
                obj.runMethod()
            end
        end
        
%         function tf = preview(obj, optsName)
%             % Todo:
%             % How to do this?
%                
%             
%             if nargin == 2 && ~isempty(optsName)
%                 params = obj.OptionsManager.getOptions(optsName);
%             else
%                 params = obj.Parameters;
%             end
%             
%             nvPairs = { 'OptionsManager', obj.OptionsManager };
%             params = tools.editStruct(params, nan, '', nvPairs{:} );
%             
%             tf = true;
%         end
        
        function setup(obj)
                        
            obj.Parameters = tools.editStruct(obj.Parameters);
            
        end
        
        function usePreset(obj, presetName)
            obj.Parameters = obj.OptionsManager.getOptions(presetName);
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
            
            % Fields of output struct with defaults.
            S.BatchMode = 'serial';
            S.IsQueueable = true;
            
            % Pick out default options from inputs or init to empty struct
            if ~isempty(varargin) && isstruct(varargin{1})
                defaultOpts = varargin{1};
                varargin = varargin(2:end);
            else
                defaultOpts = struct();
            end
            
            S.DefaultOptions = defaultOpts;
         
            
            % Make sure that varargin only contains character vectors
            isChar = cellfun(@(c) ischar(c), varargin);
            assert(all(isChar), 'Non-character inputs are not allowed')
            
            
            % Set the attributes based on keywords from varargin
            if contains('serial', varargin)
                S.BatchMode = 'serial';
            end
            
            if contains('batch', varargin)
                S.BatchMode = 'batch';
            end
            
            if contains('queueable', varargin)
                S.IsQueueable = true;
            end
            
            if contains('unqueueable', varargin)
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