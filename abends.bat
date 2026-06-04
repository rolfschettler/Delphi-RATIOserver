@echo off
git switch feature/harry
git add .
git commit -m "Tagesabschluss %date%"
git push origin feature/harry
echo.
echo Feierabend! Alles in git gesichert.
pause