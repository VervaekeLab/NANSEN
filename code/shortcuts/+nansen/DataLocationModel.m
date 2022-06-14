function dataLocationModel = DataLocationModel()
%nansen.DataLocationModel Interface for managing datalocations of project
%
%   nansen.DataLocationModel opens an app for editing the DataLocationModel
%   of the current project
%
%   h = nansen.DataLocationModel returns an instance of the
%   DataLocationModel of the current project.

    if ~nargout
        nansen.config.dloc.DataLocationModelApp();    
    else
        dataLocationModel = nansen.config.dloc.DataLocationModel();
    end

end