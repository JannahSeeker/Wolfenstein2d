function renderShutdown()
%renderShutdown Shuts down the custom rendering engine and closes the window.
%
%   renderShutdown()
%
%   See also renderInit.

    try
        % Call the MEX function with the 'shutdown' command
        renderMex('shutdown');
    catch ME
        warning('renderShutdown:FailedToCallMEX', ...
                'Failed to call renderMex function for "shutdown": %s', ME.message);
    end
end