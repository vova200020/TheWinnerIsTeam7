# Word replacements

Three lists. All three come from `notes/temp_notes/ASD-STE100_ISSUE9.pdf`, part 2, read
first-hand 2026-08-17.

- **List A** is the standard's own "List of recurring errors" (pages 2-0-17 and 2-0-18), copied verbatim.
- **List B** is the approved-verb quick-reference list (page 2-0-19), copied verbatim.
- **List C** holds the words this project's own prose uses that the dictionary refuses.
  The assistant looked each row up in the word list one at a time. The page number is the PDF page.

Lists A and B carry `<!-- ste-check: off -->` markers, because they are quotations.

For a word that is in none of the three lists, run
`python .claude/skills/ste-writing/scripts/ste_lookup.py WORD`.

---

## List A: the standard's list of recurring errors (verbatim)

"The table that follows gives you a list of the most frequently recurring errors that writers
make when they use STE. If a word is not approved in the dictionary, do not use it."

| Non-STE | STE |
|---|---|
| acceptable (adj) | PERMITTED (adj) |
| alternate (adj) | ALTERNATIVE (adj) |
| any (adj) | None, or a different sentence construction |
| avoid (v) | PREVENT (v) |
| both (adj) | THE TWO (TN) |
| check (v) | CHECK (n) |
| cover (v) | COVER (TN) |
| complete (adj) | COMPLETED (adj) |
| damage (v) | DAMAGE (n) |
| ensure (v) | MAKE SURE (v) |
| fit (v) | INSTALL (v) |
| follow (v) | OBEY (v) |
| further (adj) | MORE (adj) |
| further (adv) | MORE (adv) |
| have to (v) | Use an action verb in the imperative form |
| however (adv) | BUT (conj) |
| insert (v) | PUT (v) |
| main (adj) | PRIMARY (adj) |
| may (v) | CAN (v) |
| need (v) | NECESSARY (adj) |
| now (adv) | AT THIS TIME |
| old (adj) | REMAINING (adj), USED (adj), EXPIRED (adj) |
| over (prep) | ABOVE (prep), ON (prep), ALONG (prep) |
| people (n) | PERSON (n), PERSONNEL (n) |
| perform (v) | DO (v) |
| portion (n) | PART (n) |
| press (v) | PUSH (v) |
| reach (v) | GET (v) |
| repeat (v) | DO (v) ... AGAIN |
| required (v) | NECESSARY (adj) |
| rotate (v) | TURN (v) |
| secure (v) | ATTACH (v), SAFETY (v) |
| shall (v) | MUST (v) |
| should (v) | MUST (v) |
| since (conj) | BECAUSE (conj) |
| test (v) | TEST (n) |
| therefore (adv) | THUS (adv), AS A RESULT |
| under (prep) | BELOW (prep), IN (prep), LESS THAN |
| using (v) | USE (v), WITH (prep) |

## List B: every approved verb (verbatim, page 2-0-19)

<!-- ste-check: off -->
ABSORB, ACCEPT, ACTIVATE, ADAPT, ADD, ADJUST, AGREE, ALIGN, APPLY, ARM, ASSEMBLE, ATTACH,
BALANCE, BE, BECOME, BEND, BLEED, BLOW, BOND, BREAK, BREATHE, BURN, BYPASS,
CALCULATE, CALIBRATE, CAN, CANCEL, CANNOT, CATCH, CAUSE, CHANGE, CHARGE, CLEAN, CLOSE, COLLECT,
COME, COME ON, COMPARE, COMPLETE, COMPRESS, CONNECT, CONTACT, CONTAIN, CONTINUE, CONTROL,
CORRECT, COUNT, CUT,
DEACTIVATE, DECREASE, DE-ENERGIZE, DEFLATE, DEFUEL, DEPLOY, DISARM, DISASSEMBLE, DISCARD,
DISCONNECT, DISENGAGE, DIVIDE, DO, DRAIN, DRINK, DRY,
EAT, EJECT, ENERGIZE, ENGAGE, ERASE, EXAMINE, EXPAND, EXTEND, EXTINGUISH,
FALL, FEATHER, FEEL, FILL, FIND, FIRE, FLASH, FLOW, FLUSH, FOLD, FOLLOW, FREEZE,
GET, GIVE, GO, GO OFF, GROUND,
HANG, HAVE, HEAR, HELP, HIT, HOLD,
IDENTIFY, IGNORE, ILLUMINATE, INCLUDE, INCREASE, INFLATE, INSTALL, INTERCHANGE, ISOLATE,
KEEP, KILL, KNOW,
LATCH, LET, LIFT, LISTEN, LOCK, LOOK, LOOSEN, LOWER, LUBRICATE,
MAKE, MAKE SURE, MEASURE, MELT, MIX, MONITOR, MOOR, MOVE, MULTIPLY, MUST,
OBEY, OCCUR, OPEN, OPERATE, OVERRIDE,
PAINT, PARK, POINT, POLISH, PREPARE, PRESSURIZE, PREVENT, PROTRUDE, PULL, PUSH, PUT, PUT ON,
READ, RECEIVE, RECOMMEND, RECORD, RECYCLE, REFER, REFUEL, REJECT, RELEASE, REMOVE, REPAIR,
REPLACE, RETRACT, RUB,
SAFETY, SCHEDULE, SEAL, SEE, SELECT, SEND, SENSE, SET, SHAKE, SHOW, SIMULATE, SMELL, SMOKE,
SOAK, SPEAK, SPILL, SPRAY, START, STAY, STOP, STOW, SUBTRACT, SUPPLY, SWALLOW,
TAG, TAP, TELL, THINK, TIGHTEN, TILT, TORQUE, TOUCH, TOW, TRANSMIT, TRY, TUNE, TURN, TWIST,
UNFOLD, UNLOCK, UNWIND, USE,
WAIT, WALK, WANT, WEAR, WEIGH, WILL, WIND, WRITE.
<!-- ste-check: on -->

