{ config, lib, pkgs, ... }:

{
  # Kiosk browser configuration
  users.users.kiosk.packages = with pkgs; [
    chromium
  ];

  # Auto-start Chromium in kiosk mode
  systemd.services.chromium-kiosk = {
    description = "Chromium Kiosk Mode";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    
    environment = {
      DISPLAY = ":0";
      HOME = "/home/kiosk";
    };
    
    serviceConfig = {
      Type = "simple";
      User = "kiosk";
      Group = "users";
      ExecStart = ''
        ${pkgs.chromium}/bin/chromium \
          --kiosk \
          --no-sandbox \
          --disable-web-security \
          --disable-features=TranslateUI \
          --disable-infobars \
          --disable-default-apps \
          --disable-extensions \
          --disable-plugins \
          --disable-background-timer-throttling \
          --disable-backgrounding-occluded-windows \
          --disable-background-networking \
          --no-first-run \
          --noerrdialogs \
          --touch-events=enabled \
          --enable-pinch \
          --overscroll-history-navigation=0 \
          --start-maximized \
          --app=file:///home/kiosk/tabletop/index.html
      '';
      Restart = "always";
      RestartSec = 5;
      
      # Security restrictions
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = false;  # Need access to /home/kiosk
      ProtectSystem = "strict";
      ReadWritePaths = [ "/home/kiosk" ];
    };
  };

  # Create default tabletop page
  systemd.tmpfiles.rules = [
    "d /home/kiosk/tabletop 0755 kiosk users"
    "f /home/kiosk/tabletop/index.html 0644 kiosk users"
  ];

  # Default tabletop HTML page
  environment.etc."kiosk-html/index.html".text = ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
      <title>Tabletop Gaming Kiosk</title>
      <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }
        
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          color: white;
          touch-action: manipulation;
        }
        
        .container {
          text-align: center;
          max-width: 800px;
          padding: 2rem;
        }
        
        h1 {
          font-size: 3rem;
          margin-bottom: 1rem;
          text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .subtitle {
          font-size: 1.5rem;
          margin-bottom: 2rem;
          opacity: 0.9;
        }
        
        .status {
          background: rgba(255,255,255,0.1);
          padding: 1rem;
          border-radius: 10px;
          margin: 2rem 0;
          backdrop-filter: blur(10px);
        }
        
        .games-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 1rem;
          margin-top: 2rem;
        }
        
        .game-card {
          background: rgba(255,255,255,0.1);
          padding: 1.5rem;
          border-radius: 10px;
          backdrop-filter: blur(10px);
          cursor: pointer;
          transition: transform 0.2s, background 0.2s;
          border: 2px solid transparent;
        }
        
        .game-card:hover,
        .game-card:active {
          transform: scale(1.05);
          background: rgba(255,255,255,0.2);
          border-color: rgba(255,255,255,0.3);
        }
        
        .game-title {
          font-size: 1.2rem;
          font-weight: bold;
          margin-bottom: 0.5rem;
        }
        
        .game-description {
          font-size: 0.9rem;
          opacity: 0.8;
        }
        
        @media (max-width: 768px) {
          h1 { font-size: 2rem; }
          .subtitle { font-size: 1.2rem; }
          .container { padding: 1rem; }
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🎮 Tabletop Gaming Kiosk</h1>
        <div class="subtitle">Touch-Optimized Board Game Experience</div>
        
        <div class="status">
          <strong>System Ready</strong><br>
          Raspberry Pi 4 • Touch Enabled • Offline Capable
        </div>
        
        <div class="games-grid">
          <div class="game-card" onclick="loadGame('chess')">
            <div class="game-title">♛ Chess</div>
            <div class="game-description">Classic strategy game</div>
          </div>
          
          <div class="game-card" onclick="loadGame('checkers')">
            <div class="game-title">⚫ Checkers</div>
            <div class="game-description">Traditional board game</div>
          </div>
          
          <div class="game-card" onclick="loadGame('cards')">
            <div class="game-title">🃏 Card Games</div>
            <div class="game-description">Solitaire and more</div>
          </div>
          
          <div class="game-card" onclick="loadGame('puzzle')">
            <div class="game-title">🧩 Puzzles</div>
            <div class="game-description">Brain teasers</div>
          </div>
        </div>
        
        <div style="margin-top: 2rem; opacity: 0.7; font-size: 0.9rem;">
          <div>Network: <span id="network-status">Checking...</span></div>
          <div>Build: NixOS • Version: 24.05</div>
        </div>
      </div>
      
      <script>
        function loadGame(gameType) {
          // Placeholder for game loading
          alert('Game loading: ' + gameType + '\n\nThis is a demo interface.\nReal games would be loaded here.');
        }
        
        // Check network status
        function updateNetworkStatus() {
          if (navigator.onLine) {
            document.getElementById('network-status').textContent = 'Online';
            document.getElementById('network-status').style.color = '#4ade80';
          } else {
            document.getElementById('network-status').textContent = 'Offline';
            document.getElementById('network-status').style.color = '#fbbf24';
          }
        }
        
        updateNetworkStatus();
        window.addEventListener('online', updateNetworkStatus);
        window.addEventListener('offline', updateNetworkStatus);
        
        // Touch event optimization
        document.addEventListener('touchstart', function() {}, { passive: true });
        document.addEventListener('touchmove', function(e) {
          e.preventDefault();
        }, { passive: false });
      </script>
    </body>
    </html>
  '';

  # Copy the default page to user directory on boot
  systemd.services.setup-kiosk-page = {
    description = "Setup Kiosk Default Page";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "setup-kiosk-page" ''
        mkdir -p /home/kiosk/tabletop
        cp /etc/kiosk-html/index.html /home/kiosk/tabletop/
        chown -R kiosk:users /home/kiosk/tabletop
      '';
    };
  };

  # Disable screen blanking and power management
  services.xserver.displayManager.sessionCommands = ''
    ${pkgs.xorg.xset}/bin/xset s off
    ${pkgs.xorg.xset}/bin/xset -dpms
    ${pkgs.xorg.xset}/bin/xset s noblank
  '';

  # Hide cursor after inactivity
  services.unclutter = {
    enable = true;
    timeout = 5;
  };
}