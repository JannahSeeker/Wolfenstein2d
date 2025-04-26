classdef MapManager < handle
    %MAPMANAGER  Builds a 3D tile map and stores floor info.
    properties
        map           uint8       % H×W×F 3D tile codes
        height        double      % H
        width         double      % W
        currentFloor  double      = 1
        elevators     double      % N×3 array of [x,y,z]
        chests              % M×3 array of [x,y,z]
        keyManager    struct      % simple struct for key
        gs GameState
    end

    methods
        function obj = MapManager(gs)
            % Define one floor layout (0=empty,1–4=wall types)
            baseFloor = [
                1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,1,1,0,0,0,2,2,0,0,0,0,0,1;
                1,0,0,1,0,0,0,0,2,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,3,3,3,3,0,0,0,0,0,1;
                1,0,0,0,0,0,3,0,0,3,0,0,0,0,0,1;
                1,0,0,0,0,0,3,0,0,3,0,0,0,0,0,1;
                1,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,2,0,0,0,0,0,0,4,4,4,4,0,0,1;
                1,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,2,2,2,2,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
                ];

            numFloors = 3;
            obj.height = size(baseFloor,1);
            obj.width  = size(baseFloor,2);
            % Stack into a 3D uint8 array
            obj.map = repmat(uint8(baseFloor), 1, 1, numFloors);

            % Place example elevators & chests
            obj.elevators = [5,10,1; 15,8,2];
            obj.chests = struct( ...
                'position', {[10,4,1], [12,17,2], [3,19,3]}, ...
                'isOpen', {false, false, false}, ...
                'hasKey',     {false, false, true} ...
                );
            % Simple key manager
            obj.keyManager = struct( ...
                'keyPosition', [3,19,3], ...
                'isHeld',      false, ...
                'animFrame',   0 );
            obj.gs = gs;
        end


        function free = isCellFree(obj, row, col, floor)
            % clamp first, then test 0==empty
            row = max(1, min(obj.height, row));
            col = max(1, min(obj.width,  col));
            free = ( obj.map(row, col, floor) == 0 );
        end
        function tf = isCellElevator(obj, row, col, floor)
            tf = ( obj.map(row,col,floor) == ELEVATOR_TILE_ID );
        end

        function destFloor = getElevatorDestination(obj, row, col, floor)
            % Choose a random destination floor (1–3), excluding the current floor
            floors = 1:3;
            floors(floors == floor) = [];
            destFloor = floors(randi(numel(floors)));
        end

        function tf = isCellChest(obj, row, col, floor)
            tf = ( obj.map(row,col,floor) == CHEST_TILE_ID );
        end

        function chest = getChest(obj, row, col, floor)
            chest = obj.chests(row,col,floor);  % a struct with .hasKey, etc.
        end

        function clearCell(obj, row, col, floor)
            obj.map(row,col,floor) = 0;         % remove the chest or key
        end
    end
end
