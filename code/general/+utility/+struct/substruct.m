function sOut = substruct(sIn, varargin)
%Substruct Create new struct using a subset of fields from original struct
%
%   sOut = substruct(sIn, field1, field2, ..., fieldN) returns a substruct
%   containing the specified fields. 

    if numel(varargin) == 1 && isa(varargin{1}, 'cell')
        fieldNames = varargin{1};
    else
        fieldNames = varargin;
    end

    sOut = struct;
    
    for i = 1:numel(fieldNames)
        if isfield(sIn, fieldNames{i})
            sOut.(fieldNames{i}) = sIn.(fieldNames{i});
        else
            warning('%s is not a field of input struct', fieldNames{i})
        end
    end
    
end

