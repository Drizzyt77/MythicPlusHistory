# Changelog
## v1.1.0
- Added new season support
- Added filtering of per season tracked runs
- Added filtering of per season statistics
- Migrate database to set season ID for previously completed keys
- Fixed calculations for current and previous reset. Was using midnight as a reset time, now using exact reset timer for US/EU
- Added class color to the notes menu

## v1.1.1
- Fix bug with migration only working on reload

## v1.1.2
- Fixed issue in rare circumstances a run could double save improperly and save it under Season -1