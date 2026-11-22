---
layout: default
title: WordReview Support
---

# WordReview Support

WordReview by MobileSoft helps you practise vocabulary through dictation, spelling and mistake review on iPhone and iPad.

[Privacy Policy](privacy.html)

## Getting started

1. Tap **Choose CSV File** and select a word list.
2. Choose the range of entries you want to practise.
3. Enable **Random question order** to shuffle the questions, or **Reverse exercise** to swap the two languages.
4. Select **Dictation** or **Spelling** to begin.

Complete the practice session to save incorrect answers. Use **Review Wrong Answers** to practise them again.

## Create or import word lists

Open **Edit Word Lists** to create a list, edit its entries or import a CSV file.

CSV files must use UTF-8 encoding. The first row names the languages of the two columns. Supported languages are English, French, Spanish and Chinese.

Example CSV content:

    English,French
    hello,bonjour
    thank you,merci
    goodbye,au revoir

Each exercise must contain text in both columns.

## Frequently asked questions

### How does dictation work?

WordReview reads the answer aloud using Apple's system speech synthesis. Type the text you hear. Tap the play button to hear it again.

If you cannot hear the pronunciation, check your device's volume and audio output. Voice availability depends on the voices installed on your device.

### How are answers checked?

Answer checking ignores letter case and extra spaces. Accents and language-specific characters are preserved.

Separate accepted alternatives with `|` or `｜` in your word list. For example, `hello|hi` accepts either answer.

### Where are my mistakes saved?

Incorrect answers are saved locally when you complete a practice session. Open **Review Wrong Answers** to filter, review or delete them.

Answering a mistake correctly during review removes it from the saved list.

### Where are my files stored?

Word lists are stored in the app's `Word_resource` folder. Saved mistakes are stored in `Data/Wrong.csv`.

These folders are accessible through the Files app in WordReview's local storage.

### Do I need an account?

No account or sign-in is required.

## Contact support

For help, bug reports or suggestions, email:

[shenok.smth@gmail.com](mailto:shenok.smth@gmail.com)

Please include your device model, iOS or iPadOS version, app version and the steps needed to reproduce the issue. Screenshots can help explain the problem.

Please remove personal or sensitive information before sending screenshots or word lists.
