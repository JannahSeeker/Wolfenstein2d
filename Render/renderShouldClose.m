function closeFlag = renderShouldClose()
%renderShouldClose Checks if the renderer window should close.
%
%   CLOSEFLAG = renderShouldClose() returns true if the user requested
%   to close the window (e.g., clicked the X button), false otherwise.
%
%   See also renderInit.

    try
        % Call the MEX function with the 'shouldClose' command
        closeFlag = renderMex('shouldClose');
    catch ME
        warning('renderShouldClose:FailedToCallMEX', ...
                'Failed to call renderMex function for "shouldClose": %s', ME.message);
        % Default to closing if the call fails to prevent infinite loops
        closeFlag = true;
    end
end