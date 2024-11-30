classdef FolderType

    % First draft for folder types:
    % Should be used by the DataLocationModel

    enumeration
        Session('Session')
        Subject('Subject')
        Date('Date')
        Recording('Recording') % Alternative interpretations: trial, epoch
    end

    properties
        Name
        Description
    end

    methods
        function obj = FolderType(name)

            obj.Name = name;

            switch name

                case 'Session'
                    obj.Description = ...
                        "A folder containing data from a single recording or a set of recordings performed within an uninterrupted time period";

                case 'Subject'
                    obj.Description = ...
                        "A folder containing one or multiple sessions or recordings from one individual research animal being studied in an experiment";

                case 'Date'
                    obj.Description = ...
                        "A folder containing data from a single or multiple recording(s) or session(s) performed within one day";

                case 'Recording'
                    obj.Description = ...
                        "A folder containing data from one single continuous recording.";

                case 'Other'
                    obj.Description = ...
                        "A folder containing any other type of elements.";

            end
        end
    end
end
