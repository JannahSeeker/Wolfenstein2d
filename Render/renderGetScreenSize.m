function [width, height] = renderGetScreenSize()
%renderGetScreenSize Gets the current dimensions of the rendering window.
%
%   [WIDTH, HEIGHT] = renderGetScreenSize() returns the current width
%   and height of the window managed by the rendering engine. Returns
%   [0, 0] if the call fails.
%
%   Example: [w, h] = renderGetScreenSize;
%            disp(['Window size: ', num2str(w), 'x', num2str(h)]);
%
%   See also renderInit.

    width = 0;
    height = 0;
    try
        % Call the MEX function with the 'getScreenSize' command
        % Expects a 1x2 row vector [width, height]
        sizeVec = renderMex('getScreenSize');
        if numel(sizeVec) == 2
            width = sizeVec(1);
            height = sizeVec(2);
        else
            warning('renderGetScreenSize:UnexpectedOutput', ...
                    'renderMex for "getScreenSize" did not return a 1x2 vector.');
        end
    catch ME
        warning('renderGetScreenSize:FailedToCallMEX', ...
                'Failed to call renderMex function for "getScreenSize": %s', ME.message);
        width = 0; % Ensure failure values on error
        height = 0;
    end
end