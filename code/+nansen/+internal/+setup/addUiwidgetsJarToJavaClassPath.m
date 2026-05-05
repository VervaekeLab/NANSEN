function addUiwidgetsJarToJavaClassPath()

    jarFilePath = fullfile( widgetsRoot, 'resource', ...
                            'MathWorksConsultingWidgets.jar' );
                        
    wasSuccess = nansen.internal.setup.java.addFilepathToStaticJavapath(jarFilePath);

    if ~wasSuccess
        error('Failed to add the Widgets Toolbox'' Java Archive to the static javapath')
    end

    % Since matlab has to be restarted before changes to
    % the static Java class path take effect, the path is
    % added to the dynamic path here if its not already on
    % the static javapath
    spath = javaclasspath('-static');
    if ~any( contains(spath, jarFilePath) )
        nansen.internal.setup.java.addFilepathToDynamicJavapath(jarFilePath)
    end
end
