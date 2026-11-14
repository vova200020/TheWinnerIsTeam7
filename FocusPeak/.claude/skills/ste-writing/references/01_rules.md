# ASD-STE100 Issue 9, part 1: all writing rules

Source: `notes/temp_notes/ASD-STE100_ISSUE9.pdf`, part 1, pages 1-1-1 to 1-9-13. Read first-hand
2026-08-17. The rule statements are the wording of the standard. The "in this project" column is
the assistant's note on how the rule applies to this repository.

Two definitions the standard gives, because they decide most word questions:

- A **technical noun** is a noun term that refers to a specified concept and is applicable to a
  subject field (rule 1.1, page 1-1-1).
- A **technical verb** is a verb term that refers to a specified concept or process and is
  applicable to a subject field (rule 1.12, page 1-1-13).

The dictionary holds neither, because each subject field has its own. That is the door through
which "Connect IQ", "watch face", "Body Battery", "GATT characteristic" and "range-Doppler" enter legally.

---

## Section 1: words (rules 1.1 to 1.14)

| Rule | Statement | In this project |
|---|---|---|
| 1.1 | Use words that are approved in the dictionary, technical nouns, or technical verbs. | Three sources only. A word that is in none of the three is a defect. |
| 1.2 | Use approved words from the dictionary only as the specified part of speech. | "Test" is a noun, not a verb. Write "do a test of", not "test the". |
| 1.3 | Use approved words only with their approved meanings. | See rule 9.2 for the examples that matter most. |
| 1.4 | Use only the approved forms of verbs and adjectives. | The dictionary prints each verb's four forms and each adjective's comparative and superlative. |
| 1.5 | You can use words that you can include in a technical noun category. | 22 categories. Category 7 covers mathematical, scientific, and engineering terms. Category 12 covers parts of the body. Category 14 covers medical terms. Category 19 covers computer science and information technology. This project's vocabulary lands in 7, 12, 14, and 19. |
| 1.6 | Use a word that is not approved in the dictionary, only when it is a technical noun or part of a technical noun. | A word that the dictionary refuses can still enter as a technical noun. It cannot enter as ordinary prose. |
| 1.7 | Do not use words that are technical nouns as verbs. | Do not write "to radar" or "to force-plate". |
| 1.8 | Use technical nouns that are approved in your company, industry, or subject field. | The subject field here is wearable software (Garmin Connect IQ), embedded systems (Nordic nRF52840, Zephyr) and 60 GHz radar sensing. Use the words of the Garmin and vendor documents. |
| 1.9 | When you must select a technical noun, use one which is short and easy to understand. | Not more than three words (this is also rule 2.1). |
| 1.10 | Do not use regional, slang, or jargon words as technical nouns. | Lab shorthand is jargon. Write the full term the first time and keep it. |
| 1.11 | Do not use different technical nouns for the same item. | One item, one name, in the whole document. |
| 1.12 | You can use verbs that you can include in a technical verb category. | Four categories: manufacturing processes, computer processes and applications, instructions and information for applicable subject fields, and law and regulations. |
| 1.13 | Do not use technical verbs as nouns. | |
| 1.14 | Use American English spelling unless other official directives tell you differently. | No other directive applies by default, so use American spelling. If the team picks Canadian spelling for shared text, run the gate with `--canadian`. Never change the spelling inside a quotation. |

## Section 2: multi-word nouns (rules 2.1 to 2.2)

| Rule | Statement | In this project |
|---|---|---|
| 2.1 | Write multi-word nouns of no more than three words. | "Radar presence habit nudge service" is five. Divide it with a preposition: "the nudge service for radar presence". |
| 2.2 | When a technical noun has more than three words, write it in full. Then give a shorter form, or use hyphens between words that you use as one unit. | The hyphen is the cheap correction. "Time-of-flight depth camera" is one unit plus one noun. |

The standard's reason: the head noun is the last word, so each added modifier makes the reader
hold one more word before the meaning arrives. Readers whose first language puts the head noun
first carry the whole load twice.

## Section 3: verbs (rules 3.1 to 3.7)

| Rule | Statement | In this project |
|---|---|---|
| 3.1 | Use only the verb forms that are given in the dictionary. | |
| 3.2 | Use only the infinitive, the imperative, the simple present, the simple past, the simple future, and the past participle as an adjective. | No continuous tenses. "The pipeline is running" becomes "The pipeline operates". No perfect tenses. |
| 3.3 | Use the past participle form as an adjective. | |
| 3.4 | Do not use auxiliary verbs to make complex verb constructions. | "Would have been measured" is three auxiliaries. Divide the sentence. |
| 3.5 | Use the "-ing" form of a verb only as a technical noun or as a modifier in a technical noun. | "Clutter removal", not "removing clutter". |
| 3.6 | Use the active voice. In descriptive writing, you can use the passive voice only when the agent is unknown. | The standard gives four methods to remove the passive: name the agent, change an infinitive to an active verb, use the imperative, or use "you" or "we" as the subject. |
| 3.7 | Use an approved verb to describe an action, not a noun or other parts of speech. | "Before you remove the unit", not "before the removal of the unit". This one rule shortens most sentences. |

