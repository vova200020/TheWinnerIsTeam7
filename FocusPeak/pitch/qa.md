# FocusPeak: answers for the judges

> One short answer for each likely question, with the source where a number is used.

## 0. Status

| Item | State | Your open action |
|---|---|---|
| Answers | ✅ 14 answers written | Read them once before the pitch |

## 1. Answers

| Criterion | Question | Answer |
|---|---|---|
| Problem-Solution Fit | Who is the user? | Us: students and knowledge workers who own a Garmin watch and lose their breaks to the phone |
| Execution and Deployment | What is real and what is simulated? | Real: the app on the watch, the sensors, the scores, the 15 unit tests. Simulated in demo mode: short timers and 14 days of example history. The friends data is example data on a local server |
| Execution and Deployment | Can we install it? | Yes, sideloaded on this Forerunner 265. It also builds for the Fenix 7 Pro with SDK 9.1.0. The store review takes days, so not today |
| Execution and Deployment | Does it really lock the phone? | Today it shows a full-screen lock page with a 3 s emergency hold. Real app blocking needs the iPhone Screen Time API in a native app: next step |
| User Experience and Design | How many presses to start? | One: START on the Ready screen |
| User Experience and Design | What if I must use the phone now? | Skip the gate on the watch, or hold the phone lock for 3 s. It is allowed, and a skipped gate resets the streak. The choice stays with the user |
| Impact and Value | How do you know it changes a habit? | We do not know yet. In a 30-day trial we would measure phone pickups during focus, completed blocks per week, and the Focus Score trend |
| Creativity and Approach | What exists already? | Forest and Opal reward an untouched phone. None reads the body, and none makes the break a short workout. Garmin has no focus session |
| Science | Why 24 + 6 minutes? | It is the fixed-break protocol tested in 87 students: less fatigue and more concentration than self-chosen breaks (Biwer 2023, British Journal of Educational Psychology, PubMed 36859717) |
| Science | Why move before the break? | One bout of exercise improves attention, standardized mean difference 0.37 (meta-review of 30 meta-analyses, 2025, PubMed 39883421). The effect is small to medium |
| Science | How do you measure focus? | We do not measure it directly. The Focus Score is a proxy: time on task, wrist stillness and calm heart rate |
| Data | Why not the Garmin sleep score? | The watch API of the Fenix 7 Pro does not give it. The Garmin Health API does, after a business approval. That is our first request to Garmin |
| Privacy | Where does my data go? | It stays on the watch. The community feature sends a place label only, never coordinates, and a session at Home is never shared |
| Any | One more week? | Native iPhone app with real app blocking and sleep from Apple Health, a glance with the streak, and a 30-day trial with five users |
