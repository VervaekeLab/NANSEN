function ensureEntityTableOnPath()
%ensureEntityTableOnPath Ensure the R2025+ table component is available.

    if isEntityTableAvailable()
        return
    end

    candidatePaths = getCandidatePaths();
    for i = 1:numel(candidatePaths)
        thisPath = normalizeCandidatePath(candidatePaths{i});
        if isempty(thisPath) || ~isfolder(thisPath)
            continue
        end

        addpath(thisPath)
        rehash()
        if isEntityTableAvailable()
            return
        end
    end

    error('NANSEN:MissingEntityTable', ...
        ['The R2025a+ metadata table backend requires entity-table. ', ...
         'Install https://github.com/ehennestad/entity-table or add its ', ...
         'src/entitytable folder to the MATLAB path.'])
end

function tf = isEntityTableAvailable()
    tf = exist('entitytable.EntityTableView', 'class') == 8 || ...
        ~isempty(which('entitytable.EntityTableView'));
end

function candidatePaths = getCandidatePaths()
    nansenRoot = fileparts(nansen.toolboxdir());
    matlabRoot = findAncestorNamed(nansenRoot, 'MATLAB');

    candidatePaths = { ...
        getenv('ENTITY_TABLE_PATH'), ...
        fullfile(userpath(), 'NANSEN', 'Requirements', 'entity-table'), ...
        fullfile(nansenRoot, 'external', 'entity-table'), ...
        fullfile(fileparts(nansenRoot), 'entity-table') ...
        };

    if ~isempty(matlabRoot)
        candidatePaths{end+1} = fullfile(matlabRoot, ...
            'General', 'Repositories', 'ehennestad', 'entity-table');
    end
end

function folderPath = normalizeCandidatePath(folderPath)
    if isempty(folderPath)
        return
    end

    if isfolder(fullfile(folderPath, '+entitytable'))
        return
    end

    if isfolder(fullfile(folderPath, 'src', 'entitytable', '+entitytable'))
        folderPath = fullfile(folderPath, 'src', 'entitytable');
    elseif isfolder(fullfile(folderPath, 'src', '+entitytable'))
        folderPath = fullfile(folderPath, 'src');
    end
end

function ancestorPath = findAncestorNamed(folderPath, folderName)
    ancestorPath = '';
    while ~isempty(folderPath)
        [parentPath, name] = fileparts(folderPath);
        if strcmp(name, folderName)
            ancestorPath = folderPath;
            return
        end
        if strcmp(parentPath, folderPath)
            return
        end
        folderPath = parentPath;
    end
end
