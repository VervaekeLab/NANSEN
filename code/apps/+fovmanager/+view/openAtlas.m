function hFigure = openAtlas(atlasName, options)
%fovmanager.view.openAtlas Open figure with map of dorsal cortical surface
%
%   hFigure = fovmanager.view.openAtlas() opens the figure and returns the
%   figure handle

    arguments
        atlasName (1,1) string {mustBeMember(atlasName, "paxinos")} = "paxinos" % allen is not implemented yet
        options.Visibility (1,1) string {mustBeMember(options.Visibility, ["visible", "invisible"])} = "visible"
    end

%   Todo: 
%   - Add saggittal maps.
%   - Add lambda and bregma

    % make into a class? Should we return the figure, or the axes / panel
    % containing axes. I.e. make it a module that can either be placed in a
    % figure or in a fovmanager.App instance....????

    % Version were we are agnostic to package name. Todo: clean up
    % pkgFolderPath = utility.path.getAncestorDir( mfilename('fullpath'), 2);
    % atlasFolderPath = fullfile(pkgFolderPath, 'resources', 'brain_atlas');
    
    % Version were we know package name but local path is centrally hardcoded.
    atlasFolderPath = fovmanager.localpath( 'brain_atlas' );
    
    loadPath = fullfile(atlasFolderPath, atlasName, 'dorsal_map.fig');
    hFigure = openfig(loadPath, options.Visibility);

    if ~nargout
        clear hFigure
    end
end
