
function sid = strfindsid(str)

sidExpr = {'m\d{4}-\d{8}-\d{4}-\d{3}', 'm\d{4}-\d{8}-\d{2}', 'm\d{4}_\d{8}_\d{2}'};

for i = 1:numel(sidExpr)
    sid = regexp(str, sidExpr{i}, 'match', 'once');
    if ~isempty(sid)
        return
    end
end
