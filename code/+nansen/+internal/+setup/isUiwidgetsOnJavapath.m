function tf = isUiwidgetsOnJavapath()
% isUiwidgetsOnJavapath - Check if Widgets Toolbox jar dependency is on the
%   static java path.
    
    if exist('widgetsRoot', 'file') == 2
        jarFilePath = fullfile( widgetsRoot, 'resource', ...
                                'MathWorksConsultingWidgets.jar' );
                            
        spath = javaclasspath('-static');
        tf = any( contains(spath, jarFilePath) );
    else
        error('NANSEN:WigetsToolboxNotFound', ...
            'The Widgets Toolbox was not found. Run nansen.install or add the Widgets Toolbox to MATLAB''s savepath.')
    end
end