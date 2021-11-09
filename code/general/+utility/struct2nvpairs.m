function nvPairs = struct2nvpairs(S)
%struct2nvpairs Convert struct to cell array of name-value pairs

if isempty(S); nvPairs = {}; return; end

names = fieldnames(S);
values = struct2cell(S);

nvPairs = reshape( cat(1, names', values'), 1, [] );

end