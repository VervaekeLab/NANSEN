classdef AppPage
    enumeration
        DatasetExplorer ("Dataset Explorer")
        FileViewer      ("File Viewer")
        TaskProcessor   ("Task Processor")
        % DataViewer      ("Data Viewer") % Not implemented yet
    end
    properties
        Label
    end
    methods
        function obj = AppPage(label)
            obj.Label = label;
        end
    end
end
