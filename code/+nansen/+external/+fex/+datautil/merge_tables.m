function tMergedTable = merge_tables(varargin)

% FUNCTION merge_tables - Merge two tables together, with differing variables
%
% Usage: tMergedTable = merge_tables(table1, table2, ...)

% -- Check input arguments

% Function is reused from the brain observatory toolbox:
% https://www.mathworks.com/matlabcentral/fileexchange/90900-brain-observatory-toolbox


if nargin < 1
   help bot.internal.merge_tables;
   error('BOT:Usage', 'Incorrect usage');
end

% - Check that inputs are tables
for arg = varargin
   if ~istable(arg{1})
      error('BOT:Usage', 'All input arguments must be tables');
   end
end

% -- Collect all variable names

cTables = varargin;
cstrVariableNames = {};
vbIsCellVarDest = logical([]);
vbIsStructVarDest = logical([]);


% - Loop over tables
for nTable = numel(cTables):-1:1
   % - Build list of variable names
   [cstrVariableNames, ~, ib] = union(cstrVariableNames, cTables{nTable}.Properties.VariableNames, 'stable');
   [~, vnVarsThisTable] = ismember(cTables{nTable}.Properties.VariableNames, cstrVariableNames);
   
   % - Build logical vector of which destination variables are cell and struct variables
   vbIsCellVarDest = [vbIsCellVarDest, varfun(@iscell, cTables{nTable}(1, ib), 'OutputFormat', 'uniform')]; %#ok<AGROW>
   vbIsStructVarDest = [vbIsStructVarDest, varfun(@isstruct, cTables{nTable}(1, ib), 'OutputFormat', 'uniform')]; %#ok<AGROW>
   
   % - Record which source variables are cells
   cvbIsCellVarSource{nTable} = varfun(@iscell, cTables{nTable}(1, :), 'OutputFormat', 'uniform');
   vbIsCellVarDest(vnVarsThisTable) = vbIsCellVarDest(vnVarsThisTable) | cvbIsCellVarSource{nTable};
   
   % - Record which source variables are structs
   cvbIsStructVarSource{nTable} = varfun(@isstruct, cTables{nTable}(1, :), 'OutputFormat', 'uniform');
   vbIsStructVarDest(vnVarsThisTable) = vbIsStructVarDest(vnVarsThisTable) | cvbIsStructVarSource{nTable};
end

% - Ensure index variables are `logical`
vbIsCellVarDest = logical(vbIsCellVarDest);
vbIsStructVarDest = logical(vbIsStructVarDest);

% - Loop over tables and add variables one by one
for nTable = numel(cTables):-1:1
   % - Find missing variables in this table
   cstrMissingVariables = setdiff(cstrVariableNames, cTables{nTable}.Properties.VariableNames);

   % - Build cell array of missing values
   cMissing = num2cell(nan(size(cTables{nTable}, 1), numel(cstrMissingVariables)));
   [~, locb] = ismember(cstrMissingVariables, cstrVariableNames);
   
   % - Should any of these variables be empty cells?
   cMissing(:, vbIsCellVarDest(locb)) = {{''}};

   % - Should any of these variables be empty structs?
   cMissing(:, vbIsStructVarDest(locb)) = {struct()};
   
   % - Build a cell array of table contents
   cContents = table2cell(cTables{nTable});
   
   % - Check whether any variables need to be converted to cell arrays
   [~, vnVarsThisTable] = ismember(cTables{nTable}.Properties.VariableNames, cstrVariableNames);
   vbConvertVars = vbIsCellVarDest(vnVarsThisTable) & ~cvbIsCellVarSource{nTable};
   
   % - Convert contents to cell arrays
   cContents(:, vbConvertVars) = cellfun(@(c){{c}}, cContents(:, vbConvertVars));
   
   % - Add missing variables
   cContents = [cContents cMissing]; %#ok<AGROW>
   
   % - Convert back to a table
   cTables{nTable} = cell2table(cContents, 'VariableNames', [cTables{nTable}.Properties.VariableNames cstrMissingVariables']);
end

% - Concatenate all tables
tMergedTable = vertcat(cTables{:});
