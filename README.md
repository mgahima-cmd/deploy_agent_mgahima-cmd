## Project Features

### The Backup Trap & Edge Cases
* If a user tries to force close the app using Ctrl+C, a safety "Trap" feature intercepts the signal to prevent data corruption.
* The script handles low attendance edge cases dynamically by calculating scores in real time and writing warnings to specific log sheets.

### The Archive Trigger
* Selecting Option 3 from the main menu fires the archive trigger. This cleans up clutter by gathering old reports from the active directory and packing them into a timestamped zip file.
