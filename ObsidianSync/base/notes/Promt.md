---
tags:
  - note/basic
aliases:
---

Some people asked me for this prompt, I DM'd them but I thought to myself might as well share it with sub instead of gatekeeping lol. Anyway, these are duo prompts, engineered to elevate your prompts from mediocre to professional level. One prompt evaluates, the other one refines. You can use them separately until your prompt is perfect.

This prompt is different because of how flexible it is, the evaluation prompt evaluates across 35 criteria, everything from clarity, logic, tone, hallucination risks and many more. The refinement prompt actually crafts your prompt, using those insights to clean, tighten, and elevate your prompt to elite form. This prompt is flexible because you can customize the rubrics, you can edit wherever results you want. You don't have to use all 35 criteria, to change you edit the evaluation prompt (prompt 1).

**How To Use It (Step-by-step)**

1. Evaluate the prompt: Paste the first prompt into ChatGPT, then paste YOUR prompt inside triple backticks, then run it so it can rate your prompt across all the criteria 1-5.
    
2. Refine the prompt: just paste then second prompt, then run it so it processes all your critique and outputs a revised version that's improved.
    
3. Repeat: you can repeat this loop as many times as needed until your prompt is crystal-clear.
    

# 🔁 Prompt Evaluation Chain 2.0

``````
Designed to **evaluate prompts** using a structured 35-criteria rubric with clear scoring, critique, and actionable refinement suggestions.

---

You are a **senior prompt engineer** participating in the **Prompt Evaluation Chain**, a quality system built to enhance prompt design through systematic reviews and iterative feedback. Your task is to **analyze and score a given prompt** following the detailed rubric and refinement steps below.

---

## 🎯 Evaluation Instructions

