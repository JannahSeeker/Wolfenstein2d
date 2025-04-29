
function run2d(gs)
% Basic Raycaster Demo using renderMex engine
% Input handling is performed by C++/Raylib via renderGetInputState()
PORT = 5100;
JOY = 999;
SOCKETPORT = 5555;

dt = gs.inputPeriod;    % e.g. 1/100 s per frame
dt = 1/100;

%add players
gs.addPlayer(JOY,PORT);

gs.mapManager.pushMapToFlask("http://localhost:5555")
% --- Main Loop ---
while gs.running
    % 1) Poll & move all players (incl. shooting on rising‐edge)
    gs.updatePlayers(dt);

    % 2) Advance your world logic:
    %    – Update all sprites’ AI
    %    – Handle any pickups or interactions
    gs.updateSprites(dt);

    % 3) Resolve collisions (sprites ↔ players)
    gs.handleSpritePlayerCollisions();

    % 4) Check win/lose conditions

    % 5) Render the top‐down continuous view
    gs.pushToFlask("http://localhost:5555");
    % displayContinuousMap(gs);

    % 6) Frame pacing
    pause(dt);
    % disp("runnign loop");
end

end % function runRaycasterDemo


function displayContinuousMap(gs)
% displayContinuousMap  Draws a top-down continuous view of the map and player
%
%   gs  – game-state struct with gs.mapManager.map and gs.player.position

% Extract map and player
mapData = gs.mapManager.map(:,:,gs.mapManager.currentFloor);

% Create or reuse a figure
figure(1);
clf;  % clear figure

% Draw the map: walls as black, empty as white
imagesc(mapData);
colormap(flipud(gray(2)));  % 0→white, 1→black
hold on;

% Plot all players as red circles
for i = 1:numel(gs.players)
    pp = gs.players(i).position;
    plot(pp(2), pp(1), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
end
% Plot all sprites as black squares
for i = 1:numel(gs.spriteManager.sprites)
    sp = gs.spriteManager.sprites(i).pos;
    plot(sp(2), sp(1), 'ks', 'MarkerSize', 6, 'LineWidth', 1.5);
end
% Configure axes
axis equal tight;
set(gca, 'YDir', 'normal');  % ensure row 1 at top
title(sprintf('Floor %d — Player at [%.2f, %.2f]'));

drawnow;
end