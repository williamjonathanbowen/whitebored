Whitebored

A Mac tutor that sits on the table with you. You write on paper or a whiteboard. You talk. It looks, listens, draws on its own board, and speaks.

This is a first draft. Native Swift. Full screen. White.

What it does
- You type one line: what you want to learn.
- It starts with the real idea, not baby steps and not a worksheet.
- It uses the camera, the mic, and its own whiteboard.
- It stays silent until you press option-command.
- Then it takes a photo, grabs what you just said, shows thinking, writes a clear answer, and speaks it.

What it is not yet
- Not a phone app
- Not always-on VAD (you press look)
- Not screen recording (camera only)
- Not copying your physical board pixel-perfect, it redraws what it can see

Run it

1. Install Xcode 26 if you do not have it.
2. In this folder:

   ./scripts/run.sh

That generates the Xcode project, builds, and opens the app.

Or:

   brew install xcodegen
   xcodegen generate
   open Whitebored.xcodeproj

Then press Cmd-R.

First launch
- Allow camera, microphone, and speech.
- If it asks for an anthropic key, paste it and press return. It also reads ~/.config/whitebored/key or the ANTHROPIC_API_KEY env var.
- Type a goal, for example: how data centres actually work
- Press return. Talk and write. It stays silent until you ask.
- Hold a page up if you want. Press option-command when you want it to talk.

Needs internet for the tutor (Claude Sonnet 5). Speech and camera stay on your Mac.

A demo that would feel real
Laptop open on the table at a lazy angle. Paper. A kid or you, stuck. You say "this triangle is doing my head in", hold up the page, press look. The Mac copies the triangle onto its white board, marks the right angle in blue, and says "try writing a squared plus b squared. do not solve it yet. just write that."