## Section 4: sentences (rules 4.1 to 4.5)

| Rule | Statement | In this project |
|---|---|---|
| 4.1 | Write short and clear sentences. | In procedures, give the instruction directly in the imperative. In descriptive text, one topic per sentence, and no imperative. |
| 4.2 | Do not omit words or use contractions to make your sentences shorter. | Do not drop the verb, the subject, or the article. Do not write "don't". |
| 4.3 | Use a vertical list for complex texts. | Colon before the list. Each item starts with a capital. A period only on an item that is a full sentence, and always on the last item. No comma and no semicolon at the end of an item. One list is one type: never mix a procedure and a description. |
| 4.4 | Use connecting words and connecting phrases to connect sentences that contain related topics. | Approved: "and", "but", "then", "thus". Approved phrases: "as a result", "at the same time". A sentence can start with "And" or "But" in STE. |
| 4.5 | When applicable, use an article or a demonstrative adjective before a noun or a multi-word noun. | Not before a general concept, and not before a noun that an alphanumeric identifier follows ("tag circuit breaker 36L7"). In a series, one article at the front means the adjective covers every item; an article on each item means it covers only the first. |

## Section 5: procedural writing (rules 5.1 to 5.5)

| Rule | Statement | In this project |
|---|---|---|
| 5.1 | Write short sentences. Use a maximum of 20 words in each sentence. | Safety instructions obey this too. |
| 5.2 | Write only one instruction in each sentence unless two or more actions occur at the same time. | Two sentences in one work step are permitted when the actions occur together, or when a result follows the action at once. |
| 5.3 | Write instructions in the imperative (command) form. | Do not put "must" before the imperative, unless the instruction is a safety instruction or an important condition. |
| 5.4 | When there is a condition that the reader must know about first, start the instruction with a descriptive statement. Then divide that statement from the command with a comma. | Condition first, comma, then the command. The position of the comma changes the meaning. |
| 5.5 | Write notes only to give information, not instructions. | Maximum 25 words per sentence in a note. No imperative. No limits, no tolerances, and no results in a note: those belong in the work step. **The test:** read the procedure without the notes. If the reader can still do it correctly, the notes are correct. |

## Section 6: descriptive writing (rules 6.1 to 6.6)

| Rule | Statement | In this project |
|---|---|---|
| 6.1 | Give information gradually. | Each sentence carries one subject. The next sentence adds to it. |
| 6.2 | Use key words and key phrases to give your text a logical structure. | Repeat the key word instead of finding a synonym. A synonym breaks the chain. |
| 6.3 | Write short sentences. Use a maximum of 25 words in each sentence. | This is the default limit for a chat reply, a report, and a note. |
| 6.4 | Use paragraphs to show related information. | A paragraph starts with a topic sentence. The rest of the paragraph explains it. |
| 6.5 | Make sure that each paragraph has only one topic. | If the reader copies out every topic sentence, the result must be a good outline of the document. That is the test. |
| 6.6 | Make sure that no paragraph has more than six sentences. | |

## Section 7: safety instructions (rules 7.1 to 7.3)

| Rule | Statement | In this project |
|---|---|---|
| 7.1 | Use an applicable word (for example, "warning" or "caution") to identify the level of risk. | A warning tells the reader that there is a risk of injury or death. A caution tells the reader that there is a risk of damage to objects. |
| 7.2 | Start a safety instruction with a clear and accurate command or condition. | |
| 7.3 | Give an explanation to show the risk or possible result. | In a vertical list, put the negative command on each item ("DO NOT ..."), not once above the list. |

Where this matters here: wiring and power-up of the boards (nRF52840-DK, USB host shield, radar
kit), flashing steps, and every instruction that a user of the app reads.

## Section 8: punctuation and word count (rules 8.1 to 8.7)

