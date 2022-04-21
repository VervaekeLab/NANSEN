function toggleUicontrolLabel(h, strA, strB)
%toggleUicontrolLabel Toggle the text of a uihandle (ie menu item)
%
% Interchange strA and strB in text label of given handle h.
    
    if isempty(h); return; end

    if contains(h.Text, strA)
        h.Text = strrep(h.Text, strA, strB);
    elseif contains(h.Text, strB)
        h.Text = strrep(h.Text, strB, strA);
    else
        error('Text labels are not present, something has gone wrong...')
    end

end