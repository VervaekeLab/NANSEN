% MetadataEntity - Base class for a metadata entity definition.
%
% Properties are metadata info.
%
% Convert to/from struct
% Convert to/from table
%
% A MetaTable is a table of metadata objects which must derive from this
% MetadataEntity class.
%
% Todo: Clarify this..
% When a metadata object is picked from the table it is transformed to an
% object. The object provides methods for updating/plotting
%
%   See also MetaTable

classdef MetadataEntity < ...
        dynamicprops & ...
        nansen.util.StructAdapter & ...
        nansen.metadata.mixin.HasNotes

%   Todo
%       [ ] Add methods for interacting with a metatable?

    properties (Abstract, Constant, Hidden)
        ANCESTOR
        IDNAME
    end

    properties (Transient, SetAccess = immutable, GetAccess = protected)
        IsConstructed = false
    end
    
    events
        PropertyChanged
    end
    
    methods % Constructor
        function obj = MetadataEntity(varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'table')
                obj = obj.constructFromTable(varargin{1});
                [obj.IsConstructed] = deal(true);
            end

            % Todo: scalar vs non-scalar construction...
        end
    end

    methods
        function addDynamicTableVariables(obj, options)
        % addDynamicTableVariables - Add dynamic variable to entity object(s)

            arguments
                obj nansen.metadata.abstract.MetadataEntity
                options.UpdateValue (1,1) logical = true
            end

            dynamicVariables = obj.getDynamicVariables();
            dynamicVariableNames = string( dynamicVariables.Name );

            for iVar = 1:numel(dynamicVariableNames)
                thisVariableName = dynamicVariableNames(iVar);

                if all( isprop(obj, thisVariableName{1}) ); continue; end

                needsProp = ~isprop(obj, thisVariableName);
                if options.UpdateValue && dynamicVariables.HasUpdateFunction(iVar)
                    
                    % Todo: update for all items of the metatable
                    updateFcnName = dynamicVariables.UpdateFunctionName{iVar};
                    
                    [propertyValue, wasFound] = obj.getDynamicVariableValue(thisVariableName, updateFcnName);
                    [propertyValue{~wasFound}] = deal( dynamicVariables.NullValue{iVar} );
                else
                    propertyValue = dynamicVariables.NullValue{iVar};
                end

                obj(needsProp).createDynamicProperty(thisVariableName, propertyValue)
            end
        end

        function updateDynamicVariable(obj, variableName)
            dynamicVariables = obj.getDynamicVariables();
            dynamicVariableNames = string( dynamicVariables.Name );

            iVar = find(strcmpi(dynamicVariableNames, variableName));
            assert(~isempty(iVar), ...
                'NANSEN:MetadataEntity:DynamicVariableNotFound', ...
                ['This object does not have a dynamic variable with name ' ...
                '"%s". Available variables:\n%s\n'], ...
                variableName, ...
                strjoin(" - " + dynamicVariableNames, newline))

            if dynamicVariables.HasUpdateFunction(iVar)
                    
                updateFcnName = dynamicVariables.UpdateFunctionName{iVar};
                
                [propertyValue, ~] = obj.getDynamicVariableValue(variableName, updateFcnName);
                
                for i = 1:numel(obj)
                    % Use private setter to bypass protected SetAccess
                    obj.setDynamicPropertyValue(variableName, propertyValue)
                end
            else
                error('NANSEN:MetadataEntity:UpdateFunctionMissing', ...
                    'The variable "%s" does not have an update function', ...
                    variableName)
            end
        end
    end

    methods (Access = private)
        function value = getType(obj)
            fullClassname = class(obj);
            splitClassName = strsplit(fullClassname, '.');
            value = splitClassName{end};
        end

        function dynamicVariables = getDynamicVariables(obj)
        % getDynamicVariables - Get dynamic variables for entity type
            entityType = obj.getType();

            currentProject = nansen.getCurrentProject();
            variableAttributes = currentProject.getTable('TableVariable');
            disp(variableAttributes)
            
            keep = variableAttributes.TableType == lower(entityType) ...
                & variableAttributes.IsCustom;

            dynamicVariables = variableAttributes(keep, :);
        end
    
        function [result, hasResult] = getDynamicVariableValue(obj, variableName, functionName, options)
            
            arguments
                obj nansen.metadata.abstract.MetadataEntity
                variableName (1,1) string
                functionName (1,1) string
                options.ProgressMonitor = [] % Todo: waitbar class?
                options.MessageDisplay = [] % Constrain to message display
            end
        
            hasResult = false(1, numel(obj));
            hasWarned = false;

            % Todo: Should be a function in the tablevar function
            %updateFunction = obj.getTableVariableUpdateFunction(variableName);
            
            updateFunction = str2func(functionName);
            defaultValue = updateFunction();

            % Character vectors should be in a scalar cell
            if isequal(defaultValue, {'N/A'}) || isequal(defaultValue, {'<undefined>'}) 
                expectedDataType = 'character vector or a scalar cell containing a character vector';
            else
                expectedDataType = class(defaultValue);
            end

            warnState = warning('backtrace', 'off');
            warningCleanup = onCleanup(@() warning(warnState));
            
            numEntities = numel(obj);
            result = cell(numEntities, 1);

            for iEntity = 1:numEntities
                try
                    newValue = updateFunction(obj(iEntity));

                    if isa(newValue, 'nansen.metadata.abstract.TableVariable')
                        newValue = newValue.Value; % Unpack value from class object
                    end

                    [isValid, newValue] = ...
                        nansen.metadata.tablevar.validateVariableValue(...
                            defaultValue, newValue);
                    
                    if isValid
                        hasResult(iEntity) = true;
                        result{iEntity} = newValue;
                    else
                        if ~hasWarned
                            warningMessage = sprintf(...
                                ['The table variable function returned ', ...
                                'something unexpected.\nPlease make sure ', ...
                                'that the table variable function for "%s" ', ...
                                'returns a %s.'], varName, expectedDataType);
                            if ~isempty(options.MessageDisplay)
                                options.MessageDisplay.warn(warningMessage, 'Title', 'Update failed')
                            end
                            hasWarned = true;
                            %MEInvalid = MException('Nansen:TableVar:WrongType', warningMessage);
                        end
                    end
                catch ME
                    warning(ME.identifier, ...
                        'Failed to update variable "%s". Reason:\n%s\n', ...
                        variableName, ME.message)
                end

                if ~isempty(options.ProgressMonitor)
                    waitbar(iEntity/numEntities, options.ProgressMonitor)
                end
            end
        end
    
        function setDynamicPropertyValue(obj, variableName, propertyValue)
            % Need to temporarily make SetAccess public, because a super
            % class does not have access to set properties of subclasses
            % with properties that has SetAccess = protected.
            P = obj.findprop(variableName);
            P.SetAccess = 'public';
            accessCleanup = onCleanup(@() resetPropertySetAccess(P)); 
            obj.(variableName) = propertyValue;
        end
    end
    
    methods (Access = private)
        function obj = constructFromTable(obj, metaTable)
        %constructFromTable Construct object(s) from meta table
        %
        %   metaObj.constructFromTable(metaTable) constructs a vector of
        %   objects from a table
        
        %   Note: Need to return obj, because this function might change
        %   the size of obj.
        
            % Initialize array of objects
            numObjects = size(metaTable, 1);
            obj(numObjects) = feval(class(obj));

            % Assign object properties from meta table
            obj = obj.fromTable(metaTable);
        end
    
        function initializeDynamicProperty(obj, propName, nullValue)
        % initializeDynamicProperty - Method for initializing a dynamic property
            P = obj.addprop(propName);
            assert(isscalar(nullValue), 'Expected null value to be scalar.')
            [obj(:).(propName)] = deal(nullValue);

            % Dynamic props must only be set from within the class
            [P.SetAccess] = deal('protected');
        end

        function createDynamicProperty(obj, propName, propertyValues)
        % createDynamicProperty - Helper method to create dynamic properties

            arguments
                obj nansen.metadata.abstract.MetadataEntity
                propName (1,1) string
                propertyValues (1,:) cell
            end
            
            if ~isscalar(obj) && isscalar(propertyValues)
                % Expand if value is scalar
                propertyValues = repmat(propertyValues, 1, numel(obj));
            end

            assert(numel(obj) == numel(propertyValues), ...
                'Property values must be same length as array of entity objects.')

            P = obj.addprop(propName);
            for i = 1:numel(obj)
                obj(i).(propName) = propertyValues{i};
            end
            
            % Dynamic props must only be set from within the class
            [P.SetAccess] = deal('protected');
        end
    end

    methods % Methods for retyping
        
        function fromStruct(obj, S)
            
            assert(numel(obj) == numel(S), ...
                'NANSEN:MetadataEntity:WrongStructLength', ...
                'Input structure must be the same length as the object')
            
            propertyNames = fieldnames(S);
            
            for jProp = 1:numel(propertyNames)
                thisPropertyName = propertyNames{jProp};

                if isprop(obj, propertyNames{jProp})
