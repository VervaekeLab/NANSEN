function tf = isUuid(value)
    pattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
    tf = ~isempty(regexp(value, pattern, 'once'));
end
