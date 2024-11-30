function installWidgetsToolbox()
    fprintf('Installing Widgets Toolbox v1.3.330...')
    addonUrl = 'https://se.mathworks.com/matlabcentral/mlc-downloads/downloads/b0bebf59-856a-4068-9d9c-0ed8968ac9e6/099f0a4d-9837-4e5f-b3df-aa7d4ec9c9c9/packages/mltbx';
    tempFile = websave(fullfile(tempdir,'temp.mltbx'), addonUrl );
    matlab.addons.install(tempFile);
    delete(tempFile)
    fprintf('Done\n')
end
