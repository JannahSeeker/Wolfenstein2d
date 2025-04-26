Below is a draft README.md you can drop at the root of Wolf_v2/ (or paste into your project’s wiki) so that anyone can quickly see how everything fits together, how to wire up the mobile joysticks, and how to launch the game.

# Wolf_v2 — Top-Down Raycasting Game Prototype

A modular, object-oriented MATLAB prototype of a multiplayer raycaster game with mobile-joystick input.

---

## 🗂 Project Structure

Wolf_v2/
├── run2d.m              # Main entry point + displayContinuousMap
├── README.md            # ← (this file)
├── Objects/
│   ├── GameState.m      # Orchestrates players, sprites, map, input & logic
│   ├── Player.m         # Player handle class (position, input, move, interact, shoot)
│   ├── Sprite.m         # Enemy handle class (DirectChaser, SmartChaser A* pathfinding)
│   ├── Joystick.m       # Wrapper around web API to poll mobile joystick state
│   ├── MapManager.m     # Map data and collision/interactable-tile queries
│   └── SpriteManager.m  # Spawns, tracks & removes Sprite instances
├── managers/
│   └── SpriteManager.m  # (alias, if you prefer grouping)
└── web_joystick/        # Flask & HTML/JS mobile joystick server
├── app3.py          # Python Flask API for /api/joystick endpoints
└── templates/
└── joystick2.html  # NippleJS-powered on-screen joysticks + buttons

---

## ⚙️ Prerequisites

- **MATLAB** (R2021a or newer)  
- **Python 3** with:
  - `Flask`
  - `flask-cors`
  - `pyserial` (if reading from a hardware joystick)
- **NPM-served** `nipplejs` (included via CDN in HTML)

---

## 🚀 Getting Started

### 1. Run the Flask joystick server

1. Open a terminal in `web_joystick/`.
2. Install dependencies (ideally in a virtualenv):
   ```bash
   pip install Flask flask-cors pyserial

	3.	Launch:

python app3.py


	4.	Visit http://<your_ip>:5100/ on your phone to load the on-screen joystick controls.

2. Launch the MATLAB game
	1.	Open MATLAB and add Wolf_v2/ (and subfolders) to your path.
	2.	In the MATLAB command window, run:

run2d


	3.	Two players will be automatically added on port 5100 (you can adjust ports/IDs in the first lines of run2d.m).

⸻

🎮 How It Works
	1.	run2d.m
	•	Instantiates GameState, adds players, and enters a single loop that:
	1.	Polls each player’s Joystick (via HTTP GET /api/joystick/<id>).
	2.	Moves players, handles button presses for shooting (br) and interactions (bl).
	3.	Updates all sprites (enemy AIs).
	4.	Resolves collisions (sprite ↔ player), processes hitscan shots.
	5.	Checks for win/lose conditions.
	6.	Renders a top-down continuous view via displayContinuousMap.
	2.	Mobile Joystick UI
	•	Left stick: movement (forward/back, strafe).
	•	Right stick: rotation (turn left/right).
	•	Button A (bl): interact (e.g. elevators, chests).
	•	Button B (br): shoot (hitscan raycast).
	3.	Core Classes
	•	GameState: owns arrays of Player and Sprite objects, map data, main logic, and the raycast function.
	•	Player: handle class tracking position, input binding, movement, interactions, shooting, health, win condition.
	•	Sprite: handle class for enemies with pluggable AI (DirectChaser or SmartChaser), pathfinding, collision damage, death.
	•	MapManager: simple occupancy grid (map(row,col,floor)), queries like isCellFree, isCellChest, getElevatorDestination, etc.
	•	SpriteManager: spawns/removes sprites, keeps them in sync with GameState.

⸻

🔧 Configuration & Extensions
	•	Ports & IDs
	•	In run2d.m, you call gs.addPlayer(id, PORT); ensure your Flask server and phones agree on port and player IDs.
	•	Map Layout
	•	Edit MapManager.map to design levels (0 = empty, 1+ = wall or special tile).
	•	AI Modes
	•	Set aiBrain = "DirectChaser" or "SmartChaser" when spawning sprites to switch between greedy chasing and A* pathfinding.
	•	Adding New Interactables
	•	Extend MapManager with isCellX, getX, and clear methods (e.g. portals, traps).
	•	In Player.interact(), add a new branch to handle the logic.

⸻

📚 Further Reading
	•	DDA Raycasting: Lode’s Computer Graphics Tutorial
	•	MATLAB OOP: MathWorks Documentation
	•	NippleJS: Official Repo

⸻

Happy hacking! Feel free to file issues or open PRs to refine the gameplay, add graphics, or extend the multiplayer networking.