% %                     for i = 1:numObjects
% %                         obj(i).(propertyNames{jProp}) = S(i).(propertyNames{jProp});
% %                     end
                    try
                        [obj.(thisPropertyName)] = S.(thisPropertyName);
                    catch ME
                        switch ME.identifier
                            case "MATLAB:class:SetProhibited"
                                % Silently ignore
                                % Todo: Need a strategy for this case
                            otherwise
                                warning('Could not set property %s', thisPropertyName)
                        end
                    end
                else
                    propertyValues = {S.(thisPropertyName)};
                    obj.createDynamicProperty(thisPropertyName, propertyValues)
                end
            end
        end
        
        function S = toStruct(obj)
        %TOSTRUCT Convert object to a struct.
            S = toStruct@nansen.util.StructAdapter(obj);
        end

        function T = makeTable(obj)
            
            for i = 1:numel(obj)
                if i == 1
                    S = obj(i).toStruct();
                else
                    S(i) = obj(i).toStruct();
                end
            end
            
            T = struct2table(S, 'AsArray', true);
        end
        
        function obj = fromTable(obj, dataTable)
           
            S = table2struct(dataTable);
            numObjects = numel(S);
            obj(numObjects) = feval(class(obj));
            
            obj.fromStruct(S);
        end
    end
    
    methods (Access = protected)
        function onNotebookPropertySet(obj)
            evtData = obj.getPropertyChangedEventData('Notebook');
            obj.notify('PropertyChanged', evtData)
        end
        
        function evtData = getPropertyChangedEventData(obj, propertyName)
            newValue = obj.(propertyName);
            % Todo: This should either be improved, or documented, i.e why
            % is a struct wrapped in a cell array?
            if isa(newValue, 'struct'); newValue = {newValue}; end
            
            evtData = uiw.event.EventData('Property', propertyName, ...
                'NewValue', newValue);
        end
    end
end

function resetPropertySetAccess(dynamicMetaProp)
    dynamicMetaProp.SetAccess = 'protected';
end