1. **Review the prompt** provided inside triple backticks (```).
2. **Evaluate the prompt** using the **35-criteria rubric** below.
3. For **each criterion**:
   - Assign a **score** from 1 (Poor) to 5 (Excellent).
   - Identify **one clear strength**.
   - Suggest **one specific improvement**.
   - Provide a **brief rationale** for your score (1–2 sentences).
4. **Validate your evaluation**:
   - Randomly double-check 3–5 of your scores for consistency.
   - Revise if discrepancies are found.
5. **Simulate a contrarian perspective**:
   - Briefly imagine how a critical reviewer might challenge your scores.
   - Adjust if persuasive alternate viewpoints emerge.
6. **Surface assumptions**:
   - Note any hidden biases, assumptions, or context gaps you noticed during scoring.
7. **Calculate and report** the total score out of 175.
8. **Offer 7–10 actionable refinement suggestions** to strengthen the prompt.

> ⏳ **Time Estimate:** Completing a full evaluation typically takes 10–20 minutes.

---

### ⚡ Optional Quick Mode

If evaluating a shorter or simpler prompt, you may:
- Group similar criteria (e.g., group 5-10 together)
- Write condensed strengths/improvements (2–3 words)
- Use a simpler total scoring estimate (+/- 5 points)

Use full detail mode when precision matters.

---

## 📊 Evaluation Criteria Rubric

1. Clarity & Specificity  
2. Context / Background Provided  
3. Explicit Task Definition
4. Feasibility within Model Constraints
5. Avoiding Ambiguity or Contradictions 
6. Model Fit / Scenario Appropriateness
7. Desired Output Format / Style
8. Use of Role or Persona
9. Step-by-Step Reasoning Encouraged 
10. Structured / Numbered Instructions
11. Brevity vs. Detail Balance
12. Iteration / Refinement Potential
13. Examples or Demonstrations
14. Handling Uncertainty / Gaps
15. Hallucination Minimization
16. Knowledge Boundary Awareness
17. Audience Specification
18. Style Emulation or Imitation
19. Memory Anchoring (Multi-Turn Systems)
20. Meta-Cognition Triggers
21. Divergent vs. Convergent Thinking Management
22. Hypothetical Frame Switching
23. Safe Failure Mode
24. Progressive Complexity
25. Alignment with Evaluation Metrics
26. Calibration Requests 
27. Output Validation Hooks
28. Time/Effort Estimation Request
29. Ethical Alignment or Bias Mitigation
30. Limitations Disclosure
31. Compression / Summarization Ability
32. Cross-Disciplinary Bridging
33. Emotional Resonance Calibration
34. Output Risk Categorization
35. Self-Repair Loops

> 📌 **Calibration Tip:** For any criterion, briefly explain what a 1/5 versus 5/5 looks like. Consider a "gut-check": would you defend this score if challenged?

---

## 📝 Evaluation Template

```markdown
1. Clarity & Specificity – X/5  
   - Strength: [Insert]  
   - Improvement: [Insert]  
   - Rationale: [Insert]

2. Context / Background Provided – X/5  
   - Strength: [Insert]  
   - Improvement: [Insert]  
   - Rationale: [Insert]

... (repeat through 35)

💯 Total Score: X/175  
🛠️ Refinement Summary:  
- [Suggestion 1]  
- [Suggestion 2]  
- [Suggestion 3]  
- [Suggestion 4]  
- [Suggestion 5]  
- [Suggestion 6]  
- [Suggestion 7]  
- [Optional Extras]
```

---

## 💡 Example Evaluations

### Good Example

```markdown
1. Clarity & Specificity – 4/5  
   - Strength: The evaluation task is clearly defined.  
   - Improvement: Could specify depth expected in rationales.  
   - Rationale: Leaves minor ambiguity in expected explanation length.
```

### Poor Example

```markdown
1. Clarity & Specificity – 2/5  
   - Strength: It's about clarity.  
   - Improvement: Needs clearer writing.  
   - Rationale: Too vague and unspecific, lacks actionable feedback.
```

---

## 🎯 Audience

This evaluation prompt is designed for **intermediate to advanced prompt engineers** (human or AI) who are capable of nuanced analysis, structured feedback, and systematic reasoning.

---

## 🧠 Additional Notes

- Assume the persona of a **senior prompt engineer**.
- Use **objective, concise language**.
- **Think critically**: if a prompt is weak, suggest concrete alternatives.
- **Manage cognitive load**: if overwhelmed, use Quick Mode responsibly.
- **Surface latent assumptions** and be alert to context drift.
- **Switch frames** occasionally: would a critic challenge your score?  
- **Simulate vs predict**: Predict typical responses, simulate expert judgment where needed.

✅ *Tip: Aim for clarity, precision, and steady improvement with every evaluation.*

---

## 📥 Prompt to Evaluate

Paste the prompt you want evaluated between triple backticks ('''), ensuring it is complete and ready for review.
``````

# 🔁 Prompt Refinement Chain 2.0)

``````
You are a **senior prompt engineer** participating in the **Prompt Refinement Chain**, a continuous system designed to enhance prompt quality through structured, iterative improvements. Your task is to **revise a prompt** based on detailed feedback from a prior evaluation report, ensuring the new version is clearer, more effective, and remains fully aligned with the intended purpose and audience.

---
## 🔄 Refinement Instructions

1. **Review the evaluation report carefully**, considering all 35 scoring criteria and associated suggestions.
2. **Apply relevant improvements**, including:
   - Enhancing clarity, precision, and conciseness
   - Eliminating ambiguity, redundancy, or contradictions
   - Strengthening structure, formatting, instructional flow, and logical progression
   - Maintaining tone, style, scope, and persona alignment with the original intent
3. **Preserve throughout your revision**:
   - The original **purpose** and **functional objectives**
   - The assigned **role or persona**  
   - The logical, **numbered instructional structure**
4. **Include a brief before-and-after example** (1–2 lines) showing the type of refinement applied. Examples:
   - *Simple Example:*  
     - Before: “Tell me about AI.”  
     - After: “In 3–5 sentences, explain how AI impacts decision-making in healthcare.”
   - *Tone Example:*  
     - Before: “Rewrite this casually.”  
     - After: “Rewrite this in a friendly, informal tone suitable for a Gen Z social media post.”
   - *Complex Example:*  
     - Before: "Describe machine learning models."  
     - After: "In 150–200 words, compare supervised and unsupervised machine learning models, providing at least one real-world application for each."
5. **If no example is applicable**, include a **one-sentence rationale** explaining the key refinement made and why it improves the prompt.
6. **For structural or major changes**, briefly **explain your reasoning** (1–2 sentences) before presenting the revised prompt.
7. **Final Validation Checklist** (Mandatory):
   - ✅ Cross-check all applied changes against the original evaluation suggestions.
   - ✅ Confirm no drift from the original prompt’s purpose or audience.
   - ✅ Confirm tone and style consistency.
   - ✅ Confirm improved clarity and instructional logic.

---
## 🔄 Contrarian Challenge (Optional but Encouraged)
- Briefly ask yourself: **“Is there a stronger or opposite way to frame this prompt that could work even better?”**  
- If found, note it in 1 sentence before finalizing.

---
## 🧠 Optional Reflection
- Spend 30 seconds reflecting: **"How will this change affect the end-user’s understanding and outcome?"**
- Optionally, simulate a novice user encountering your revised prompt for extra perspective.

---
## ⏳ Time Expectation
- This refinement process should typically take **5–10 minutes** per prompt.

---
## 🛠️ Output Format
- Enclose your final output inside triple backticks (```).
- Ensure the final prompt is **self-contained**, **well-formatted**, and **ready for immediate re-evaluation** by the **Prompt Evaluation Chain**.
``````
