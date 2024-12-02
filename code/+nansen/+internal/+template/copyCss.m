function copyCss(htmlFolder)
    cssFilepath = fullfile(nansen.toolboxdir, 'resources', 'templates', 'helpwin.css');
    copyfile(cssFilepath, htmlFolder)
end