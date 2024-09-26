function ME = getException(errID, varargin)
%nansen.stack.getException Get exception related to image stack objects

params = struct();
params.InputNumber = 1;

params = utility.parsenvpairs(params, [], varargin);

switch errID

    case 'NANSEN:InvalidImageStackInput'

        if params.InputNumber == 1
            msg = ['First argument must be an ImageStack object', ...
                ' or a variable that can create an ImageStack object.'];
        elseif params.InputNumber == 2
            msg = ['Second argument must be an ImageStack object', ...
               ' or a variable that can create an ImageStack object.'];
        else
            msg = sprintf( ['Expected input #%d to be an ImageStack object', ...
               ' or a variable that can create an ImageStack object.'], ...
               params.InputNumber );
        end
        
    case 'NANSEN:Stack:InvalidImageStack'
        msg = 'Image data must be a numeric array or an ImageStack object';

end

ME = MException(errID, msg);

end
