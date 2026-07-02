object WebModule1: TWebModule1
  OnCreate = WebModuleCreate
  OnDestroy = WebModuleDestroy
  Actions = <
    item
      Default = True
      Name = 'DefaultHandler'
      PathInfo = '/'
      OnAction = DefActionHandler
    end
    item
      Name = 'createtokenAction'
      PathInfo = '/createtoken'
      OnAction = WebModule1WebActionItem1Action
    end
    item
      Name = 'verifytokenAction'
      PathInfo = '/verifytoken'
      OnAction = WebModule1WebActionItem2Action
    end
    item
      Name = 'loginAction'
      PathInfo = '/login'
      OnAction = WebModule1WebActionItem3Action
    end
    item
      Name = 'docsAction'
      PathInfo = '/docs'
      OnAction = WebModule1WebActionItem4Action
    end
    item
      Name = 'HandbuchAction'
      PathInfo = '/handbuch'
      OnAction = WebModule1HandbuchActionAction
    end>
  BeforeDispatch = WebModuleBeforeDispatch
  OnException = WebModuleException
  Height = 230
  Width = 415
  object HelpPageProducer: TPageProducer
    HTMLDoc.Strings = (
      ''
      '# /login?user=(*benutzername*)&password=(*passwort*)'
      '<<POST, GET>>'
      'F'#252'hrt eine Anmeldung durch und liefert ein JWT-TOKEN zur'#252'ck'
      ''
      
        'POST [*Request*]: {"user":"*benutzername*","password":"*passwort' +
        '*"}'
      ''
      ''
      '[*Response:*] JSON'
      
        '{"token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJ3ZWJtb' +
        '2R1bGUtZGVtbyIsInN1YiI6Ik1XIiwiaWF0IjoxNzYxNTcy....."}'
      ''
      ''
      'Im Fehlerfall: Statuscode 401'
      
        '{"status":"error", "message":"Benutzername oder Passwort sind fa' +
        'lsch"}'
      ''
      
        '<div style="Font-size:large;color:red;font-weight:bold">gesch'#252'tz' +
        'te Endpunkte:</div>'
      ''
      '#/getparams'
      '<<POST, GET>>'
      
        'Listet alle Parameter des Apache-Servers inklusive der Verbindun' +
        'gsparameter der datenbank auf'
      
        'Hilfreich bei der Entwicklung. Kann mit beliebigen Request-Parem' +
        'tern augferufen werden'
      ''
      '<h5>Datenabfrage SQL </h5>'
      '# /select'
      '<<POST>>'
      'F'#252'hrt eine SQL-SELECT Abfrage durch. <b>(OPEN)</b>'
      ''
      '[*Request*]: Bodytext (Beispiel)'
      
        ' {* {"sql":"Select  from adressen where name2 like :name2 order ' +
        'by kennziffer desc ","params":{"name2":"May%"}} *}'
      ''
      '[*Response:*] JSON'
      
        'Header mit Felddefinitionen und dem Array aller angefragten Date' +
        'ns'#228'tze. (leeres Array wenn keine Datens'#228'tze)'
      
        'Hinweis : Feldtypen beziehen sich auf die Konstanten  "Data.DB.T' +
        'FieldType". <b>ACHTUNG</b>:Die Max. L'#228'nge befindet sich nur bei ' +
        'ftstring am Ende mit einem Leerzeichen getrennt!'
      'Beispiel:'
      '{*'
      '{'
      
        '&nbsp;  "header": {"nr": "ftinteger", "betrieb": "ftstring 8", "' +
        'bezeichnung": "ftstring 80" },'
      '&nbsp;&nbsp;"data":'
      '&nbsp;&nbsp;&nbsp;&nbsp;['
      
        '&nbsp;&nbsp;&nbsp;{"nr": 17, "betrieb": "A5", "bezeichnung": "Be' +
        'trieb A5"},'
      
        '&nbsp;&nbsp;&nbsp;{"nr": 18, "betrieb": "A6", "bezeichnung": "Be' +
        'trieb A6"}'
      '&nbsp;&nbsp;&nbsp;&nbsp;]'
      '}*}'
      'Im Fehlerfall: Statuscode 400'
      '{'
      '    "status": "error",'
      '    "message": "Der Grund des Fehlers""'
      '}'
      ''
      ''
      '# /select/withblob'
      '<<POST>>'
      
        'F'#252'hrt eine SQL-SELECT Abfrage durch und liefert das Ergebnis von' +
        ' BLOB-Feldern in Codierung <b>BASE64</b>.'
      
        'Per Default liefert "select" ohne "withblob" bei einem Blobfeld ' +
        'lediglich das Wort "BLOB" wenn das Feld einen Inhalt hat.'
      ''
      'Alles weitere siehe oben (select)'
      ''
      ''
      ''
      ''
      ''
      '# /execsql'
      '<<POST>>'
      'F'#252'hrt eine SQL-SELECT Abfrage durch. <b>(ExecSQL)</b>'
      ''
      '[*Request*]: Bodytext (Beispiel)'
      
        ' {* {"sql":"Select  from adressen where name2 like :name2 order ' +
        'by kennziffer desc ","params":{"name2":"May%"}} *}'
      ''
      '[*Response:*] JSON'
      'Ein Array aller angefragten Datens'#228'tze'
      ''
      'Im Fehlerfall: Statuscode 400'
      '{'
      '    "status": "error",'
      '    "message": "Der Grund des Fehlers""'
      '}'
      ''
      '<h5>UPDATE</h5>'
      ''
      
        '# /update?table=(*tabellenname*)&key=(*Feldname Prim'#228'rschl'#252'ssel*' +
        ')'
      '<<POST>>'
      #196'ndert einen bestehenden Datensatz'
      
        '<span style="color:red">ACHTUNG: Es d'#252'rfen KEINE Blobfelder im J' +
        'SON angegeben werden! (siehe /filetoblob bzw. /base64toblob)</sp' +
        'an>'
      ''
      '[*Request*]: Bodytext (Beispiel)'
      '{*'
      '    {'
      '     "nr": 17,'
      '     "betrieb": "A5",'
      '     "bezeichnung": "NIX"'
      '    }'
      '*}'
      ''
      ''
      'Im Fehlerfall: Statuscode 400'
      '{'
      '    "status": "error",'
      '    "message": "Der Grund des Fehlers""'
      '}'
      ''
      ''
      ''
      ''
      
        '# /filetoblob?table=(*tabellenname*)&keyfield=(*Feldname Prim'#228'rs' +
        'chl'#252'ssel*)&keyvalue=(*Wert des Prim'#228'rschl'#252'ssel*)&blobfield=(*Fel' +
        'dname Blobfeld*)'
      '<<POST>>'
      
        'L'#228'dt eine Datei in ein Blobfeld (Dateiupload). Der Datensatz mus' +
        's bereits existieren'
      'Es ist nur der Upload einer einzelnen Datei M'#246'glich.'
      ''
      
        '<div style="color:red">Wichtig: Der Request muss "form-data" (g'#252 +
        'ltiger Dateiupload) codiert sein!</div>'
      ''
      'URL-Beispiel:'
      '{*'
      '/filetoblob?table=bildtext&keyfield=nr&keyvalue=3&blobfield=bild'
      '*}'
      ''
      
        'Im Fehlerfall: Statuscode 400 (Datenbankerror) bzw. 500 Uploader' +
        'ror)'
      '{'
      '    "status": "error",'
      '    "message": "Der Grund des Fehlers""'
      '}'
      ''
      '<h5>INSERT</h5>'
      ''
      '# /insert?table=(*tabellenname*)'
      '<<POST>>'
      'F'#252'gt einen neuen Datensatz ein.'
      
        '<span style="color:red">ACHTUNG: Es d'#252'rfen KEINE Blobfelder im J' +
        'SON angegeben werden! (siehe /filetoblob bzw. /base64toblob)</sp' +
        'an>'
      ''
      '[*Request*]: Bodytext (Beispiel)'
      '{*'
      '    {'
      '    "nr":"1000",'
      '    "ZIEL":"timbucktu",'
      '    "reisenr":"880",'
      '    "reisevon":"01.01.2026",'
      '    "reisebis":"06.01.2026",'
      '    "pauschfaktor":"1"'
      '    }'
      '*}'
      '[*Response:*] JSON,'
      '{'
      '    "status": "OK",'
      '    "keyname": "NR",'
      '    "keyvalue": "53"'
      '}'
      ''
      'keyname: Der Name des Prim'#228'rschl'#252'ssels'
      
        'keyvalue: Der Wert den der neue Datensatz im Prim'#228'rschl'#252'ssel hat' +
        '.'
      ''
      'Im Fehlerfall: Statuscode 400'
      '{'
      '    "status": "error",'
      '    "message": "Der Grund des Fehlers""'
      '}'
      ''
      '<h5>DELETE </h5>'
      ''
      '# /delete?table=(*tabellenname*)'
      '<<POST>>'
      'L'#246'scht einen oder mehrerer Datens'#228'tze'
      ''
      '[*Request*]: Bodytext (Beispiel)'
      '{*'
      ''
      '{"nr": 16 }'
      ''
      '*}'
      ''
      
        'Es ist m'#246'glich, mehrere Felder im JSON einzutragen. Diese werden' +
        ' dann zu einem Filter mit AND verkn'#252'pft'
      
        '<span style="color:red">ACHTUNG: Es d'#252'rfen KEINE Blobfelder im J' +
        'SON angegeben werden! (Eine Filter auf ein Blobfeld l'#246'st im INTE' +
        'RBASE einen Fehler aus)</span>'
      ''
      '[*Response:*] JSON,'
      '{'
      '    "status": "OK"'
      '}'
      ''
      'Im Fehlerfall: Statuscode 400'
      '{'
      '    "status": "error",'
      '    "message": "Der Grund des Fehlers""'
      '}'
      ''
      ''
      ''
      ''
      '<h5>SQL-Ausf'#252'hren</h5>'
      ''
      ''
      '# /exec'
      '<<POST>>'
      
        'F'#252'hrt eine SQL-Anweisung aus (ExecSQL). Wichtig: Die SQL-Anweisu' +
        'ng darf KEINE Ergebnismenge zur'#252'ckliefern'
      ''
      '[*Request*]: Bodytext (Beispiel)'
      ''
      
        ' {* {"sql":"<span style="color:blue">update</span> adressen set ' +
        'name1='#39'Hulda'#39' where  name2=:name2","params":{"name2":"Mayer"}} *' +
        '}'
      ''
      
        ' <div style="color:red">  Folgendes w'#252'rde einen Fehler produzier' +
        'en (Weil Ergebnismenge) : </div>'
      ''
      
        ' {* {"sql":" <span style="color:red">Select</span>  from adresse' +
        'n where name2 like :name2 order by kennziffer desc ","params":{"' +
        'name2":"May%"}} *}'
      ''
      'Im Fehlerfall: Statuscode 400'
      '{'
      '    "status": "error",'
      '    "message": "Der Grund des Fehlers""'
      '}'
      ''
      ''
      '<h5>Datenbank-/ TabellenInfo</h5>'
      ''
      ''
      '#/tablestructure?table=(*tabellenname*)'
      '<<POST>>'
      ''
      '1. Gibt den Namen des Prim'#228'rschl'#252'ssel-Feldes an.'
      ''
      '2. Listet die detailierten Feldeigenschaften einer Tabelle auf.'
      
        'Folgende Informationen werden f'#252'r jedes Tabellenfeld zur'#252'ckgelie' +
        'fert:'
      ''
      'primarykey : Namen des Prim'#228'rschl'#252'ssel-Feldes'
      ''
      'field_name : Der Feldname'
      
        'field_type : Feldtyp  (Feldtypen beziehen sich auf die Konstante' +
        'n  "Data.DB.TFieldType")'
      'max_length : Max L'#228'nge (bei ftstring)'
      'not_null : NULL erlaubt (true oder false)'
      'default_value : Defaultwert'
      ''
      'Beispiel der Ausgabe:'
      '{*'
      ''
      '{'
      '    "primarykey": "nr",'
      '    "fields": ['
      '        {'
      '            "field_name": "nr",'
      '            "field_type": "ftinteger",'
      '            "max_length": null,'
      '            "not_null": true,'
      '            "default_value": null'
      '        },'
      '        {'
      '            "field_name": "bezeichnung",'
      '            "field_type": "ftfixedchar",'
      '            "max_length": 80,'
      '            "not_null": null,'
      '            "default_value": null'
      '        }'
      '    ]'
      '}'
      ''
      '*}')
    Left = 224
    Top = 72
  end
  object TitlePageProducer: TPageProducer
    HTMLDoc.Strings = (
      '<!DOCTYPE html>'
      '<html lang="de">'
      '<head>'
      '    <meta charset="UTF-8">'
      '    <title>RATIOserver</title>'
      
        '    <meta name="viewport" content="width=device-width, initial-s' +
        'cale=1.0">'
      ''
      
        '    <link href="https://fonts.googleapis.com/css2?family=Inter:w' +
        'ght@400;600;800&display=swap" rel="stylesheet">'
      ''
      '    <style>'
      '        * {'
      '            margin: 0;'
      '            padding: 0;'
      '            box-sizing: border-box;'
      '        }'
      ''
      '        body {'
      '            font-family: '#39'Inter'#39', sans-serif;'
      
        '            background: radial-gradient(circle at top left, #0f2' +
        'b4d, #081826 70%);'
      '            color: white;'
      '            display: flex;'
      '            justify-content: center;'
      '            align-items: center;'
      '            height: 100vh;'
      '            text-align: center;'
      '        }'
      ''
      '        .container {'
      '            max-width: 850px;'
      '            padding: 60px 40px;'
      '        }'
      ''
      '        h1 {'
      '            font-size: 4.5rem;'
      '            font-weight: 800;'
      '            letter-spacing: 2px;'
      '        }'
      ''
      '        .ratio {'
      
        '            background: linear-gradient(90deg, #4facfe, #00f2fe)' +
        ';'
      '            -webkit-background-clip: text;'
      '            -webkit-text-fill-color: transparent;'
      '        }'
      ''
      '        .server {'
      '            color: #d6eaff;'
      '            font-weight: 600;'
      '        }'
      ''
      '        /* Statement Animation */'
      '        .statement {'
      '            margin-top: 40px;'
      '            font-size: 1.6rem;'
      '            font-weight: 600;'
      '            line-height: 1.6;'
      '            opacity: 0;'
      '            transform: translateY(40px);'
      '            animation: slideUp 0.9s ease-out forwards;'
      '            animation-delay: 0.3s;'
      '        }'
      ''
      '        .statement span {'
      '            display: block;'
      '        }'
      ''
      '        @keyframes slideUp {'
      '            to {'
      '                opacity: 1;'
      '                transform: translateY(0);'
      '            }'
      '        }'
      ''
      '        h2 {'
      '            margin-top: 35px;'
      '            font-weight: 400;'
      '            font-size: 0.95rem;'
      '            opacity: 0.6;'
      '            letter-spacing: 1px;'
      '        }'
      ''
      '        .separator {'
      '            margin: 60px auto 40px auto;'
      '            width: 120px;'
      '            height: 2px;'
      
        '            background: linear-gradient(90deg, transparent, #4fa' +
        'cfe, #00f2fe, transparent);'
      '            border-radius: 2px;'
      '            opacity: 0.8;'
      '        }'
      ''
      '        .company {'
      '            font-size: 1.4rem;'
      '            font-weight: 600;'
      '            letter-spacing: 1px;'
      '        }'
      ''
      '        .slogan {'
      '            margin-top: 15px;'
      '            font-size: 1rem;'
      '            opacity: 0.7;'
      '        }'
      ''
      '        /* Button */'
      '        .cta-button {'
      '            display: inline-block;'
      '            margin-top: 40px;'
      '            padding: 14px 32px;'
      '            font-size: 1rem;'
      '            font-weight: 600;'
      '            text-decoration: none;'
      '            color: #081826;'
      
        '            background: linear-gradient(90deg, #4facfe, #00f2fe)' +
        ';'
      '            border-radius: 50px;'
      '            transition: all 0.3s ease;'
      '            box-shadow: 0 10px 25px rgba(0, 150, 255, 0.3);'
      '        }'
      ''
      '        .cta-button:hover {'
      '            transform: translateY(-3px);'
      '            box-shadow: 0 15px 35px rgba(0, 150, 255, 0.5);'
      '        }'
      ''
      '        @media (max-width: 600px) {'
      '            h1 {'
      '                font-size: 2.8rem;'
      '            }'
      ''
      '            .statement {'
      '                font-size: 1.2rem;'
      '            }'
      '        }'
      '    </style>'
      '</head>'
      '<body>'
      ''
      '    <div class="container">'
      '        <h1>'
      
        '            <span class="ratio">RATIO</span><span class="server"' +
        '>server</span>'
      '        </h1>'
      ''
      '        <div class="statement">'
      '            <span>Powerful. Fast. Secure.</span>'
      '            <span>Data & Report API.</span>'
      '        </div>'
      ''
      '        <h2>powered by Apache</h2>'
      ''
      '        <div class="separator"></div>'
      ''
      '        <div class="company">Konzeptdata</div>'
      ''
      '        <div class="slogan">'
      '            Solide Software f'#252'r solide Unternehmen'
      '        </div>'
      ''
      '        <a href="/ibapi/docs" class="cta-button">'
      '            View Documentation'
      '        </a>'
      ''
      '    </div>'
      ''
      '</body>'
      '</html>')
    OnHTMLTag = TitlePageProducerHTMLTag
    Left = 80
    Top = 128
  end
  object HandbuchPageProducer: TPageProducer
    HTMLDoc.Strings = (
      '<!DOCTYPE html>'
      '<html lang="de">'
      '<head>'
      '<meta charset="UTF-8">'
      
        '<meta name="viewport" content="width=device-width, initial-scale' +
        '=1.0">'
      '<title>RATIOserver API '#8211' CRUD-Handbuch</title>'
      '<style>'
      '  :root {'
      '    --bg: #ffffff;'
      '    --bg-alt: #f5f6f8;'
      '    --border: #dde1e6;'
      '    --text: #1f2430;'
      '    --text-mute: #5b6270;'
      '    --accent: #2563eb;'
      '    --ok: #157347;'
      '    --err: #b3261e;'
      '    --code-bg: #1e2230;'
      '    --code-text: #e6e8ef;'
      '    --radius: 6px;'
      '  }'
      ''
      '  * { box-sizing: border-box; }'
      ''
      '  body {'
      '    margin: 0;'
      '    font-family: "Segoe UI", Arial, sans-serif;'
      '    color: var(--text);'
      '    background: var(--bg);'
      '    line-height: 1.55;'
      '  }'
      ''
      '  .layout {'
      '    display: grid;'
      '    grid-template-columns: 260px 1fr;'
      '    max-width: 1200px;'
      '    margin: 0 auto;'
      '  }'
      ''
      '  nav {'
      '    border-right: 1px solid var(--border);'
      '    padding: 24px 16px;'
      '    position: sticky;'
      '    top: 0;'
      '    align-self: start;'
      '    height: 100vh;'
      '    overflow-y: auto;'
      '  }'
      ''
      '  nav h2 {'
      '    font-size: 13px;'
      '    text-transform: uppercase;'
      '    letter-spacing: .05em;'
      '    color: var(--text-mute);'
      '    margin: 0 0 12px;'
      '  }'
      ''
      '  nav ul {'
      '    list-style: none;'
      '    margin: 0 0 20px;'
      '    padding: 0;'
      '  }'
      ''
      '  nav a {'
      '    display: block;'
      '    padding: 6px 8px;'
      '    border-radius: var(--radius);'
      '    color: var(--text);'
      '    text-decoration: none;'
      '    font-size: 14px;'
      '  }'
      ''
      '  nav a:hover { background: var(--bg-alt); }'
      ''
      '  main {'
      '    padding: 32px 40px 80px;'
      '    max-width: 840px;'
      '  }'
      ''
      '  header.title {'
      '    margin-bottom: 40px;'
      '    padding-bottom: 20px;'
      '    border-bottom: 2px solid var(--text);'
      '  }'
      ''
      '  header.title h1 {'
      '    margin: 0 0 6px;'
      '    font-size: 28px;'
      '  }'
      ''
      '  header.title p {'
      '    margin: 0;'
      '    color: var(--text-mute);'
      '    font-size: 15px;'
      '  }'
      ''
      '  section {'
      '    margin-bottom: 44px;'
      '    scroll-margin-top: 20px;'
      '  }'
      ''
      '  h2 {'
      '    font-size: 20px;'
      '    border-left: 4px solid var(--accent);'
      '    padding-left: 12px;'
      '    margin: 0 0 16px;'
      '  }'
      ''
      '  h3 {'
      '    font-size: 15px;'
      '    margin: 20px 0 8px;'
      '  }'
      ''
      '  p { margin: 0 0 12px; }'
      ''
      '  ul, ol { margin: 0 0 12px; padding-left: 22px; }'
      '  li { margin-bottom: 4px; }'
      ''
      '  code {'
      '    font-family: "Consolas", "Cascadia Code", monospace;'
      '    background: var(--bg-alt);'
      '    padding: 1px 6px;'
      '    border-radius: 4px;'
      '    font-size: 13px;'
      '  }'
      ''
      '  pre {'
      '    background: var(--code-bg);'
      '    color: var(--code-text);'
      '    padding: 14px 16px;'
      '    border-radius: var(--radius);'
      '    overflow-x: auto;'
      '    font-size: 13px;'
      '    line-height: 1.5;'
      '    margin: 0 0 16px;'
      '  }'
      ''
      '  pre code {'
      '    background: none;'
      '    padding: 0;'
      '    color: inherit;'
      '  }'
      ''
      '  table {'
      '    width: 100%;'
      '    border-collapse: collapse;'
      '    margin: 0 0 16px;'
      '    font-size: 14px;'
      '  }'
      ''
      '  th, td {'
      '    border: 1px solid var(--border);'
      '    padding: 8px 10px;'
      '    text-align: left;'
      '    vertical-align: top;'
      '  }'
      ''
      '  th {'
      '    background: var(--bg-alt);'
      '    font-weight: 600;'
      '  }'
      ''
      '  .badge {'
      '    display: inline-block;'
      '    font-size: 12px;'
      '    font-weight: 600;'
      '    padding: 2px 8px;'
      '    border-radius: 4px;'
      '  }'
      ''
      '  .badge-ok { background: #e7f5ec; color: var(--ok); }'
      '  .badge-err { background: #fbe9e7; color: var(--err); }'
      '  .badge-warn { background: #fff4e5; color: #a15c00; }'
      ''
      '  .callout {'
      '    border: 1px solid var(--border);'
      '    border-left: 4px solid #a15c00;'
      '    background: #fffaf0;'
      '    padding: 12px 16px;'
      '    border-radius: var(--radius);'
      '    margin: 0 0 16px;'
      '    font-size: 14px;'
      '  }'
      ''
      '  .callout strong { display: block; margin-bottom: 4px; }'
      ''
      '  .flow {'
      '    counter-reset: step;'
      '    list-style: none;'
      '    padding-left: 0;'
      '  }'
      ''
      '  .flow li {'
      '    position: relative;'
      '    padding-left: 36px;'
      '    margin-bottom: 10px;'
      '  }'
      ''
      '  .flow li::before {'
      '    counter-increment: step;'
      '    content: counter(step);'
      '    position: absolute;'
      '    left: 0;'
      '    top: 0;'
      '    width: 24px;'
      '    height: 24px;'
      '    border-radius: 50%;'
      '    background: var(--accent);'
      '    color: #fff;'
      '    font-size: 13px;'
      '    font-weight: 600;'
      '    display: flex;'
      '    align-items: center;'
      '    justify-content: center;'
      '  }'
      ''
      '  footer {'
      '    color: var(--text-mute);'
      '    font-size: 13px;'
      '    border-top: 1px solid var(--border);'
      '    padding-top: 16px;'
      '    margin-top: 40px;'
      '  }'
      ''
      '  @media (max-width: 800px) {'
      '    .layout { grid-template-columns: 1fr; }'
      
        '    nav { position: static; height: auto; border-right: none; bo' +
        'rder-bottom: 1px solid var(--border); }'
      '    main { padding: 24px 20px 60px; }'
      '  }'
      '</style>'
      '</head>'
      '<body>'
      '<div class="layout">'
      ''
      '  <nav>'
      '    <h2>Inhalt</h2>'
      '    <ul>'
      '      <li><a href="#grundprinzip">1. Grundprinzip</a></li>'
      
        '      <li><a href="#endpunkttypen">2. Die 7 Endpunkttypen</a></l' +
        'i>'
      '      <li><a href="#felder">3. Feldliste (fields)</a></li>'
      
        '      <li><a href="#filter">4. Filterparameter (filtered)</a></l' +
        'i>'
      '      <li><a href="#erfolg">5. Antwort im Erfolgsfall</a></li>'
      '      <li><a href="#fehler">6. Antwort im Fehlerfall</a></li>'
      '      <li><a href="#beispiele">7. Beispiele (curl)</a></li>'
      '      <li><a href="#pagination">8. Pagination</a></li>'
      '    </ul>'
      '  </nav>'
      ''
      '  <main>'
      '    <header class="title">'
      '      <h1>RATIOserver API '#8211' CRUD-Handbuch</h1>'
      
        '      <p>Referenz f'#252'r Aufruf und Auswertung der Standard-CRUD-En' +
        'dpunkte (get / getFiltered / getById / getKey / insert / update ' +
        '/ delete)</p>'
      '    </header>'
      ''
      '    <section id="grundprinzip">'
      '      <h2>1. Grundprinzip</h2>'
      
        '      <p>Alle CRUD-Endpunkte folgen demselben Muster, unabh'#228'ngig' +
        ' von Modul oder Entit'#228't:</p>'
      '      <table>'
      '        <tr><th>Punkt</th><th>Regel</th></tr>'
      
        '        <tr><td>HTTP-Methode</td><td>Immer <code>POST</code> '#8211' a' +
        'uch bei den <code>get*</code>-Endpunkten. Parameter stehen im Bo' +
        'dy, nicht im Query-String.</td></tr>'
      
        '        <tr><td>Content-Type</td><td>Request und Response immer ' +
        '<code>application/json</code></td></tr>'
      
        '        <tr><td>Body</td><td>Immer ein JSON-Objekt, auch wenn ke' +
        'ine Parameter n'#246'tig sind: <code>{}</code></td></tr>'
      
        '        <tr><td>Auth</td><td>Header <code>Authorization: Bearer ' +
        '&lt;jwttoken&gt;</code>, au'#223'er bei Routen mit <code>Auth=false</' +
        'code></td></tr>'
      
        '        <tr><td>URL-Schema</td><td><code>{{baseURL}}/&lt;modul&g' +
        't;/&lt;methode&gt;</code>, z. B. <code>http://localhost/ibapi/do' +
        'kumente/getvorlagen</code></td></tr>'
      '      </table>'
      
        '      <p><code>&lt;modul&gt;</code> ist der Controller-Bereich (' +
        'z. B. <code>dokumente</code>, <code>toupac</code>, <code>adresse' +
        'n</code>, <code>anmiet</code>, <code>fuhrpark</code>, <code>inco' +
        'ming</code>), <code>&lt;methode&gt;</code> der Endpunktname klei' +
        'n geschrieben.</p>'
      '    </section>'
      ''
      '    <section id="endpunkttypen">'
      '      <h2>2. Die 7 Standard-Endpunkttypen</h2>'
      
        '      <p>Pro Entit'#228't <code>&lt;Entity&gt;</code> (Tabellenname) ' +
        'existieren i. d. R. diese sieben Endpunkte:</p>'
      '      <table>'
      
        '        <tr><th>Endpunkt</th><th>Zweck</th><th>Beispiel-Body</th' +
        '></tr>'
      
        '        <tr><td><code>get&lt;entity&gt;</code></td><td>Liste all' +
        'er Datens'#228'tze</td><td><code>{"fields":["nr","name"],"orderby":"n' +
        'ame"}</code></td></tr>'
      
        '        <tr><td><code>get&lt;entity&gt;filtered</code></td><td>L' +
        'iste, gefiltert nach optionalen Parametern (Abschnitt 4)</td><td' +
        '><code>{"fields":"*","art":"BRIEF","orderby":"name"}</code></td>' +
        '</tr>'
      
        '        <tr><td><code>get&lt;entity&gt;byid</code></td><td>Einze' +
        'lner Datensatz '#252'ber Prim'#228'rschl'#252'ssel</td><td><code>{"nr":1,"field' +
        's":"*"}</code></td></tr>'
      
        '        <tr><td><code>get&lt;entity&gt;key</code></td><td>N'#228'chst' +
        'en freien Schl'#252'sselwert (Generator) ermitteln</td><td><code>{}</' +
        'code></td></tr>'
      
        '        <tr><td><code>insert&lt;entity&gt;</code></td><td>Neuen ' +
        'Datensatz anlegen</td><td><code>{"name":"...","art":"BRIEF"}</co' +
        'de></td></tr>'
      
        '        <tr><td><code>update&lt;entity&gt;</code></td><td>Besteh' +
        'enden Datensatz '#228'ndern</td><td><code>{"nr":1,"name":"Neuer Wert"' +
        '}</code></td></tr>'
      
        '        <tr><td><code>delete&lt;entity&gt;</code></td><td>Datens' +
        'atz l'#246'schen</td><td><code>{"nr":1}</code></td></tr>'
      '      </table>'
      ''
      
        '      <h3>Zus'#228'tzliche Steuerparameter (alle lesenden Endpunkte)<' +
        '/h3>'
      '      <ul>'
      '        <li><code>fields</code> '#8211' siehe Abschnitt 3</li>'
      
        '        <li><code>orderby</code> '#8211' Sortierfeld, muss ein erlaubt' +
        'es Feld sein, sonst <code>Sortierfeld "..." ist nicht erlaubt.</' +
        'code></li>'
      
        '        <li><code>limit</code> / <code>offset</code> '#8211' Paginatio' +
        'n, nur bei <code>get&lt;entity&gt;</code> und <code>...filtered<' +
        '/code> (Abschnitt 8). Ohne <code>limit</code> (bzw. <code>limit:' +
        '0</code>) werden alle Datens'#228'tze geliefert.</li>'
      '      </ul>'
      '    </section>'
      ''
      '    <section id="felder">'
      '      <h2>3. Feldliste (<code>fields</code>)</h2>'
      '      <p>'
      
        '        Jeder lesende Endpunkt hat eine im Server-Code fest hint' +
        'erlegte Whitelist erlaubter Felder'
      
        '        (ersichtlich aus Postman-Collection bzw. Quellcode des E' +
        'ndpunkts). <code>fields</code> steuert,'
      
        '        welche dieser Felder in der Antwort landen '#8211' nicht, wona' +
        'ch gefiltert wird.'
      '      </p>'
      '      <table>'
      
        '        <tr><th>Wert von <code>fields</code></th><th>Bedeutung</' +
        'th></tr>'
      
        '        <tr><td><code>"*"</code></td><td>Alle f'#252'r diesen Endpunk' +
        't erlaubten Felder</td></tr>'
      
        '        <tr><td><code>["feld1","feld2"]</code></td><td>Nur die g' +
        'enannten Felder '#8211' jedes muss in der Whitelist stehen</td></tr>'
      
        '        <tr><td>Schl'#252'ssel fehlt ganz</td><td>Verhalten wie <code' +
        '>"*"</code></td></tr>'
      
        '        <tr><td><code>[]</code></td><td><span class="badge badge' +
        '-warn">Fehler</span> <code>Keine Felder angegeben.</code></td></' +
        'tr>'
      
        '        <tr><td>Feldname nicht in Whitelist</td><td><span class=' +
        '"badge badge-warn">Fehler</span> <code>Feld "&lt;name&gt;" ist n' +
        'icht erlaubt.</code></td></tr>'
      
        '        <tr><td>weder <code>"*"</code> noch Array</td><td><span ' +
        'class="badge badge-warn">Fehler</span> <code>"fields" muss "*" o' +
        'der ein JSON-Array sein.</code></td></tr>'
      '      </table>'
      
        '      <p>Alle Fehler dieser Kategorie kommen mit HTTP 200 '#8211' dazu' +
        ' mehr in Abschnitt 6.</p>'
      '    </section>'
      ''
      '    <section id="filter">'
      
        '      <h2>4. Filterparameter bei <code>get&lt;entity&gt;filtered' +
        '</code></h2>'
      '      <p>'
      
        '        Liefert dieselbe Grundliste wie <code>get&lt;entity&gt;<' +
        '/code>, zus'#228'tzlich beliebig viele'
      
        '        Filterbedingungen m'#246'glich. Auch hier gilt eine endpunkts' +
        'pezifische Whitelist m'#246'glicher Filterfelder.'
      '      </p>'
      '      <ul>'
      
        '        <li>Ein Filterfeld wirkt nur, wenn es im Body vorhanden ' +
        'und nicht <code>null</code> ist.</li>'
      
        '        <li>Fehlt ein Filterfeld, entf'#228'llt die Einschr'#228'nkung ers' +
        'atzlos '#8211' kein Fehler.</li>'
      
        '        <li>Mehrere Filter werden immer mit <strong>AND</strong>' +
        ' verkn'#252'pft, kein OR '#252'ber den Standardmechanismus.</li>'
      
        '        <li>Kein Filter gesetzt '#8658' Verhalten identisch zu <code>g' +
        'et&lt;entity&gt;</code>.</li>'
      
        '        <li>Jeder Filter pr'#252'ft auf Gleichheit (<code>feld = wert' +
        '</code>), keine Bereichs-/Vergleichsoperatoren, sofern nicht and' +
        'ers dokumentiert.</li>'
      
        '        <li>Ein Feld im Body, das nicht zu den definierten Filte' +
        'rfeldern geh'#246'rt, wird stillschweigend ignoriert.</li>'
      '      </ul>'
      '      <pre><code>// Kein Filter -> alle Datens'#228'tze'
      '{ "fields": "*" }'
      ''
      '// Ein Filter -> art = "BRIEF"'
      '{ "fields": "*", "art": "BRIEF" }'
      ''
      '// Zwei Filter (UND) -> art = "BRIEF" UND bereich = "EINGANG"'
      
        '{ "fields": "*", "art": "BRIEF", "bereich": "EINGANG" }</code></' +
        'pre>'
      ''
      '      <h3>DoSelectFilteredDynamic-Endpunkte</h3>'
      '      <p>'
      
        '        Die meisten <code>...filtered</code>-Endpunkte sind serv' +
        'erseitig '#252'ber'
      
        '        <code>DoSelectFilteredDynamic</code> implementiert. Filt' +
        'erfelder und SQL-Bedingung sind als zwei'
      '        parallele Listen im Server-Code hinterlegt:'
      '      </p>'
      
        '      <pre><code>CONDITIONS:     array[0..1] of string = ('#39'Field' +
        '1 = :Field1'#39', '#39'Field2 = :Field2'#39');'
      
        'FILTER_PARAMS:  array[0..1] of string = ('#39'Field1'#39', '#39'Field2'#39');</c' +
        'ode></pre>'
      '      <ul>'
      
        '        <li><strong>Pr'#252'freihenfolge:</strong> nach der im Code f' +
        'estgelegten Reihenfolge (<code>FILTER_PARAMS[0]</code>, <code>[1' +
        ']</code>, ...), nicht nach der Reihenfolge im JSON-Body.</li>'
      
        '        <li><strong>Verkettung:</strong> jeder vorhandene, nicht' +
        '-<code>null</code> Parameter wird als <code>(CONDITIONS[i])</cod' +
        'e> angeh'#228'ngt, alle Bedingungen zusammen per <code>AND</code>: <c' +
        'ode>WHERE (Bedingung_A) AND (Bedingung_B) ...</code></li>'
      
        '        <li><strong>Fehlender Parameter:</strong> Bedingung entf' +
        #228'llt komplett aus der WHERE-Klausel (nicht <code>IS NULL</code>,' +
        ' taucht im generierten SQL gar nicht auf).</li>'
      
        '        <li><strong>Kein Parameter gesetzt:</strong> WHERE-Klaus' +
        'el leer, Verhalten wie <code>get&lt;entity&gt;</code>.</li>'
      '      </ul>'
      '      <div class="callout">'
      '        <strong>Reihenfolge im Body ist irrelevant</strong>'
      
        '        <code>{"art":"BRIEF","bereich":"EINGANG"}</code> und <co' +
        'de>{"bereich":"EINGANG","art":"BRIEF"}</code>'
      
        '        erzeugen exakt dieselbe WHERE-Klausel <code>(art = :art)' +
        ' AND (bereich = :bereich)</code>, da die'
      
        '        Verkettungsreihenfolge durch <code>FILTER_PARAMS</code>/' +
        '<code>CONDITIONS</code> im Server-Code'
      '        vorgegeben ist '#8211' nicht durch den Request.'
      '      </div>'
      '    </section>'
      ''
      '    <section id="erfolg">'
      '      <h2>5. Antwort im Erfolgsfall</h2>'
      ''
      '      <h3>a) Leseoperationen ohne Pagination</h3>'
      
        '      <p><code>get&lt;entity&gt;</code>, <code>...filtered</code' +
        '>, <code>...byid</code>, <code>...key</code> '#8211' jeweils ohne <cod' +
        'e>limit</code>. <span class="badge badge-ok">HTTP 200</span></p>'
      '      <pre><code>{'
      '  "header": {'
      '    "nr": "ftinteger",'
      '    "name": "ftstring 100",'
      '    "erstelltam": "ftdate",'
      '    "menge": "ftfloat"'
      '  },'
      '  "data": ['
      
        '    { "nr": 1, "name": "Beispiel", "erstelltam": "2026-07-01", "' +
        'menge": 3.5 },'
      
        '    { "nr": 2, "name": "Zweiter Eintrag", "erstelltam": null, "m' +
        'enge": 0 }'
      '  ]'
      '}</code></pre>'
      '      <ul>'
      
        '        <li><code>header</code>: Feldname '#8594' Datentyp (<code>ftst' +
        'ring N</code>, <code>ftinteger</code>, <code>ftfloat</code>, <co' +
        'de>ftdate</code>, <code>ftdatetime</code>, <code>ftblob</code>).' +
        '</li>'
      
        '        <li><code>data</code>: Array der Datens'#228'tze, Feldnamen k' +
        'lein geschrieben; <code>NULL</code> als JSON <code>null</code>.<' +
        '/li>'
      
        '        <li>Datumsfelder als <code>"yyyy-mm-dd"</code>, Zeitstem' +
        'pel als <code>"yyyy-mm-dd hh:nn:ss"</code>.</li>'
      '        <li>BLOB-Felder als Base64-String.</li>'
      
        '        <li>Kein Treffer (z. B. Filter passt auf nichts) '#8658' kein ' +
        'Fehler, sondern <code>"data": []</code>.</li>'
      '      </ul>'
      ''
      '      <h3>b) Leseoperationen mit Pagination</h3>'
      
        '      <p><code>get&lt;entity&gt;</code> / <code>...filtered</cod' +
        'e> mit <code>limit &gt; 0</code>. <span class="badge badge-ok">H' +
        'TTP 200</span></p>'
      '      <pre><code>{'
      '  "total": 137,'
      '  "limit": 20,'
      '  "offset": 0,'
      '  "data": {'
      '    "header": { "nr": "ftinteger", "name": "ftstring 100" },'
      '    "data": [ { "nr": 1, "name": "Beispiel" } ]'
      '  }'
      '}</code></pre>'
      '      <div class="callout">'
      '        <strong>Verschachtelte Struktur</strong>'
      
        '        <code>header</code>/<code>data</code> liegen hier unter ' +
        '<code>data.header</code>/<code>data.data</code>'
      
        '        '#8211' nicht direkt auf oberster Ebene wie bei (a). <code>tot' +
        'al</code> ist die Trefferzahl unter'
      
        '        Ber'#252'cksichtigung aktiver Filter, nicht die Gesamtzahl de' +
        'r Tabelle.'
      '      </div>'
      ''
      '      <h3>c) Schreiboperationen</h3>'
      
        '      <p><code>insert&lt;entity&gt;</code>, <code>update&lt;enti' +
        'ty&gt;</code>, <code>delete&lt;entity&gt;</code>. <span class="b' +
        'adge badge-ok">HTTP 200</span></p>'
      '      <pre><code>{ "status": "OK" }</code></pre>'
      
        '      <p>Kein Datensatz, keine neue ID in der Antwort. F'#252'r neue ' +
        'Prim'#228'rschl'#252'ssel vorher <code>get&lt;entity&gt;key</code> aufrufe' +
        'n.</p>'
      '    </section>'
      ''
      '    <section id="fehler">'
      '      <h2>6. Antwort im Fehlerfall</h2>'
      
        '      <pre><code>{ "status": "error", "message": "&lt;Fehlertext' +
        '&gt;" }</code></pre>'
      ''
      '      <table>'
      
        '        <tr><th>Situation</th><th>HTTP-Status</th><th>Beispiel <' +
        'code>message</code></th></tr>'
      
        '        <tr><td>Kein/leeres Token</td><td><span class="badge bad' +
        'ge-err">401</span></td><td>'#8222'Keine Anmeldedaten verf'#252'gbar. Bitte ' +
        'neu anmelden.'#8220'</td></tr>'
      
        '        <tr><td>Ung'#252'ltiges/abgelaufenes Token</td><td><span clas' +
        's="badge badge-err">401</span></td><td>'#8222'Anmeldung ung'#252'ltig oder ' +
        'abgelaufen.'#8220'</td></tr>'
      
        '        <tr><td>Route ist LocalOnly, Zugriff von au'#223'erhalb</td><' +
        'td><span class="badge badge-err">403</span></td><td>'#8222'Zugriff nur' +
        ' vom lokalen Server erlaubt.'#8220'</td></tr>'
      
        '        <tr><td>Unbekannte Route</td><td><span class="badge badg' +
        'e-err">404</span></td><td>'#8222'Dieser Pfad (/xyz) wurde nicht gefund' +
        'en.'#8220'</td></tr>'
      
        '        <tr><td>Datenbankfehler (Unique-/FK-Verletzung, ung'#252'ltig' +
        'es SQL)</td><td><span class="badge badge-warn">400</span></td><t' +
        'd>Firebird/InterBase-Fehlermeldung</td></tr>'
      
        '        <tr><td>Server-/Konfigurationsfehler</td><td><span class' +
        '="badge badge-warn">400</span></td><td>'#8222'Der Parameter [database]' +
        ' fehlt'#8220'</td></tr>'
      
        '        <tr><td><strong>Fachlicher Validierungsfehler</strong> (' +
        'nicht erlaubtes Feld, fehlender Pflichtparameter, ung'#252'ltiges JSO' +
        'N, nicht erlaubtes Sortierfeld, ...)</td><td><span class="badge ' +
        'badge-ok">200</span></td><td>'#8222'Feld "x" ist nicht erlaubt.'#8220', '#8222'"nr' +
        '" fehlt im Request-Body.'#8220'</td></tr>'
      '      </table>'
      ''
      '      <div class="callout">'
      '        <strong>Wichtig f'#252'r Client-Entwickler</strong>'
      
        '        Fachliche Validierungsfehler liefern HTTP 200, nicht 4xx' +
        ' '#8211' nur harte Datenbank-/Serverfehler liefern 400.'
      
        '        Der HTTP-Statuscode allein ist kein verl'#228'ssliches Erfolg' +
        'skriterium; die Response muss immer zus'#228'tzlich'
      '        auf <code>status:"error"</code> gepr'#252'ft werden.'
      '      </div>'
      ''
      '      <h3>Pr'#252'freihenfolge im Client</h3>'
      '      <ol class="flow">'
      '        <li>Antwort als JSON parsen.</li>'
      
        '        <li><code>status</code> vorhanden und <code>== "error"</' +
        'code>? '#8594' Fehlerfall, <code>message</code> anzeigen/loggen.</li>'
      
        '        <li>Sonst '#8594' Erfolgsfall: Schreiboperationen anhand <code' +
        '>status == "OK"</code>, Leseoperationen anhand vorhandenem <code' +
        '>header</code>/<code>data</code> (ggf. verschachtelt, siehe 5b).' +
        '</li>'
      
        '        <li><code>401</code>/<code>403</code>/<code>404</code> z' +
        'us'#228'tzlich als eindeutige, nicht-fachliche Fehler auswertbar, z. ' +
        'B. f'#252'r automatischen Re-Login.</li>'
      '      </ol>'
      '    </section>'
      ''
      '    <section id="beispiele">'
      '      <h2>7. Beispiele (curl)</h2>'
      ''
      '      <h3>Liste ohne Filter</h3>'
      
        '      <pre><code>curl -X POST "http://localhost/ibapi/dokumente/' +
        'getvorlagenfiltered" \'
      '  -H "Authorization: Bearer &lt;jwttoken&gt;" \'
      '  -H "Content-Type: application/json" \'
      '  -d '#39'{"fields":"*"}'#39
      ''
      
        '# -> 200, liefert ALLE Vorlagen (kein Filter gesetzt)</code></pr' +
        'e>'
      ''
      '      <h3>Liste mit einem Filter</h3>'
      
        '      <pre><code>curl -X POST "http://localhost/ibapi/dokumente/' +
        'getvorlagenfiltered" \'
      '  -H "Authorization: Bearer &lt;jwttoken&gt;" \'
      '  -H "Content-Type: application/json" \'
      '  -d '#39'{"fields":"*","art":"BRIEF","orderby":"name"}'#39
      ''
      '# -> 200'
      
        '# {"header":{"nr":"ftinteger","name":"ftstring 100","art":"ftstr' +
        'ing 20"},'
      
        '#  "data":[{"nr":1,"name":"Standardbrief","art":"BRIEF"}]}</code' +
        '></pre>'
      ''
      
        '      <h3>Pflichtfeld fehlt <span class="badge badge-warn">fachl' +
        'icher Fehler '#8594' trotzdem 200!</span></h3>'
      
        '      <pre><code>curl -X POST "http://localhost/ibapi/dokumente/' +
        'getvorlagenbyid" \'
      '  -H "Authorization: Bearer &lt;jwttoken&gt;" \'
      '  -H "Content-Type: application/json" \'
      '  -d '#39'{"fields":"*"}'#39
      ''
      '# -> 200 (!)'
      
        '# {"status":"error","message":"\"nr\" fehlt im Request-Body."}</' +
        'code></pre>'
      ''
      '      <h3>Nicht erlaubtes Feld in <code>fields</code></h3>'
      
        '      <pre><code>curl -X POST "http://localhost/ibapi/dokumente/' +
        'getvorlagen" \'
      '  -H "Authorization: Bearer &lt;jwttoken&gt;" \'
      '  -H "Content-Type: application/json" \'
      '  -d '#39'{"fields":["nr","geheimesfeld"]}'#39
      ''
      '# -> 200 (!)'
      
        '# {"status":"error","message":"Feld \"geheimesfeld\" ist nicht e' +
        'rlaubt."}</code></pre>'
      ''
      '      <h3>Kein/ung'#252'ltiges Token</h3>'
      
        '      <pre><code>curl -X POST "http://localhost/ibapi/dokumente/' +
        'getvorlagen" \'
      '  -H "Content-Type: application/json" -d '#39'{}'#39
      ''
      '# -> 401'
      
        '# {"status":"error","message":"Keine Anmeldedaten verf'#252'gbar. Bit' +
        'te neu anmelden."}</code></pre>'
      '    </section>'
      ''
      '    <section id="pagination">'
      '      <h2>8. Pagination '#8211' Zusammenfassung</h2>'
      '      <table>'
      '        <tr><th>Body-Parameter</th><th>Wirkung</th></tr>'
      
        '        <tr><td>kein <code>limit</code> bzw. <code>limit:0</code' +
        '></td><td>Alle Datens'#228'tze, Antwort wie in 5a (kein <code>total</' +
        'code>-Umschlag)</td></tr>'
      
        '        <tr><td><code>limit:N</code> (N &gt; 0), optional <code>' +
        'offset:M</code></td><td>Antwort wie in 5b, mit <code>total</code' +
        '>/<code>limit</code>/<code>offset</code> und verschachteltem <co' +
        'de>data.header</code>/<code>data.data</code></td></tr>'
      '      </table>'
      '    </section>'
      ''
      '    <footer>'
      
        '      Kurzreferenz basierend auf dem RATIOserver CRUD-Endpunkte-' +
        'Handbuch.'
      '    </footer>'
      '  </main>'
      '</div>'
      '</body>'
      '</html>')
    Left = 88
    Top = 32
  end
end
