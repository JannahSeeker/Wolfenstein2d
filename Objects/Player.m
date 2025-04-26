classdef Player < handle
    %PLAYER  Holds all player‐related state.
    properties
        position   (1,3) double = [3,4,1]  % [x,y,z]
        name string
        angle      double       = 0
        health     double       = 100
        maxHealth  double       = 100
        mana       double       = 0
        hasKey     logical      = false
        speed      double       = 5      % cells/sec
        rotSpeed   double       = 1.5    % rad/sec
        animFrame  double       = 0
        joystick Joystick
        time double
        isKey logical = false
        id int32
        gs GameState
        prevBL logical = false   % track last‐frame button state
        isDead logical = false

    end
    methods
        function obj = Player(gs)
            %Joystick Construct a Joystick handle with given id and port
            obj.gs = gs;
        end
        function bindJoystick(obj,id,port)
            % Construct all sub‐objects
            obj.joystick = Joystick(id,port);
        end
        function move(obj, dx, dy)
            % try X
            newX = obj.position(1) + dx;
            row  = floor(obj.position(2));
            col  = floor(newX);
            if obj.gs.mapManager.isCellFree(row, col, obj.position(3))
                obj.position(1) = newX;
            end
            % try Y
            newY = obj.position(2) + dy;
            row  = floor(newY);
            col  = floor(obj.position(1));
            if obj.gs.mapManager.isCellFree(row, col, obj.position(3))
                obj.position(2) = newY;
            end
            if obj.position(3) == 3
                checkWin(obj.gs)
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

        function isWin(obj)
            %if player position is in the 3rd floor of the map and in the upper right corner, and has the key then they win
            obj.gs.PlayerWin(id)
        end

        function checkWin(obj)
            %CHECKWIN  Self-test for win: floor 3, corner cell, has key
            x = obj.position(1);
            y = obj.position(2);
            z = obj.position(3);


            inCorner = (x >= 14 && x <= 16) && (y >= 14 && y <= 16);
            if inCorner && obj.hasKey
                obj.time  = now;           % record finish time (or use tic/toc)
                obj.gs.playerWin(obj.id);      % notify GameState
            end

        end

        function shoot(obj)
            if ~obj.hasKey
                obj.gs.handleHitscanShot(obj.id);
            end
        end
        function interact(obj)
            % Compute the cell immediately in front of the player
            dirX = cos(obj.angle);
            dirY = sin(obj.angle);

            targetX = ceil(floor(obj.position(1) + dirX));
            targetY = ceil(floor(obj.position(2) + dirY));
            f = obj.position(3);

            m = obj.gs.mapManager;

            % Elevator?
            if m.isCellElevator(targetY, targetX, f)
                dest = m.getElevatorDestination(targetY, targetX, f);
                obj.position(3) = dest;       % move player up/down
                return
            end
            % Chest?
            if m.isCellChest(targetY, targetX, f)
                if obj.mana > 10
                    chest = m.getChest(targetY, targetX, f);
                    if chest.hasKey
                        obj.hasKey = true;          % pick up the key
                        m.clearCell(targetY, targetX, f);
                    end
                    return
                end
            end

        end

        function takeDamage(obj,health)
            if health <= 0
                obj.isDead = true;
                obj.gs.playerLose(obj.id)
                return
            end
            obj.health = obj.health - health;
        end
    end
end