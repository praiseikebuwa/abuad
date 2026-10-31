Viewed package.json
Viewed README.md:1-393
Viewed schema.prisma:1-527
Viewed app_router.dart:1-250

Here is a curated list of new features we can add to **ABUAD Life**, tailored to your existing architecture ([schema.prisma](file:///c:/Users/pikeb/Desktop/abuad/backend/prisma/schema.prisma), [app_router.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/core/router/app_router.dart), Socket.io, and Gemini AI):

---

### 1. 🧠 AI & Academic Co-Pilot (Extending [ai_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/ai/presentation/ai_screen.dart) & [cbt_practice_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/portal/presentation/cbt_practice_screen.dart))
* **PDF-to-CBT Quiz & Flashcard Generator:** Allow students to upload lecture PDFs or slides in [resources_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/resources/presentation/resources_screen.dart) and have Gemini automatically generate interactive CBT practice tests, flashcards, and cheat sheets.
* **AI Lecture Voice Note Summarizer:** Record lectures or upload audio to generate structured markdown notes, key takeaways, and action items.
* **Multiplayer CBT Battle Mode:** Real-time 1v1 or departmental quiz battles over Socket.io where students compete on past questions with live leaderboards.

---

### 2. 🎥 Social, Reels & Camera (Extending [reels_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/feed/presentation/reels_screen.dart) & [camera_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/camera/presentation/camera_screen.dart))
* **Campus Live Audio Spaces / Drop-in Rooms:** Twitter Spaces / Clubhouse-style live audio rooms for faculty town halls, tutorial sessions, late-night campus gist, or student union debates.
* **Collaborative Story Chains ("Campus Passes"):** Prompt-based 24h story chains (e.g., *"Show your hostel view"*, *"Exam week fit check"*) where anyone can tap "Add Yours" to append to a campus-wide story reel.
* **Reels Remix / Duets & Green Screen:** Allow students to duet or stitch existing campus reels directly in [camera_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/camera/presentation/camera_screen.dart).
* **Anonymous "Whisper / Confessions" Feed Tab:** A moderated, dedicated tab utilizing the `isAnonymous` flag on `Post` in [schema.prisma](file:///c:/Users/pikeb/Desktop/abuad/backend/prisma/schema.prisma#L137) with automatic AI toxicity filtering before publishing.

---

### 3. 💬 Real-Time Chat & Gamification (Extending [chat_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/chat/presentation/chat_screen.dart))
* **Interactive Snap Streak Rewards & Freeze:** Since `streakCount` and `streakExpiry` already exist on `ChatChannel` ([schema.prisma](file:///c:/Users/pikeb/Desktop/abuad/backend/prisma/schema.prisma#L226-L228)), add visual fire tiers, profile badges, and a "Streak Restore/Freeze" mechanic.
* **In-Chat Mini-Games & Polls:** Quick turn-based games (Wordle, Trivia, Tic-Tac-Toe) and instant group polls directly inside group and direct chats.
* **Watch Party / Study-With-Me Rooms:** Synchronized Pomodoro timers and shared whiteboards inside group channels for exam prep.
* **Voice Note Auto-Transcription:** Instant on-demand text transcription beneath voice notes in chat for when students are in a lecture hall and can't play audio aloud.

---

### 4. 🛍️ Marketplace, Cafeteria & Campus Economy (Extending [marketplace_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/marketplace/presentation/marketplace_screen.dart))
* **Cafeteria Food Ordering & Errand Runner ("Drop-Off"):** Let students pre-order from campus cafeterias or post a small delivery bounty (e.g., `₦500`) for another student heading back to their hostel to pick up food/items.
* **Escrow & In-App Campus Wallet:** Safe P2P payments where funds are held until the buyer scans the seller's QR code ([qr_scanner_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/chat/presentation/qr_scanner_screen.dart)) upon item handover.
* **Wishlist & Price-Drop Alerts:** Notify students when a textbook or gadget they need in their department is listed or drops in price.
* **Event Ticketing & QR Check-in:** Upgrade [events_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/events/presentation/events_screen.dart) with digital QR tickets, capacity limits, and organizer scan-to-verify at the door.

---

### 5. 🗺️ Map, Safety & Campus Utilities (Extending [map_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/map/presentation/map_screen.dart) & [campus_sos_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/utilities/presentation/campus_sos_screen.dart))
* **"Walk With Me" Live Companion Sharing:** Temporary live location sharing with close friends (`CloseFriend` model in [schema.prisma](file:///c:/Users/pikeb/Desktop/abuad/backend/prisma/schema.prisma#L112-L122)) when walking back to hostels at night, with a dead-man timer that triggers an `SOSAlert` if the user doesn't check in.
* **Snap-Map Style Friend & Crowd Heatmap:** Optional "Ghost Mode / Close Friends" live avatar pins on the campus map plus crowd density indicators at libraries, cafeterias, and shuttle stops.
* **Digital Exeat & Hostel Maintenance Tracker:** Track hostel repair requests (plumbing, electrical) and exeat/pass statuses inside [hostel_hub_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/utilities/presentation/hostel_hub_screen.dart).
* **AI Visual Match for Lost & Found:** Auto-match newly posted "Found" items with existing "Lost" reports in [lost_found_screen.dart](file:///c:/Users/pikeb/Desktop/abuad/lib/src/features/utilities/presentation/lost_found_screen.dart) using Gemini Vision and send instant push notifications.

---

Which category or specific feature would you like to build first? I can design the schema updates, backend routes, and Flutter UI right away.