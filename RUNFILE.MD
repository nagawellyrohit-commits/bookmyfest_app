# CollegeConnect Run Guide

This guide details how to start the backend server, Prisma database studio, and launch the Flutter app on iOS and Android emulators from scratch.

---

## 🖥️ 1. Start the Backend Server (Terminal 1)

Before launching the app, start the Express Node.js server:
```bash
cd server
npm run dev
```

---

## 🗄️ 2. Open Prisma Database Studio (Terminal 2 - Optional)

If you need to view or manage database entries directly:
```bash
cd server
npm run db:studio
```

---

## 🍎 3. Run on iOS Simulator (Terminal 3)

If the simulator is completely closed, you must first **boot the device ID** before opening the Simulator window.

1. **Boot the specific simulator device**:
   ```bash
   xcrun simctl boot 7C1F6405-FDEF-405A-A804-C06E6871F59F
   ```
2. **Open the Simulator window application**:
   ```bash
   open -a Simulator
   ```
3. **Run the Flutter app**:
   ```bash
   flutter run -d 7C1F6405-FDEF-405A-A804-C06E6871F59F
   ```

---

## 🤖 4. Run on Android Emulator (Terminal 3)

If the emulator is completely closed:

1. **Launch the Android Emulator** (wait about 15-30 seconds for it to fully load):
   ```bash
   flutter emulators --launch android
   ```
2. **Run the Flutter app**:
   ```bash
   flutter run -d android
   ```