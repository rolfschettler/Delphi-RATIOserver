@echo off
git switch feature/harry
if errorlevel 1 goto :fehler_switch

git pull --no-edit origin feature/harry
if errorlevel 1 goto :fehler_pull

rem Konfliktmarker im Stand? (git grep liefert 0, wenn etwas gefunden wurde)
git grep -q -I -E "^(<<<<<<<|>>>>>>>) "
if not errorlevel 1 goto :fehler_marker

echo.
echo Guten Morgen! Kannst los legen.
pause
exit /b 0

:fehler_switch
echo.
echo ACHTUNG: Konnte nicht auf feature/harry wechseln - siehe Meldung oben.
echo Bitte NICHT weiterarbeiten, sondern Rolf Bescheid geben.
pause
exit /b 1

:fehler_pull
echo.
echo ACHTUNG: Holen vom Server hat NICHT geklappt - siehe Meldung oben.
echo Moegliche Ursachen: eigene ungespeicherte Aenderungen oder Merge-Konflikte.
echo Bitte NICHT weiterarbeiten und NICHT abends.bat / fertig.bat starten,
echo sondern Rolf Bescheid geben.
pause
exit /b 1

:fehler_marker
echo.
echo ACHTUNG: In folgenden Dateien stehen Konfliktmarker:
git grep -l -I -E "^(<<<<<<<|>>>>>>>) "
echo.
echo Der Code kompiliert so nicht. Bitte NICHT weiterarbeiten und
echo NICHT abends.bat / fertig.bat starten, sondern Rolf Bescheid geben.
pause
exit /b 1