| Rule | Statement | In this project |
|---|---|---|
| 8.1 | You can use all standard English punctuation marks but not the semicolon. | The reason the standard gives: the semicolon lets you write very long sentences, and it is not easy to use correctly. Write two sentences. |
| 8.2 | Use hyphens to connect words that are directly related. | |
| 8.3 | You can use parentheses for a reference, an item number, a work-step number, an abbreviation, both number forms of a noun, an explanation, or an alternative. | |
| 8.4 | In a vertical list, a colon has the same effect on word count as a period and shows the end of a sentence. | |
| 8.5 | When you put text in parentheses, it counts as one word in that sentence. | |
| 8.6 | Count each of these as one word: numbers, numbers with units, abbreviations, alphanumeric identifiers, quoted text, titles and headings and labels, and proper nouns of individuals, groups, organizations, and geopolitical entities. | This is why a numbers-dense sentence is shorter than it looks. `code/ste_check.py` implements this counting. |
| 8.7 | Hyphenated words count as one word. | |

The standard gives no general punctuation rules of its own. It points to five reference books:
The Chicago Manual of Style, the Gregg Reference Manual, the U.S. GPO Style Manual, Swan's
Practical English Usage, and Kirkman's Punctuation Matters.

## Section 9: writing practices (rules 9.1 to 9.4)

| Rule | Statement | In this project |
|---|---|---|
| 9.1 | Use a different sentence construction when a word-for-word replacement is not sufficient. | If the alternative changes the meaning, or has a different part of speech, rebuild the sentence. Do not force the word in. |
| 9.2 | Use each approved word correctly. | An approved word usually has ONE approved meaning. See the meaning traps below. |
| 9.3 | When you use two words together, do not make phrasal verbs. | A phrasal verb has a meaning that its parts do not have. Only a few are approved, and they have a restricted meaning. |
| 9.4 | When you select terminology or wording, always use a consistent style. | The same action gets the same sentence pattern every time it occurs. Different wording for the same action causes confusion and delay. |

### Meaning traps that rule 9.2 names (all verified in part 1, pages 1-9-5 and 1-9-6)

| Do not write | Write | Why |
|---|---|---|
| wear protective clothing | use (or put on) protective clothing | "Wear" is approved with the meaning "to become damaged by friction". |
| this regulation extends to all units | this regulation is applicable to all units | "Extend" means to increase in dimension or range. |
| when the pressure goes down | when the pressure decreases | "Goes down" describes an indicator that moves, not the quantity. |
| move the tube to see if it is tight | move the tube to make sure that it is tight | "See" is only for what the eyes see. |
| the indicator turns green | the color of the indicator changes to green | "Turn" means to move around an axis or a point. |
| do not let the pressure go below 20 psi | do not let the pressure become less than 20 psi | "Above" and "below" are for physical positions, not limits. |
| when you work with cleaning agents | when you do work with cleaning agents | "Work" is an approved noun, not an approved verb. |
| with the help of a second person | with the aid of a second person | "Help" is an approved verb, not an approved noun. |
| be careful not to damage the sleeve | be careful not to cause damage to the sleeve | "Damage" is an approved noun, not an approved verb. |
| check the laptop battery | do a check of the laptop battery | "Check" is an approved noun, not an approved verb. |
| the ohmmeter gives an indication of 450 ohms | the ohmmeter shows 450 ohms | Rule 3.7: use the verb. |
| after you put out the fire | after you extinguish the fire | Rule 9.3: "put out" is a phrasal verb. |
| this compound can give off fumes | this compound can release fumes | Rule 9.3. |

## General recommendations GR-1 to GR-8

These are not rules. The standard gives them to prevent the errors writers make most.

| # | Subject | What to do |
|---|---|---|
| GR-1 | the conjunction "that" | Keep it. It shows where the main clause ends. It also helps translation, because many languages cannot omit it. Write "make sure **that** the valve is open". |
| GR-2 | the preposition "with" | It has three approved meanings and causes ambiguity. Read the sentence again. "Install the panel with the green fasteners" has three readings. Also, give the primary action verb: "seal the opening with tool TS9867", not "use tool TS9867 to seal the opening". |
| GR-3 | pronouns | If a pronoun can point at two nouns, write the noun again. Use only the pronouns in the dictionary. |
| GR-4 | the pronoun "this" | Make sure the reader knows what "this" points at. If it can point at two things, give the context again. |
| GR-5 | false friends | A word that looks like one in another language can mean something else in English. |
| GR-6 | Latin abbreviations | Do not use them. Write "for example", "that is", "and so on". Frequently you can delete them. |
| GR-7 | inclusive language | STE fully complies with gender-neutral language requirements. "He" and "she" are not permitted. "Man" and "woman" are not permitted unless the context makes them necessary, for example in a medical text. |
| GR-8 | the possessive form | It is permitted, but many languages have no equivalent. If you are not sure the sentence is correct, do not use it. |

**Note on GR-7 for this project.** Use role names (the user, the team, the judges). Never use a
gendered pronoun, and never a personal name.
