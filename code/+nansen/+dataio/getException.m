function ME = getException(errID, varargin)
%nansen.stack.getException Get exception related to image stack objects

params = struct();
params.InputNumber = 1;

params = utility.parsenvpairs(params, [], varargin);

switch errID

    case 'Nansen:IOModel:WrongInput'
        msg = 'Expected input to be a file- or a folderpath';
    
    case 'Nansen:IOModel:FileNotFound'
        msg = 'The input file does not exist';
end

ME = MException(errID, msg);

end