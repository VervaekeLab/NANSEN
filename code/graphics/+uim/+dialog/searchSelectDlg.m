function selection = searchSelectDlg(options, title)
    arguments
        options
        title (1,1) string = "Select value"
    end
    h = uim.dialog.uiSearchSelect(options, title);
    uiwait(h);

    selection = h.Selection;
    delete(h);
end
