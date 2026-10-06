STICKMAN VS GEOMETRY
====================
A 20-chapter adventure through geometry, physics, maths, chemistry and biology. No install needed on a computer:
double-click index.html.

PLAY ON A PHONE
---------------
The game is a web app. A phone can only "install" it from a web address,
so the files have to be served from somewhere.

A) Same Wi-Fi as the computer (quickest)
   1. On the computer, in this folder, run:   python3 -m http.server 8765
   2. On the phone, open:   http://<computer-ip>:8765
   3. Turn the phone sideways and tap to play.
   4. iPhone: Share > Add to Home Screen.   Android: menu > Add to Home screen.
   The computer must stay on and on the same Wi-Fi.

B) Permanent, works anywhere and offline
   Upload every file in this folder to any HTTPS static host
   (GitHub Pages, Netlify, Cloudflare Pages...). Open that address on the
   phone and choose "Add to Home Screen" / "Install app". After the first
   visit it works offline.

FILES
-----
index.html            the whole game
manifest.webmanifest  app name, icon and full-screen landscape settings
sw.js                 offline cache
icon-*.png            app icons

CONTROLS
--------
Keyboard: arrows or A/D move, Space jump, X use the phi, P pause, R retry,
H all controls, T tutorial, M mute, B glow.
Touch: on-screen buttons; tap a chapter card to start it.
