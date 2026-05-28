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
      ''
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
end
