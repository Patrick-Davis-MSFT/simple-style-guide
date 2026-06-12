# Style Guide Foundry — User Guide

This guide walks you through using the **Style Guide Foundry** add-in for Microsoft Word. The add-in checks your document text against the government style guide and suggests corrections — including citations, formatting, dashes, ellipses, acronym usage, and more.

---

## Table of Contents

1. [Getting Started](#1-getting-started)
   - [Requirements](#requirements)
   - [Accessing the Add-in](#accessing-the-add-in)
2. [Opening the Plugin](#2-opening-the-plugin)
3. [Checking Your Text](#3-checking-your-text)
   - [Select Text in Your Document](#step-1--select-text-in-your-document)
   - [Run the Style Check](#step-2--run-the-style-check)
   - [Review the Results](#step-3--review-the-results)
4. [Working with Track Changes](#4-working-with-track-changes)
   - [Track Changes ON — Automatic Replacements](#track-changes-on--automatic-replacements)
   - [Track Changes OFF — Comments Only](#track-changes-off--comments-only)
5. [Making Changes to Your Document](#5-making-changes-to-your-document)
   - [Accepting Automatic Changes](#accepting-automatic-changes)
   - [Rejecting Automatic Changes](#rejecting-automatic-changes)
   - [Applying Suggestions Manually](#applying-suggestions-manually)
6. [Entering New Text and Re-checking](#6-entering-new-text-and-re-checking)
7. [Saving Your Document](#7-saving-your-document)
8. [Refreshing the Plugin](#8-refreshing-the-plugin)
9. [Closing and Re-opening the Plugin](#9-closing-and-re-opening-the-plugin)
10. [Troubleshooting](#10-troubleshooting)
11. [Frequently Asked Questions (FAQ)](#11-frequently-asked-questions-faq)

---

## 1. Getting Started

### Requirements

| Requirement | Details |
|---|---|
| **Microsoft Word** | Word for Windows (desktop), Word for Mac, or Word on the web (Office 365) |
| **Internet connection** | Required — the add-in communicates with an Azure-hosted service to analyze your text |
| **Add-in installed** | Your administrator must have deployed the add-in, or you sideload the manifest file |

### Accessing the Add-in

The Style Guide Foundry add-in is deployed by your organization's IT administrator. **You do not need to install anything.** The add-in is already available on your Word ribbon.

Simply open Microsoft Word and look for the **Open Style Guide** button on the **Home** tab. If you do not see it, try closing and reopening Word, or contact your IT administrator to confirm the add-in has been deployed to your account.

---

## 2. Opening the Plugin

1. Open a document in **Microsoft Word**.
2. Navigate to the **Home** tab on the ribbon.
3. Look for the **Style Guide** group on the right side of the ribbon.
4. Click the **Open Style Guide** button.

![The Home tab ribbon showing the Style Guide group with the Open Style Guide button](images/02-ribbon-button.png)
*Figure 2 — The "Open Style Guide" button on the Home tab ribbon.*

5. A **task pane** will open on the right side of your Word window, titled **Style Guide Foundry**.

![The Style Guide Foundry task pane open on the right side of the Word window](images/03-taskpane-open.png)
*Figure 3 — The Style Guide Foundry task pane after opening.*

---

## 3. Checking Your Text

### Step 1 — Select Text in Your Document

1. In your Word document, **highlight** (select) the text you want to check.
   - Click and drag to select a sentence, paragraph, or section.
   - You can also use **Ctrl+A** to select all text in the document.
2. The task pane will **automatically detect** your selection. You do not need to copy or paste anything.

![Text selected/highlighted in the Word document with the task pane visible on the right](images/04-select-text.png)
*Figure 4 — Select the text you want to check in your document.*

> **Tip:** Select at least 100 characters of text for the best results. Very short selections (a few words) may not produce meaningful style suggestions.

### Step 2 — Run the Style Check

1. With your text selected, look at the task pane on the right.
2. Click the **Run style check** button.

![The Run style check button highlighted in the task pane](images/05-run-style-check.png)
*Figure 5 — Click "Run style check" to analyze your selected text.*

3. A **spinning indicator** will appear with the text "Analyzing..." while your text is being processed.

![The task pane showing the Analyzing spinner](images/06-analyzing-spinner.png)
*Figure 6 — The add-in is analyzing your text. Please wait.*

> **Note:** Analysis typically takes a few seconds depending on the length of your text and your internet connection.

### Step 3 — Review the Results

Once the analysis is complete, the **Results** section in the task pane displays the suggested changes:

Each result card shows:

| Field | Description |
|---|---|
| **Change #** | A numbered label (Change 1, Change 2, etc.) |
| **Original text** | The exact text in your document that needs correction |
| **New text** | The style-guide-compliant replacement text |
| **Reason** | A brief explanation of why the change is needed, referencing the applicable style guide rule |

![Results displayed in the task pane showing Change 1 with Original text, New text, and Reason](images/07-results-panel.png)
*Figure 7 — Style check results showing suggested changes with reasons.*

> **Tip:** Scroll down in the task pane to see all results if there are many suggestions.

---

## 4. Working with Track Changes

The add-in behaves differently depending on whether **Track Changes** is turned on or off in Word.

### Track Changes ON — Automatic Replacements

When Track Changes is **enabled**:

1. The add-in **automatically replaces** the original text with the corrected text in your document.
2. Each replacement is tracked as a change (you will see red strikethrough for deleted text and colored new text).
3. A **comment** is added to each replacement explaining the change, including:
   - The original text
   - The new text
   - The reason for the change
   - A note that the text was automatically updated

![Document showing tracked changes with strikethrough original text and new replacement text, plus a comment bubble](images/08-track-changes-on.png)
*Figure 8 — With Track Changes ON, replacements are applied automatically and tracked.*

**To enable Track Changes:**
1. Go to the **Review** tab.
2. Click **Track Changes** (toggle it on).
3. Then select your text and run the style check.

![The Review tab with Track Changes button highlighted and toggled on](images/09-enable-track-changes.png)
*Figure 9 — Enable Track Changes from the Review tab before running a style check.*

### Track Changes OFF — Comments Only

When Track Changes is **disabled**:

1. The add-in **does not modify** your document text.
2. Instead, it adds a **comment** to the original text with the suggested correction.
3. You can review each comment and decide whether to apply the change manually.

![Document text unchanged with comment bubbles showing suggested corrections](images/10-track-changes-off.png)
*Figure 10 — With Track Changes OFF, comments are added but text is not modified.*

---

## 5. Making Changes to Your Document

### Accepting Automatic Changes

If Track Changes was **ON** and the add-in automatically replaced text:

1. Go to the **Review** tab.
2. Click on a tracked change in your document.
3. Click **Accept** to keep the change, or **Accept All Changes** to accept everything at once.

![The Review tab showing Accept and Accept All Changes buttons](images/11-accept-changes.png)
*Figure 11 — Accept individual changes or all changes from the Review tab.*

### Rejecting Automatic Changes

If you do not agree with a replacement:

1. Go to the **Review** tab.
2. Click on the tracked change you want to undo.
3. Click **Reject** to revert to the original text.

![The Review tab showing the Reject button for a tracked change](images/12-reject-changes.png)
*Figure 12 — Reject a change to revert to your original text.*

### Applying Suggestions Manually

If Track Changes was **OFF** (comments only):

1. Read the comment attached to the flagged text.
2. The comment includes the **Original text**, **New text**, and **Reason**.
3. Manually edit your document text to match the **New text** suggested in the comment.
4. Right-click the comment and select **Delete Comment** (or **Resolve**) once you have applied the change.

![A comment bubble with the suggestion and the right-click menu showing Delete Comment](images/13-apply-manual-change.png)
*Figure 13 — Read the comment, manually update the text, then delete or resolve the comment.*

---

## 6. Entering New Text and Re-checking

After making changes or adding new content to your document:

1. **Select** the new or updated text you want to check.
2. The task pane will automatically detect your new selection.
3. Click **Run style check** again.
4. Review the new set of results.

You can repeat this cycle as many times as needed:

```
Select text → Run style check → Review results → Edit document → Repeat
```

![Workflow diagram: Select Text → Run Style Check → Review Results → Edit → Repeat](images/14-workflow-cycle.png)
*Figure 14 — The iterative workflow for checking new or edited text.*

> **Tip:** You can check different sections of your document separately. Select one paragraph, run the check, then select the next paragraph and run it again.

---

## 7. Saving Your Document

The Style Guide Foundry add-in **does not automatically save** your document. After reviewing and accepting changes:

1. Press **Ctrl+S** (Windows) or **Cmd+S** (Mac) to save.
2. Or click **File** → **Save** / **Save As**.

> **Important:** Save your document after accepting or rejecting tracked changes to preserve your edits.

---

## 8. Refreshing the Plugin

If the plugin becomes unresponsive or you want to reset it:

### Method 1 — Close and Reopen

1. Click the **X** button on the top-right corner of the task pane to close it.
2. Click the **Open Style Guide** button on the Home ribbon to reopen it.

### Method 2 — Reload the Task Pane

1. Right-click inside the task pane.
2. If a **Reload** or **Refresh** option appears, click it.

![Right-click context menu in the task pane showing the Reload option](images/15-refresh-taskpane.png)
*Figure 15 — Right-click the task pane to find reload options.*

### Method 3 — Restart Word

If the above methods do not work:

1. Save your document (**Ctrl+S**).
2. Close Microsoft Word completely.
3. Reopen your document.
4. Click **Open Style Guide** on the Home ribbon.

---

## 9. Closing and Re-opening the Plugin

### Closing the Plugin

- Click the **X** in the top-right corner of the task pane.
- The plugin task pane will close, but your document remains unaffected.

### Re-opening the Plugin

- Go to the **Home** tab.
- Click **Open Style Guide** in the Style Guide group.
- The task pane will reopen; any previous results will be cleared and you can start a fresh check.

> **Note:** Closing the task pane does not lose any changes already applied to your document. It only clears the results display in the panel.

---

## 10. Troubleshooting

### "Run style check" button is grayed out / disabled

**Cause:** No text is selected in your document.

**Fix:** Highlight at least one sentence of text in your document. The button will become active once the add-in detects a selection.

![The Run style check button in disabled state with no text selected](images/16-button-disabled.png)
*Figure 16 — The button is disabled when no text is selected.*

---

### "Style check failed: API returned HTTP 401" or "HTTP 403"

**Cause:** The Azure backend service rejected the request.

**Fix:** Contact your administrator. They may need to check the deployment configuration.

---

### "Style check failed: Failed to fetch" or Network Error

**Cause:** No internet connection, or the Azure backend service is temporarily unavailable.

**Fix:**
1. Check your internet connection.
2. Try again in a few minutes.
3. If the problem persists, contact your administrator.

---

### "Office runtime is not available"

**Cause:** The add-in page was opened outside of Word (e.g., in a standalone browser tab).

**Fix:** The add-in must be opened from within Microsoft Word:
1. Close the standalone browser tab.
2. Open Word and click **Open Style Guide** from the ribbon.

---

### No results after running a style check

**Cause:** Your text may already comply with the style guide, or the selected text was too short.

**Fix:**
1. Try selecting a longer passage (100+ characters).
2. Verify that the text contains elements the style guide covers (citations, acronyms, formatting, etc.).

---

### Comments or tracked changes are not appearing

**Cause:** The Comments or Markup view may be hidden.

**Fix:**
1. Go to the **Review** tab.
2. Under **Tracking**, set the display to **All Markup**.
3. Ensure **Show Comments** is enabled.

![The Review tab with All Markup view and Show Comments enabled](images/17-show-markup.png)
*Figure 17 — Ensure "All Markup" view is enabled to see comments and tracked changes.*

---

## 11. Frequently Asked Questions (FAQ)

### Q: Does the add-in change my document without asking?

**A:** It depends on Track Changes:
- **Track Changes ON:** Yes, it replaces text automatically, but all changes are tracked so you can accept or reject each one.
- **Track Changes OFF:** No, it only adds comments. You make changes manually.

---

### Q: Can I check my entire document at once?

**A:** Yes. Press **Ctrl+A** to select all text in your document, then click **Run style check**. However, for very long documents, you may get better results checking section by section.

---

### Q: What style rules does the add-in check?

**A:** The add-in enforces the configured style guide, including:
- Citation formatting (U.S. Code, court decisions, administrative orders, proposed/final rules)
- Acronym usage (full name + abbreviation on first use)
- Dash rules (em dash vs. en dash)
- Ellipsis formatting
- Non-breaking spaces and hyphens
- Quotation formatting and footnotes
- URL and website citation formatting
- Widow/orphan text formatting
- And more

---

### Q: Does the add-in modify text inside quotation marks?

**A:** No. Direct quotations (text inside double or single quotes) are **never** modified, even if they contain style violations. Only text outside of quotations is corrected.

---

### Q: Can I use this add-in in Word on the web?

**A:** Yes. The add-in works in Word for Windows (desktop), Word for Mac, and Word on the web (Office 365). The experience is the same across platforms.

---

### Q: Who do I contact for support?

**A:** Contact your organization's IT administrator or the Style Guide Foundry project team for help with add-in availability, authentication issues, or feature requests.

---

## Quick Reference Card

| Action | How To |
|---|---|
| **Open the plugin** | Home tab → **Open Style Guide** button |
| **Select text to check** | Highlight text in your document (click and drag, or Ctrl+A for all) |
| **Run a style check** | Click **Run style check** in the task pane |
| **Auto-replace text** | Enable **Track Changes** (Review tab) before running the check |
| **Review suggestions only** | Disable Track Changes; the add-in adds comments instead |
| **Accept a change** | Review tab → click tracked change → **Accept** |
| **Reject a change** | Review tab → click tracked change → **Reject** |
| **Check new/edited text** | Select updated text → click **Run style check** again |
| **Save your document** | **Ctrl+S** (or File → Save) |
| **Refresh the plugin** | Close the task pane (X) → reopen via Home tab → **Open Style Guide** |
| **Close the plugin** | Click **X** on the task pane's top-right corner |

---

## Screenshots Reference

> **Note for maintainers:** Screenshots referenced in this guide should be placed in the `docs/images/` folder. Below is the list of required screenshots:

| File Name | Description |
|---|---|
| `02-ribbon-button.png` | Home tab ribbon with the "Open Style Guide" button visible in the Style Guide group |
| `03-taskpane-open.png` | The Style Guide Foundry task pane open on the right side of the Word window |
| `04-select-text.png` | Text highlighted/selected in a Word document with the task pane visible |
| `05-run-style-check.png` | The "Run style check" button in the task pane |
| `06-analyzing-spinner.png` | The "Analyzing..." spinner in the task pane |
| `07-results-panel.png` | Results displayed in the task pane with Change cards showing Original text, New text, and Reason |
| `08-track-changes-on.png` | Document with tracked changes (strikethrough + new text) and comments |
| `09-enable-track-changes.png` | The Review tab with Track Changes toggled on |
| `10-track-changes-off.png` | Document with comment bubbles (no text modifications) |
| `11-accept-changes.png` | The Review tab showing Accept / Accept All Changes buttons |
| `12-reject-changes.png` | The Review tab showing the Reject button |
| `13-apply-manual-change.png` | A comment bubble with right-click menu showing Delete Comment |
| `14-workflow-cycle.png` | Diagram showing the Select → Check → Review → Edit → Repeat cycle |
| `15-refresh-taskpane.png` | Right-click context menu inside the task pane |
| `16-button-disabled.png` | The "Run style check" button grayed out with no text selected |
| `17-show-markup.png` | The Review tab with "All Markup" and "Show Comments" enabled |

To capture these screenshots, open the add-in in Word, perform each action, and use **Snipping Tool** (Windows) or **Cmd+Shift+4** (Mac) to capture the relevant area.

---

*Last updated: March 2026*
