@echo off
git switch feature/harry
if errorlevel 1 goto :fehler_switch

rem Offener Merge mit ungeloesten Konflikten? Dann nicht einfach alles adden.
git ls-files -u | findstr . >nul
if not errorlevel 1 goto :fehler_merge

git add .

rem Konfliktmarker im gestagten Stand? (git grep liefert 0, wenn etwas gefunden wurde)
git grep --cached -q -I -E "^(<<<<<<<|>>>>>>>) "
if not errorlevel 1 goto :fehler_marker

git commit -m "Feature fertig %date%"
git push origin feature/harry
if errorlevel 1 goto :fehler_push

echo.
echo Erledigt! Rolf kann jetzt deinen Stand holen.
pause
exit /b 0

:fehler_switch
echo.
echo ACHTUNG: Konnte nicht auf feature/harry wechseln - siehe Meldung oben.
echo Es wurde NICHTS gesichert. Bitte Rolf Bescheid geben.
pause
exit /b 1

:fehler_merge
echo.
echo ACHTUNG: Es laeuft ein Merge mit ungeloesten Konflikten in:
git diff --name-only --diff-filter=U
echo.
echo Es wurde NICHTS committet und NICHTS gepusht. Bitte Rolf Bescheid geben.
pause
exit /b 1

:fehler_marker
echo.
echo ACHTUNG: In folgenden Dateien stehen Konfliktmarker:
git grep --cached -l -I -E "^(<<<<<<<|>>>>>>>) "
echo.
echo Es wurde NICHTS committet und NICHTS gepusht. Bitte Rolf Bescheid geben.
pause
exit /b 1

:fehler_push
echo.
echo ACHTUNG: Commit ist lokal gespeichert, aber der Push zum Server hat NICHT geklappt.
echo Siehe Meldung oben. Bitte Rolf Bescheid geben.
pause
exit /b 1
