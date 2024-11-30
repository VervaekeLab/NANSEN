classdef OptionsAdapter < handle
%OptionsAdapter Adapter for toolbox options
%
%   Superclass that defines properties and methods that are required for an
%   OptionsAdapter subclass.
%
%   An OptionsAdaper class should define an options struct with clear names
%   that can be inputted to the struct editor app. It should also convert
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
        S = convert(S)              % For conversion to toolbox options
        
        %S = getAdapter()            % Adapter for converting options to toolbox names.
        
    end
    
    methods

        function S = get.Options(obj)
            S = obj.getOptions();
        end
    end
    
    methods (Static)
        
        function SOut = rename(S, nameMap, outputFormat)
            
            if nargin < 3|| isempty(outputFormat)
                outputFormat = 'struct'; % vs nvpairs
            end
            
            % Get fieldnames recursively and find intersection
            fieldsOpts = fieldnamesr(S, 2);
            fieldsNames = fieldnamesr(nameMap);
            
            C = intersect(fieldsOpts, fieldsNames);

            switch outputFormat
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
                    
                    % Todo: O
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
    end
end