A verb that is not in this list, and that belongs to no technical-verb category (rule 1.12), is
not permitted. Two consequences worth naming, because this project writes them every day:

- **ESTIMATE, ANALYSIS, and PROCESS are approved as NOUNS only.** Write "the estimate of power",
  or use a technical verb of the subject field, not "we estimate the power" in ordinary prose.
- **SENSE, MEASURE, MONITOR, RECORD, CALCULATE, COMPARE, and SIMULATE are approved verbs.** They
  cover most of what this project's methods sentences must say.

## List C: this project's habitual words that the dictionary refuses

The assistant looked each row up one at a time. "p" is the PDF page of the entry.

| Word (not approved) | p | Approved alternative the dictionary gives |
|---|---|---|
| ability (n) | 149 | CAN (v) |
| acceptable (adj) | 152 | PERMITTED (adj), SATISFACTORY (adj), SERVICEABLE (adj) |
| accomplish (v) | 153 | DO (v), COMPLETE (v) |
| achieve (v) | 154 | GET (v) |
| allow (v) | 160 | LET (v) |
| analyze (v) | 162 | ANALYSIS (TN) |
| approach (v) | 165 | GO NEAR |
| assess (v) | 168 | CALCULATE (v), ESTIMATE (n) |
| capability (n) | 184 | FUNCTION (n), CAN (v) |
| check (v) | 189 | MAKE SURE (v), MEASURE (v), EXAMINE (v), CHECK (n) |
| comprehensive (adj) | 197 | FULL (adj) |
| conduct (v) | 198 | DO (v) |
| critical (adj) | 206 | VERY IMPORTANT |
| decrease (n) | 209 | DECREASE (v) |
| detect (v) | 215 | FIND (v), SENSE (v) |
| determine (v) | 215 | FIND (v), GIVE (v), SELECT (v), CALCULATE (v) |
| due to (prep) | 225 | BECAUSE OF (prep), BECAUSE (conj) |
| enable (v) | 231 | LET (v) |
| ensure (v) | 233 | MAKE SURE (v) |
| establish (v) | 235 | MAKE SURE (v) |
| estimate (v) | 235 | ESTIMATE (n) |
| evaluate (v) | 235 | EXAMINE (v), ANALYSIS (TN) |
| facilitate (v) | 245 | HELP (v), MAKE ... EASIER |
| function (v) | 258 | OPERATE (v), MOVE (v) |
| however (adv) | 272 | BUT (conj) |
| implement (v) | 277 | DO (v) |
| improve (v) | 278 | BETTER (adj) |
| increase (n) | 282 | INCREASE (v) |
| indicate (v) | 282 | SHOW (v), IDENTIFY (v), SPECIFIED (adj) |
| obtain (v) | 319 | GET (v) |
| opportunity (n) | 322 | reword; "if it is possible" |
| perform (v) | 331 | DO (v), MEASURE (v) |
| prior to (prep) | 340 | BEFORE (conj) |
| process (n) | 341 | PROCEDURE (n); it IS a technical noun when it means a sequence of changes |
| provide (v) | 344 | GIVE (v), SUPPLY (v) |
| reduce (v) | 354 | DECREASE (v) |
| require (v) | 360 | NECESSARY (adj) |
| result (v) | 362 | CAUSE (v), RESULT (n) |
| significant (adj) | 377 | IMPORTANT (adj) |
| support (v) | 395 | HOLD (v), SUPPORT (TN) |
| test (v) | 401 | TEST (n) |
| therefore (adv) | 402 | THUS (adv), AS A RESULT |
| use (n) | 420 | OPERATION (n), USE (v) |
| utilize (v) | 420 | USE (v) |
| various (adj) | 421 | DIFFERENT (adj) |
| verify (v) | 422 | MAKE SURE (v) |
| via (prep) | 422 | THROUGH (prep) |

**Absent from the word list entirely.** These words enter only as a technical noun or a technical
verb of the subject field. In ordinary prose they are defects: robust, novel, leverage, optimize,
essential, crucial, substantial, currently, additionally, furthermore, regarding, multiple,
demonstrate, validate, challenge. Project standard 8 already bans three of them as filler:
"leveraging", "robust", and "novel".

## The word count of the project's own filler

Rule 10 of `report-standard` already bans em-dashes, and section 8 of `hackathon-code-standard`
bans filler. STE reaches the same result by a different route. Where the two disagree, STE is
narrower, so STE wins for the assistant's own wording.
