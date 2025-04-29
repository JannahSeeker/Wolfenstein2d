classdef Player < handle
    %PLAYER  Holds all player‐related state.
    properties
        position   (1,3) double = [3,4,1]  % [x,y,z]
        name string = ""
        angle      double       = 3*pi/2
        health     double       = 100
        maxHealth  double       = 100
        mana       double       = 0
        hasKey     logical      = false
        speed      double       = 15      % cells/sec
        rotSpeed   double       = 10    % rad/sec
        animFrame  double       = 0
        joystick Joystick
        endTime uint64 = 0
        startTime uint64 = 0
        isKey logical = false
        isFinished logical = false
        keyIndex = 0;
        id int32
        gs GameState
        prevBL logical = false   % track last‐frame button state
        isDead logical = false

    end
    methods
        function obj = Player(gs)
            %Joystick Construct a Joystick handle with given id and port
            obj.name = "abdullah";
            obj.gs = gs;
            obj.startTime = tic;
        end
        function bindJoystick(obj,id,port)
            % Construct all sub‐objects
            obj.joystick = Joystick(id,port);
        end
        function move(obj, dx, dy)
            % try X
            newX = obj.position(1) + dx;

            %attaching the row, the row is the y condition
            row  = floor(obj.position(2));
            %the column is the new x
            col  = floor(newX);
            if obj.gs.mapManager.isCellFree(row, col, obj.position(3))
                obj.position(1) = newX;
            end
            % try Y
            %take y
            newY = obj.position(2) + dy;
            row  = floor(newY);
            col  = floor(obj.position(1));
            if obj.gs.mapManager.isCellFree(row, col, obj.position(3))
                obj.position(2) = newY;
            end
            if obj.hasKey
                obj.gs.mapManager.moveKey(obj.position,obj.keyIndex);
            end

            if obj.position(3) == 3 && obj.hasKey
                obj.checkWin()
            end

        end

        function updateFromJoystick(obj, dt)
            obj.joystick.pollJoystick();
            % forward/back & strafe
            fwd    = obj.joystick.yl * obj.speed * dt;
            strafe = obj.joystick.xl * obj.speed * dt;
            % rotation
            obj.angle = obj.angle + obj.joystick.xr * obj.rotSpeed * dt;
            % compute world‐space deltas

            if obj.joystick.bl && ~obj.prevBL
                obj.interact();
            end
            obj.prevBL = obj.joystick.bl;

            dx = cos(obj.angle)*fwd + -sin(obj.angle)*strafe;
            dy = sin(obj.angle)*fwd +  cos(obj.angle)*strafe;
            obj.move(dx, dy);

        end



        function checkWin(obj)
            %CHECKWIN  Self-test for win: floor 3, corner cell, has key
            x = obj.position(1);
            y = obj.position(2);
            z = obj.position(3);

            inCorner = (x >= 14 && x <= 16) && (y >= 14 && y <= 16);
            if inCorner && obj.hasKey
                obj.isFinished = true;
                obj.endTime  = toc(obj.startTime);           % record finish time (or use tic/toc)
                obj.gs.playerWin(obj.id);      % notify GameState
            end

        end

        function shoot(obj)
            if ~obj.hasKey
                obj.gs.handleHitscanShot(obj.id);
            else
                obj.gs.mapManager.dropKey(obj.keyIndex);
                obj.hasKey = false;
                obj.keyIndex = 0;
            end
        end
        function interact(obj)
            % Compute the cell immediately in front of the player
            dirX = cos(obj.angle);
            dirY = sin(obj.angle);
            targetX = ceil(floor(obj.position(1) + dirX));
            targetY = ceil(floor(obj.position(2) + dirY));
            f = obj.position(3);
            m = obj.gs.mapManager
            % Elevator?
            if m.isCellElevator(targetY, targetX, f)
                disp("Checkign Elevator");
                dest = m.getElevatorDestination(targetY, targetX, f);
                % find a free cell on the destination floor
                % pick two random integer cell‐coordinates within the map

                while ~m.isCellFree(targetY, targetX, dest)
                    disp("searching");
                    targetX = randi([2, m.width-1]);
                    targetY = randi([2, m.height-1]);
                end
                % teleport:

                obj.position(1) = targetX;
                obj.position(2) = targetY;
                obj.position(3) = dest;

                return
            end
            % Chest?
            %need certain mana to open chest adn not have a key
            if obj.mana == 0 && ~obj.hasKey
                [isChest, hasaKey,km] = m.isChestandKey(targetY, targetX, f);

                %if the cell above is a chest
                if isChest && hasaKey
                    obj.hasKey = true;
                    obj.keyIndex  = km;
                    m.holdKey(obj.keyIndex);
                    m.moveKey(obj.position,obj.keyIndex);

                    %if not, possible key dropped, check if the key is a cell
                else
                    pos = [targetX,targetY,f];
                    km = m.isCellKey(pos);
                    
                    if km
                        obj.keyIndex  = km;
                        m.holdKey(obj.keyIndex);
                        m.moveKey(obj.position,obj.keyIndex);
                    end
                end
            end



        end

        function takeDamage(obj,damage)
            % obj.health = obj.health - damage;
            disp(damage);
            if obj.health <= 0
                obj.isDead = true;
                obj.gs.playerLose(obj.id);
                disp("Dead");
                return
            end
        end
    end
end