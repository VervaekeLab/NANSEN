function data = read(filename, varargin)
%read Read test fixture MAT file as table.

    S = load(filename, varargin{:});
    data = struct2table(S);
end
