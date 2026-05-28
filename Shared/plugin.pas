unit plugin;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs;

type

  TAdresse = record
    Anrede: string;
    Vorname: string;
    Nachname: string;
    Strasse: string;
    PLZ: string;
    Ort: string;
    Email: String;
    Telefon: String;
    Briefanrede: string;
  end;

function GeneriereZufaelligeAdresse: TAdresse;

implementation


function GeneriereZufaelligeAdresse: TAdresse;
const
    Anreden: array [0 .. 2] of string = ('Herr', 'Frau', 'Divers');

  // Männliche Vornamen
  VornamenM: array [0 .. 49] of string = (
    'Max', 'Lukas', 'Tim', 'Paul', 'Finn', 'Leon', 'Ben', 'Jonas', 'Noah', 'Elias',
    'Luis', 'Felix', 'Jan', 'David', 'Tom', 'Fabian', 'Nico', 'Simon', 'Philip', 'Erik',
    'Moritz', 'Joel', 'Samuel', 'Jannik', 'Tobias', 'Niklas', 'Alexander', 'Marcel', 'Sebastian', 'Daniel',
    'Martin', 'Oliver', 'Jonathan', 'Julian', 'Dominik', 'Kevin', 'Matthias', 'Stefan', 'Andreas', 'Johannes',
    'Peter', 'Georg', 'Florian', 'Markus', 'Dirk', 'Christian', 'Thomas', 'Michael', 'Pascal', 'Kai'
    );

  // Weibliche Vornamen
  VornamenW: array [0 .. 49] of string = (
    'Julia', 'Anna', 'Laura', 'Lea', 'Emma', 'Mia', 'Sophie', 'Marie', 'Lina', 'Clara',
    'Lilly', 'Emily', 'Sarah', 'Nina', 'Johanna', 'Amelie', 'Lisa', 'Maja', 'Paula', 'Mara',
    'Elisa', 'Ronja', 'Alina', 'Franziska', 'Melina', 'Hannah', 'Charlotte', 'Vanessa', 'Lena', 'Isabell',
    'Carina', 'Jasmin', 'Theresa', 'Katharina', 'Sandra', 'Bianca', 'Angelina', 'Verena', 'Stefanie', 'Eva',
    'Sina', 'Helena', 'Marlene', 'Antonia', 'Annika', 'Christine', 'Nicole', 'Carolin', 'Ina', 'Nadine'
    );

  Nachnamen: array [0 .. 49] of string = (
    'Müller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 'Meyer', 'Wagner', 'Becker', 'Hoffmann', 'Schulz',
    'Koch', 'Bauer', 'Richter', 'Klein', 'Wolf', 'Schröder', 'Neumann', 'Schwarz', 'Zimmermann', 'Braun',
    'Krüger', 'Hofmann', 'Hartmann', 'Lange', 'Schmitt', 'Werner', 'Schmitz', 'Krause', 'Meier', 'Lehmann',
    'Schmid', 'Schulze', 'Maier', 'Köhler', 'Herrmann', 'König', 'Walter', 'Mayer', 'Huber', 'Kaiser',
    'Fuchs', 'Peters', 'Lang', 'Scholz', 'Möller', 'Weiß', 'Jung', 'Hahn', 'Berger', 'Keller'
    );

  Strassen: array [0 .. 49] of string = (
    'Hauptstraße', 'Bahnhofstraße', 'Dorfstraße', 'Lindenweg', 'Bergstraße', 'Schulstraße', 'Gartenweg', 'Wiesenweg', 'Feldstraße', 'Mühlenweg',
    'Birkenweg', 'Rosenstraße', 'Finkenweg', 'Ahornweg', 'Kirchstraße', 'Waldstraße', 'Am Hang', 'Tannenweg', 'Buchenstraße', 'Fabrikstraße',
    'Blumenweg', 'Sonnenstraße', 'Ringstraße', 'Erlenweg', 'Im Winkel', 'Tulpenweg', 'Nelkenstraße', 'Kastanienweg', 'Am Bach', 'Schillerstraße',
    'Goethestraße', 'Mozartstraße', 'Lessingstraße', 'Am Sportplatz', 'Poststraße', 'Drosselweg', 'Eichenweg', 'Am See', 'Panoramastraße', 'Talstraße',
    'Neue Straße', 'Am Bahnhof', 'Höhenweg', 'Breslauer Straße', 'Rathausstraße', 'Industriestraße', 'Auf dem Hügel', 'Platanenweg', 'Brunnenstraße', 'Schlossweg'
    );

  Orte: array [0 .. 49] of string = (
    'Berlin', 'Hamburg', 'München', 'Köln', 'Frankfurt', 'Stuttgart', 'Düsseldorf', 'Dortmund', 'Essen', 'Leipzig',
    'Bremen', 'Dresden', 'Hannover', 'Nürnberg', 'Duisburg', 'Bochum', 'Wuppertal', 'Bielefeld', 'Bonn', 'Münster',
    'Karlsruhe', 'Mannheim', 'Augsburg', 'Wiesbaden', 'Gelsenkirchen', 'Mönchengladbach', 'Braunschweig', 'Chemnitz', 'Kiel', 'Aachen',
    'Halle', 'Magdeburg', 'Freiburg', 'Krefeld', 'Lübeck', 'Oberhausen', 'Erfurt', 'Mainz', 'Rostock', 'Kassel',
    'Hagen', 'Saarbrücken', 'Hamm', 'Potsdam', 'Ludwigshafen', 'Oldenburg', 'Leverkusen', 'Osnabrück', 'Solingen', 'Heidelberg'
    );
var
    Adr: TAdresse;
  Hausnummer: Integer;
  AnredeIndex: Integer;


begin

  Randomize;
  AnredeIndex := Random(Length(Anreden));
  Adr.Anrede := Anreden[AnredeIndex];
  Adr.Nachname := Nachnamen[Random(Length(Nachnamen))];
  if Adr.Anrede = 'Herr' then
  begin
    Adr.Vorname := VornamenM[Random(Length(VornamenM))];
    Adr.Briefanrede := 'Sehr geehrter Herr ' + Adr.Nachname;
  end
  else
    if Adr.Anrede = 'Frau' then
  begin
    Adr.Vorname := VornamenW[Random(Length(VornamenW))];
    Adr.Briefanrede := 'Sehr geehrte Frau ' + Adr.Nachname;
  end
  else
  begin
    // Bei "Divers" zufälliger Name aus beiden Listen
    if Random(2) = 0 then
      Adr.Vorname := VornamenM[Random(Length(VornamenM))]
    else
      Adr.Vorname := VornamenW[Random(Length(VornamenW))];
    Adr.Briefanrede := 'Sehr geehrte(r) ' + Adr.Vorname + ' ' + Adr.Nachname;
  end;

  Hausnummer := Random(100) + 1;
  Adr.Strasse := Strassen[Random(Length(Strassen))] + ' ' + IntToStr(Hausnummer);
  Adr.PLZ := Format('%.5d', [Random(90000) + 10000]);
  Adr.Ort := Orte[Random(Length(Orte))];
  Adr.Email := Adr.Vorname + '.' + Adr.Nachname + Adr.PLZ + '@demo.de';
  Randomize;
  Adr.Telefon := '+49 ' + IntToStr(Random(1000) + 100) + ' ' + IntToStr(Random(10000000) + 10000);
  Result := Adr;
end;

end.
