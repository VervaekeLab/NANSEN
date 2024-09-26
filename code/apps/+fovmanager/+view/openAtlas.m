function hFigure = openAtlas(varargin)
%fovmanager.view.openAtlas Open figure with map of dorsal cortical surface
%
%   hFigure = fovmanager.view.openAtlas() opens the figure and returns the
%   figure handle

%   Todo: add saggittal maps. 
%   Add lambda and bregma
%

    % make into a class? Should we return th figure, or the axes / panel
    % containing axes. Ie make it a module that can either be placed in a
    % figure or in a fovmanager.App instance....????

    param = struct();
    param.AtlasName = 'paxinos'; % allen is not implemented yet

    
    if ~isempty(varargin) && isa(varargin{1}, 'char')
        validatestring(varargin{1}, {'Visible', 'Invisible'}, ...
            'First argument must be either Visible or Invisible');
    end

      
    % Version were we are agnostic to package name
    pkgFolderPath = utility.path.getAncestorDir( mfilename('fullpath'), 2);
    atlasFolderPath = fullfile(pkgFolderPath, 'resources', 'brain_atlas');
    
    % Version were we know package name but local path is centrally hardcoded.
    atlasFolderPath = fovmanager.localpath( 'brain_atlas' );
    
    
    loadPath = fullfile(atlasFolderPath, param.AtlasName, 'dorsal_map.fig');
    hFigure = openfig(loadPath, varargin{:});

    if ~nargout
        clear hFigure
    end
    
end