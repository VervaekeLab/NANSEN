classdef OptionsAdapter < handle
%OptionsAdapter Adapter for toolbox options
%
%   Superclass that defines properties and methods that are required for an
%   OptionsAdapter subclass.
%
%   An OptionsAdapter class should define an options struct with clear names
%   that can be inputed to the struct editor app. It should also convert
%   these options to the format required by its corresponding toolbox.

    % Question: 
    %   1.  Why are methods in general static?
    %       So that we can get preset options without creating a class
    %       instance... But what is the benefit???
    %
    %   2.  Why is the getToolboxOptions method static?
    %
    %   3.  Should the Options property provide the default options struct
    %       on demand
    
    
    
    
    properties (Abstract, Constant)
        ToolboxName     % Name of toolbox this options adapter correspond with
        Name            % Name of options (For keeping track of options presets/variations)
        Description     % Description for an option preset/variation
    end
    
    properties (Dependent)
        Options         % A struct of options. Not sure if this should be stored in the class...
    end
    
    
    methods (Abstract, Static)
        S = getOptions()            % For nansen/ui options
        S = getAdapter()            % Adapter for converting options to toolbox names.
        S = convert(S)              % For conversion to toolbox options
    end
    
    methods

        function S = get.Options(obj)
            S = obj.getOptions();
        end
        
    end
    
    methods (Static)
        
        function SOut = rename(S, nameMap, outputFormat)
        %rename Rename fields of options struct
        
            if nargin < 3|| isempty(outputFormat)
                outputFormat = 'struct'; % vs nvpairs
            end
            
            % Get fieldnames recursively and find intersection
            fieldsOpts = fieldnamesr(S, 2);
            fieldsNames = fieldnamesr(nameMap);
            
            C = intersect(fieldsOpts, fieldsNames);

            switch lower(outputFormat)
                case 'struct'
                    SOut = struct();
                    
                    for i = 1:numel(C)

                        subfields = strsplit(C{i}, '.');
                        s = struct('type', {'.'}, 'subs', subfields);
                    
                        name = subsref(nameMap, s);
                        value = subsref(S, s);
                    
                        s = struct('type', {'.'}, 'subs', name);
                        SOut = subsasgn(SOut, s, value);
                        
                    end
                    
                case 'nvpairs'

                    % Collect normcorre parameter names and values in a cell array
                    % of name-value pairs.

                    nvPairs = cell(1, numel(C)*2);
                    for i = 1:numel(C)
                        name = eval(strjoin({'nameMap', C{i}}, '.'));
                        value = eval(strjoin({'S', C{i}}, '.'));
                        ind = (i-1)*2 + (1:2);
                        nvPairs(ind) = {name, value};
                    end
                    SOut = nvPairs;
                    
            end
            
        end

        function S = removeUiSpecifications(S)
            
            fieldNames = fieldnames(S);
            discard = endsWith(fieldNames, '_');
            
            S = rmfield(S, fieldNames(discard));
            
        end
        
        function S = ungroupOptions(S)
        
            SOut = struct();
            
            fieldsTopLevel = fieldnames(S);
            
            for i = 1:numel(fieldsTopLevel)
                if ~isa( S.(fieldsTopLevel{i}), 'struct' )
                    SOut.(fieldsTopLevel{i}) = S.(fieldsTopLevel{i});
                else

                    % Pull config fields out of substructs.
                    configNames = fieldnames(S.(fieldsTopLevel{i}));
                    for j = 1:numel(configNames)
                        SOut.(configNames{j}) = S.(fieldsTopLevel{i}).(configNames{j});
                    end
                end
            end
            
            S = SOut;
            
        end
    end

end