classdef HasOptions < handle
%nansen.mixin.HasOptions Mixin to provide options for a class based method
%
%   This class provides an interface for classes that represent an
%   algorithm which is dependent on a set of options/parameters.
%
%   Options can be edited interactively, and edited options can be saved as
%   presets and retrieved at a later time using an OptionsManager object.
%   The OptionsManager is implemented as an abstract, constant method.
%   Therefore, any class that inherits this mixin must assign the
%   OptionsManager in the class definition.
%
%   If a subclass which implement this mixin does not assign options,
%   explicitly, the get method for options will return the default options
%   from the OptionsManager.
%
%   EXAMPLES
%       hAlgorithm = subclassInheritingHasOptions()
%
%       % Retrieve options:
%       opts = hAlgorithm.Options
%
%       % Open dialog to edit options:
%       hAlgorithm.editOptions()

%   - - - - - - - - - - - - - SUBCLASSING - - - - - - - - - - - - -
%
%   Any subclass MUST implement:
%       OptionsManager (Constant property)
%
%   Any subclass SHOULD implement:
%       options = getDefaultOptions() (Static method)

%   - - - - - - - - - - - - - - NOTES - - - - - - - - - - - - - - -
%
%   Notes on implementation: The OptionsManager is implemented as a
%   "singleton" for each instance of a subclass (algorithm). This might not
%   be a good idea, but I'll let the programming oracle be the judge of
%   that. The shortterm benefit is that available options for an algorithm
%   can be retrieved without creating an object of the class, and the
%   options manager only needs to be constructed once. One drawback happens
%   during development, if e.g default options are changed, it will not
%   register with the optionsmanager until the next clear all/clear classes

%   TODO:
%   [ ] Edit options method, or use optionsmanager?
%  *[ ] Create a method for detecting options from varargin and assigning
%       to the options property (to be used in a subclass constructor). 
%   [ ] 

%   QUESTIONS
%   [ ] How to deal with options names which are necessary for storing and
%       retrieving preset options
%
%   [ ]
    
    properties (Abstract, Constant)
        OptionsManager nansen.manage.OptionsManager
    end
    
    properties (Dependent)
        OptionsName   % here or options manager?
        Options       %
    end
    
    properties (Access = protected)
        Options_    %
    end
    
    methods (Static)
        function options = getDefaultOptions(className) % Subclasses should override
        %getDefaultOptions Method to provide the default options.
        %
        %   Any algorithm that requires options must override this method
        %   and provide a struct containing fields and values representing
        %   the parameter names and values.
            if nargin < 1 || isempty(className)
                options = struct.empty;
            else
                
                S = nansen.wrapper.suite2p.Options.getDefaults();
                options = S;
    
                superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
                options = nansen.mixin.HasOptions.combineOptions(options, superOptions{:});
            end
        end
    end
    
    methods % Public methods
        
        function [optsStruct, wasAborted] = editOptions(obj)
            
             args = {};
% % %             if ~isempty(obj.Options)
% % %                 args = [args, obj.Options];
% % %             end
% % %
% % % %             if ~isempty(obj.OptionsName)
% % % %                 args = [obj.OptionsName, args];
% % % %             else
% % %                 if ~isempty(args)
% % %                     args = ['Custom', args];
% % %                 end
% % % %             end
            
            [~, optsStruct, wasAborted] = obj.OptionsManager.editOptions(args{:});
            obj.Options_ = optsStruct;
            
            if ~nargout
                clear optsStruct wasAborted
            elseif nargout == 1
                clear wasAborted
            end
        end
    end
    
    methods % Set/get methods
        
        function set.Options(obj, opts)
            obj.Options_ = opts;
        end
        
        function opts = get.Options(obj)
            if ~isempty(obj.Options_)
                opts = obj.Options_;
            elseif ~isempty(obj.OptionsManager)
                opts = obj.OptionsManager.Options;
            end
        end
    end
    
    methods (Access = protected)
        
        function opts = checkArgsForOptions(obj, varargin)
            
            isStruct = cellfun(@isstruct, varargin);
            
            if any(isStruct)
                opts = varargin{ find(isStruct, 1) };
                defaultOpts = obj.OptionsManager.getOptions();
                
                isValidOpts = isequal(fieldnames(opts), fieldnames(defaultOpts));
                if isValidOpts
                    obj.Options_ = opts;
                end
            end
            
            if ~nargout
                clear opts
            end
        end
    end
    
    methods (Static, Sealed)%, Access = protected)
        
        function options = getSuperClassOptions(className)
        %getSuperClassOptions Get default options from all superclasses
            if nargin < 1
                className = mfilename('class');
            end
            
            mc = meta.class.fromName(className);
            superClassNames = {mc.SuperclassList.Name};
            
            numSuperClasses = numel(superClassNames);
            options = {};
            
            for i = 1:numSuperClasses
                iClassName = superClassNames{i};
                getOptsFcn = str2func([iClassName, '.getDefaultOptions']);
                try
                    options = [options, getOptsFcn()];
                end
                
                options = [options, nansen.mixin.HasOptions.getSuperClassOptions(iClassName)];
                
            end
        end
        
        function options = combineOptions(options, varargin)
            for i = 1:numel(varargin)

                fields = fieldnames(varargin{i});

                for j = 1:numel(fields)
                    if isfield(options, fields{j}) && ...
                            isa(options.(fields{j}), 'struct')
                        
                        options.(fields{j}) = utility.struct.mergestruct(...
                            options.(fields{j}), varargin{i}.(fields{j}) );
                    else
                        options.(fields{j}) = varargin{i}.(fields{j});
                    end
                end
            end
        end
    end
end
