function sortedS = sort(S, fieldName)
%sort Sort a struct by values of a field
    
    T = struct2table(S); % convert the struct array to a table
    sortedT = sortrows(T, fieldName); % sort the table by 'DOB'
    sortedS = table2struct(sortedT); % change it back to struct array if necessary
end