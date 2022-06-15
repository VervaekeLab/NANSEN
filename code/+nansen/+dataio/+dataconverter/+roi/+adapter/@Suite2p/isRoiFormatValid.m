function tf = isRoiFormatValid(filepath, data)

    if nargin < 2
        S = load(filepath);
    end
    
    tf = false;
    [~, name, ~] = fileparts(filepath);

    if strcmp(name, 'stat')
        if isa(data, 'cell')
            if isa(data{1}, 'struct')
                fieldnamesS2p = {'compact', 'med', 'lam', 'skew'}';
                if all(ismember(fieldnamesS2p, fieldnames(data{1})))
                    tf = true;
                end
            end
        end
    else
        if all( isfield(data, {'stat', 'ops', 'iscell'}) )
            tf = true;
        end
        
        % What if someone renamed their files...?
    end
end