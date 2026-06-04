@echo off
git switch feature/harry
git add .
git commit -m "Feature fertig %date%"
git push origin feature/harry
echo.
echo Erledigt! Rolf kann jetzt deinen Stand holen.
pause