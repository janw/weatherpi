#!/usr/bin/perl -w
#
# ws500.pl: Ausleseprogramm fuer die WS500 von elv
#
# Copyright (C) 2006 Jochen, Basti, Django
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# Or, point your browser to http://www.gnu.org/copyleft/gpl.html
#
# The author can be reached at  django[aett]mnet-mail[punkt]de
#
# The project's page is at http://omni128.de/dokuwiki/doku.php?id=ws:ws500
#

use Device::SerialPort;
use POSIX qw(locale_h);                                          
use locale;
use DBI;
use DBD::mysql;
use IO::File;

use strict;                                                             # Nur sauber programmierter Perlcode wird akzeptiert
use warnings;                                                           # Aktivierung des Warnmechanismus von Perl
use diagnostics;                                                        # Aktivierung zusaetzlicher Informationen bei Fehlermeldungen


# --- Definition der Systemeinstellungen --- #

our $dev;
our $lastcount;
our $debug;
our $reporting;
our $mailinfo;
our $mailto;
our $mailfrom;
our $Sendmail_Prog;
our $logfile;
our $writeToFile;
our $recordFile;
our $statusFile;
our $server;
our $mysqlusage;
our $dbhost;
our $dbuser;
our $dbpasswd;
our $dbdatabase;
#our $sqllogger;

# --- Definition der Systemvariablen --- #

my @sensoren_status;
my @empfausfall;                                                        # Zaehler fuer Empfangsausfaelle der Station
my @RXBuffer;
my @TXBuffer;
my @feuchte;
my @temperatur;
my @csvzeile;
my @sensor_db;


my $FTDI;
my $absdruck;
my $charakter;
my $commandstring;
my $druck;
my $errorcount;
my $firmware = 2.50;                                                    # test
my $firstrun;
my $framelaenge = 0;
my $hexcharakter;
my $hoehe;
my $i;
my $input;
my $intervall;
my $is_offline;
my $is_raining;
my $korrhoehe = "50";
my $meterbytehigh;
my $meterbytelow;
my $newmysqltime;
my $offset = 0;
my $oldIntervall;
my $oldmysqltime;
my $online;
my $paniccount;
my $recordtime;
my $sensor_db;
my ( $regen,$regen_alt,$regen_delta,$regen_menge,$regen_db );
my ( $sonne,$sonne_alt,$sonne_delta,$sonne_menge,$sonne_ok,$sonne_db );
my ($sth,$sqlstate,$sqllogger,$sql,$query,$dbh);                        # MySQL-Variablen
my $time_next_record;
my $time_next_developstatus;
my $time_nr;
my $tmp;
my $tmpstring;
my $type;
my $Version = "0.1.2";
my $wettervorhersage;
my ( $wind_geschwindigkeit,$wind_richtung,$wind_schwankung );
my $wippe;
my $wippebytehigh;
my $wippebytelow;
my $writeString;


require '/etc/ws500/ws500.conf';                                        # Dateiname und Pfad für die Konfigurationsdatei

##########################################################################################################################################################
# *** START *** Hauptprogramm
##########################################################################################################################################################

write_Log ("====================================================\n                          Programm $0: Version $Version gestartet.\n                          ====================================================");                                     # Programmstart dokumentieren#
print STDERR "\nProgramm $0: Version: $Version zum Auslesen der WS500 wird gestartet:\n\n";
get_lastcount();                                                        # letzten Zaehlerstaende fuer light und rain wieder zurueckholen
connect_MySQL () if ($mysqlusage == 1);                                 # MySQL-Datenbankanbindung herstellen, sofern gewuenscht

$time_next_developstatus = time();
$time_next_record = time();                                             # Versuchsballon!
$intervall = 0;
$is_offline = 0;
$firstrun = 1;

while ( 1 ) {                                                           # "Endlosschleife"
        my $theMessage = shift;

        if ($time_next_developstatus <= time()) {
                $paniccount = 0;
                $oldIntervall = $intervall;
                init_USB();
                write_Log ("get_DEVELOP_STATUS()");
                $tmp = get_DEVELOP_STATUS();
                while (!$tmp && ($paniccount < 5)) {                    # 5x Versuchen den Status der Station abzufragen
                        $paniccount++;
                        $tmp = get_DEVELOP_STATUS();
                }
                close_USB();
                if ($paniccount >= 5){                                  # sind die 5 Versuche Fehlgeschlagen, dann hier weiter
                        print "1.Warnung: Verbindung zur WS500 gestoert! \nMoegliche Ursachen koennten sein:\n";
                        print "  ° USB Verbindung wurde unterbrochen\n";
                        print "  ° Station gerade in Sync-Modus\n";
                        print "Verbindungsaufbau erfolgt automatisch erneut in einer Minute!\n";
                        write_Log ("USB-Verbindung gestoert!");
                        $theMessage = "Warnung: Verbindung zur WS500 gestoert! \nVerbindungsaufbau erfolgt automatisch erneut in einer Minute!\n";
                        send_Mail($theMessage);

                        $is_offline = 1;
                        if ($firstrun == 1) {
                                sleep 60;                               # beim ersten Mal müssen erst die kritischen Variablen befüllt werden!

                ####TEST####
                                init_USB();
                                write_Log ("2nd try to get_DEVEOLOP_STATUS()");
                                $tmp = get_DEVELOP_STATUS();
                                while (!$tmp && ($paniccount < 5)) {    # 5x Versuchen den Status der Station abzufragen
                                        $paniccount++;
                                        $tmp = get_DEVEOLOP_STATUS();
                                }
                        close_USB();
                ####TEST####

                        }
                        else {
                                $time_next_developstatus =  time() + 60;# einfach in einer Minute noch mal versuchen.
                        }
                        $paniccount = 0;
                }

                if (($tmp == 1) && ($is_offline == 1)) {
                        $is_offline = 0;
                        write_Log ("USB-Verbindung wiederhergestellt!");
                        $theMessage = "Information: Verbindung zur WS500 besteht wieder! Werde nun die Konfiguration auslesen.\n";
                        send_Mail($theMessage)
                }

                if ($is_offline == 0) {
                        if ($oldIntervall != $intervall) {
                                $firstrun = 0;
                                $time_next_record = time();
                                write_Log ("naechste Record(next)-Abfrage: ".localtime($time_next_record));
                        }

                        write_Status_To_File();
                        $time_next_developstatus =  time() + $intervall*60 if ($is_offline == 0);
                        write_Log ("naechste Konfig-Abfrage: ".localtime($time_next_developstatus));
                }
        }

        if ($time_next_record <= time()) {
                write_Log ("entering next_record()");
                init_USB();
                if (get_CURRENT_RECORD()) {
                        if ($is_offline == 1) {
                                $is_offline = 0;
                                write_Log ("Verbindung wiederhergestellt!");
                        }
                }

                $errorcount = 0;

                do {                                                    #solange noch Daten gespeichert sind
                        write_Log ("checking next record...()");

                        if (get_NEXT_RECORD() == 1) {
                                write_Log ("get_NEXT_RECORD()");
                                if ($is_offline == 1) {
                                        $is_offline = 0;
                                        write_Log ("Verbindung wiederhergestellt!");
                                }
                                prozess_DATA();                         # Weitere Bearbeitung der Datensaetze
                        }

                        if ($framelaenge == 0) {
                                $paniccount++;
                        }
                        if ($framelaenge < 5) {
                                $errorcount++;
                        }
                        else
                        {
                                $errorcount = 0;
                                $paniccount = 0;
                        }
                } until (($framelaenge < 5) && ($errorcount > 5) );
                close_USB();
                if ($paniccount >= 5){
                        print "2.Warnung: Verbindung zur WS500 gestoert! \nMoegliche Ursachen koennten sein:\n";
                        print "  ° USB Verbindung wurde unterbrochen\n";
                        print "  ° Station gerade in Sync-Modus\n";
                        print "Verbindungsaufbau erfolgt automatisch erneut in einer Minute!\n";
                        write_Log ("USB-Verbindung gestoert!");
                        $theMessage = "Warnung: Verbindung zur WS500 gestoert! \nVerbindungsaufbau erfolgt automatisch erneut in einer Minute!\n";
                        send_Mail($theMessage);
                        
                        $paniccount = 0;
                        $time_next_record =  time() + 60;               #in 60 sekunden noch mal nachschauen
                        $is_offline = 1;
                }
                $time_next_record =  time() + $intervall*60 if ($is_offline == 0);
                write_Log ("naechste Record(next)-Abfrage: ".localtime($time_next_record));
        }

        sleep 1;
}

##########################################################################################################################################################
# *** ENDE *** Hauptprogramm
##########################################################################################################################################################


##############################################################################
### ab hier sind die ueberarbeiteten Unterprogramme alphabetisch abgelegt: ###
##############################################################################

# *** START *** Unterprogramm "byte2Int" zum Umrechnen eines zwei Bytewertes in eine ganze Zahl
sub byte2Int {
        my $highbyte = shift;                                           # Variable leeren
        my $lowbyte  = shift;                                           # Variable leeren

#       if ($highbyte > 127) {
#               $highbyte -= 128;
#               return(($highbyte*255+$lowbyte)*-1);
#       }
        if ($highbyte == 255) {                                         # wenn Highbyte gleich "FF" ist, dann ist der Wert
#               $highbyte = 0;
#               return(($highbyte*-255+$lowbyte)*-1);
                return(($lowbyte)-256);                                 # Lowbayte minus 256
        }
        else
        {
                return($highbyte*255+$lowbyte);                         # ansonsten ganz "normal" weiterrechnen
        }
}
# *** ENDE ***  Unterprogramm "byte2Int" zum Umrechnen eines zwei Bytewertes in eine ganze Zahl

# *** START *** Unterprogramm "close_USB" zum Schliessen der USB-Kommunikationsschnittstelle
sub close_USB {
        write_Log ("USB-RS232-Port wird geschlossen...\n                          ----------------------------------------------------");
#       my $rts=$FTDI->rts_active(0);
#       $FTDI->purge_all;
               
        $FTDI->close || write_Log ("USB-RS232-Port wird geschlossen -> Fehler!");
        $online = 0;
}
# *** ENDE ***  Unterprogramm "close_USB" zum Schliessen der USB-Kommunikationsschnittstelle

# *** START *** Unterprogramm "connect_MySQL" zum Herstellen der Datenbankanbindung an die Wetterdatenbank
sub connect_MySQL {
        my $theMessage = shift;
        $dbh = DBI -> connect ("DBI:mysql:$dbdatabase:$dbhost",$dbuser,$dbpasswd,
        {
        PrintError => 0,
        }
        );
        unless ( $dbh ) {
                write_Log ("MySQL-Datenbankverbindungsaufbau fehlgeschlagen!");
                $theMessage = "Verbindung zur MySQL-Datenbank $dbdatabase auf $dbhost konnte nicht hergestellt werden!\n";
                send_Mail($theMessage);
                die ("Verbindung zur MySQL-Datenbank $dbdatabase auf $dbhost konnte nicht hergestellt werden!\n");
        }
        write_Log ("Verbindung zur MySQL-Datenbank wurde hergestellt.");
}
# *** ENDE *** Unterprogramm "connect_MySQL" zum Herstellen der Datenbankanbindung an die Wetterdatenbank

# *** START *** Unterprogramm "convert_Time" zum Umformatieren von Datum & Uhrzeit
sub convert_Time {
        my $oldtime = shift;

        my $date=gmtime($oldtime);                                      # Datum
        my @date=gmtime($oldtime);                                      # Datum
        my $sekunde=sprintf("%02d",$date[0]);                           # Sekunden
        my $minute=sprintf("%02d",$date[1]);                            # Minuten
        my $stunde=sprintf("%02d",$date[2]);                            # Stunden
        my $tag=sprintf("%02d",$date[3]);                               # Tag
        my $mon=sprintf("%02d",$date[4]+1);                             # Monat korrigiert um "+1", da 0-11
        my $jahr=sprintf("%04d",$date[5]+1900);                         # Jahr korrigiert mit "+1900" für 4-stellige Anzeige
        my $minus = "-";                                                # Datumstrennzeichen
        my $leer = " ";                                                 # Trennzeichen zwischen Datum und Uhrzeit
        my $doppelpunkt = ":";                                          # Uhrzeittrennzeichen

        $newmysqltime = $jahr.$minus.$mon.$minus.$tag.$leer.$stunde.$doppelpunkt.$minute.$doppelpunkt.$sekunde;

#       return ($newmysqltime);
}
# *** ENDE ***  Unterprogramm "convert_Time" zum Umformatieren von Datum & Uhrzeit

# *** START *** Unterprogramm "escapeByte" zum Behandeln des empfangenen Escape-Bytes xF8
sub escapeByte {
        my $addbyte = shift;
        if (is_Escape_Chr($addbyte)) {
                write_Log ("byte escaped!: ".$tmpstring);
                $commandstring .= "\xF8".chr(($addbyte-1));
        }
        else {
                $commandstring .= chr($addbyte);
        }
}
# *** ENDE ***  Unterprogramm "escapeByte" zum Behandeln des empfangenen Escape-Bytes xF8

# *** START *** Unterprogramm "get_CURRENT_RECORD" zum Ausgeben des aktuellen Datensatzes der WS500
sub get_CURRENT_RECORD {
        write_ws500("\xFE\x33\xFC");
        read_ws500();
        write_Array();
        if ($framelaenge >= 40) {
                read_RECORD_Frame();

                if ($debug == 1) {
                        print "+-------------------------------------------------------+\n";
                        print "+\t\taktueller Datensatz\t\t\t|\n";
                        print "+-------------------------------------------------------+\n";
                        print "|\tRegenmenge: ".$regen." Impulse\t\t\t\t|\n";
                        print "|\tWind: ".$wind_geschwindigkeit." km/h\t\t\t\t\t|\n";
                        print "|\tWindrichtung: ".$wind_richtung." °\t\t\t\t|\n";
                        print "|\tWindschwankung: ".$wind_schwankung." °\t\t\t\t|\n";
                        print "|\tLuftdruck (rel.): ".$druck." hPa\t\t\t|\n";
                        print "|\tLuftdruck (abs.): ".$absdruck." hPa\t\t\t|\n";
                        print "|\tSonnenscheindauer: ".$sonne." Minuten\t\t\t|\n";
                        print "|\tWetterstatus:  ".$wettervorhersage."\t\t\t\t|\n";
                        for ($i=0; $i < 10; $i++) {
                                print "+-------------------------------------------------------+\n";
                                print "|\tTemperatur ".$i."= ".$temperatur[$i]."°C\t\t\t\t|\n";
                                print "|\tFeuchte ".$i."   = ".$feuchte[$i]."% rel\t\t\t\t|\n";
                        }
                        print "+-------------------------------------------------------+\n\n\n";
                }
        }
        return ($framelaenge >= 40);
}
# *** ENDE ***  Unterprogramm "get_CURRENT_RECORD" zum Ausgeben des aktuellen Datensatzes der WS500

# *** START *** Unterprogramm "get_DEVEOLOP_STATUS" zum Ausgeben des Konfigurationsdatensatzes der WS500
sub get_DEVELOP_STATUS {
        my $theMessage = shift;
        get_FIRMWARE();
#       get_FIRMWARE() if ($firstrun == 1);
        write_ws500("\xFE\x32\xFC");
        read_ws500();
        write_Array();

                                                                        # Config auslesen
        if ($framelaenge >= 17) {
                if ($RXBuffer[1] == 50)                                 # config record
                {
                        $offset = 2;

                        for ($i=1; $i < 10; $i++) {
                                $sensoren_status[$i] = unescapeByte() - 16;

                                        if ($sensoren_status[$i] < 0) {
                                                $sensor_db[$i] = "0";
                                        }
                                        else {
                                                $sensor_db[$i] = "1";
                                        }

                                        if ($sensoren_status[$i] > 0 ) {
                                                $theMessage = "Die Kommunikation der WS500 mit dem Fuehler $i ist unterbrochen! Es sind $sensoren_status[$i] Funkausfaelle zu verzeichnen!\n";
                                                send_Mail($theMessage);
                                                }
                                        }
                        }
                        $sensor_db[0] = "1";                            # Innensensor ist immer vorhanden

                        $intervall = unescapeByte();
                        $hoehe = unescapeByte()*255 + unescapeByte();
                        $wippe = unescapeByte()*255 + unescapeByte();

                        for ($i=1; $i < 10; $i++) {

                        if ($debug == 1)
                        {
                                print "+-------------------------------------------------------+\n";
                                print "+\t\t    Stations-Status \t\t\t|\n";
                                print "+-------------------------------------------------------+\n";
                                print "|\tFirmware: ".$firmware."\t\t\t\t\t|\n";
                                print "|\tMessintervall: ".$intervall." Minuten\t\t\t|\n";
                                print "|\tHoehe: ".$hoehe." m ue. NN\t\t\t\t|\n";
                                print "|\tWippe: ".$wippe." ml/Impuls\t\t\t\t|\n";

                                                $sensor_db[0] = "1";

                                for ($i=1; $i < 10; $i++) {
                                        if ($sensoren_status[$i] < 0) {
                                                print "|\tSensor ".$i.": nicht verfuegbar\t\t\t|\n";
                                        }
                                        else {
                                                print "|\tSensor ".$i.": verfuegbar (Empfangsausfaelle: ".$sensoren_status[$i].")\t|\n";
                                        }
                                }
                                print "+-------------------------------------------------------+\n\n\n";
                        }
                }
        }
        return ($framelaenge >= 17);
}
# *** ENDE ***  Unterprogramm "get_DEVEOLOP_STATUS" zum Ausgeben des Konfigurationsdatensatzes der WS500

# *** START *** Unterprogramm "get_FIRMWARE" zum Auslesen der Firmwareversion der WS500
sub get_FIRMWARE {
        write_ws500("\xFE\x34\xFC");
        read_ws500();

        if ($framelaenge >= 4) {
                $firmware = (sprintf("%x",$RXBuffer[2]))/10;
        }
}
# *** ENDE ***  Unterprogramm "get_FIRMWARE" zum Auslesen der Firmwareversion der WS500

# *** START *** Unterprogramm "get_lastcount" zum Holen der beiden letzten Zaehlerstaende fuer Regen und Sonnenschein
sub get_lastcount {
        if(!open(BACKUPFILE, "+<".$lastcount)) {
                $reporting = 0;
                print "Konnte auf Recorddatei ".$lastcount." nicht zugreifen!\n";
        }
        print BACKUPFILE "";
        close(BACKUPFILE) || warn "close failed";

        $sonne_alt = 0;                                                 # Sonnenwert zuruecksetzen
        $regen_alt = 0;                                                 # Regenwert zuruecksetzen

        open (BACKUPFILE,$lastcount) or die "Fehler beim Oeffnen der CSV-Datei";

                while (<BACKUPFILE>) {
                if (m/^\s*#/o) {next;};                                 # Kommentazeilen ueberspringen
                @csvzeile = split /;/,$_;                               # Zeile aufsplitten und in Array uebergeben
                $regen_alt = $csvzeile [0];                             # letzter Regenwert aus Feld/Spalte "1" holen
                $sonne_alt = $csvzeile [1];                             # letzter Sonnenwert aus Feld/Spalte "2" holen

        }
        write_Log ("Letzte Werte fuer Regen und Sonnenschein wurden aus $lastcount gelesen");
        close(BACKUPFILE);
}
# *** ENDE ***  Unterprogramm "get_lastcount" zum Holen der beiden letzten Zaehlerstaende fuer Regen und Sonnenschein

# *** START *** Unterprogramm "get_NEXT_RECORD" zum Ausgeben der historischen Datensaetzes der WS500
sub get_NEXT_RECORD {
        write_ws500("\xFE\x31\xFC");
        read_ws500();
        if ($framelaenge >= 40) {
                write_Array(@RXBuffer);
                read_RECORD_Frame();

                if ($debug == 1){
                        print "+-------------------------------------------------------+\n";
                        print "|\t Datensatz - Nummer ".$time_nr." \t\t\t\t|\n";
                        print "+-------------------------------------------------------+\n";
                        print "|\tRegen (alt): ".$regen_alt." Impulse\t\t\t|\n";
                        print "|\tRegen (neu): ".$regen." Impulse\t\t\t|\n";
                        print "|\tRegenmenge:  ".$regen_delta." Impulse   \t\t\t|\n";
                        print "|\tRegenmenge: ".$regen_menge." ml pro m^2\t\t\t|\n";
                        print "|\tWind: ".$wind_geschwindigkeit." km/h\t\t\t\t\t|\n";
                        print "|\tWindrichtung: ".$wind_richtung." °\t\t\t\t|\n";
                        print "|\tWindschwankung: ".$wind_schwankung." °\t\t\t\t|\n";
                        print "|\tLuftdruck (rel.): ".$druck."hPa\t\t\t|\n";
                        print "|\tLuftdruck (abs.): ".$absdruck."hPa\t\t\t|\n";
                        print "|\tSonne (alt): ".$sonne_alt." Minuten\t\t\t|\n";
                        print "|\tSonne (neu): ".$sonne." Minuten\t\t\t|\n";
                        print "|\tSonnenscheindauer: ".$sonne_delta." Minuten\t\t\t|\n";
                        print "|\tWetterstatus:  ".$wettervorhersage."\t\t\t\t|\n";
                                for ($i=0; $i < 10; $i++) {
                                        print "+-------------------------------------------------------+\n";
                                        print "|\tTemperatur ".$i."= ".$temperatur[$i]."°C\t\t\t\t|\n";
                                        print "|\tFeuchte ".$i."   = ".$feuchte[$i]."% rel\t\t\t\t|\n";
                                }
                                print "+-------------------------------------------------------+\n\n\n";
                }
        }
        else {
                write_Log ("Fehler: Framelaenge: ".$framelaenge);
        }
        return ($framelaenge >= 40);                                    # gibt true zurueck, falls erfolgreich ein Datensatz ausgelesen wurde
}
# *** ENDE ***  Unterprogramm "get_NEXT_RECORD" zum Ausgeben der historischen Datensaetzes der WS500


# *** START *** Unterprogramm "init_USB" zum Konfigurieren der Datenkommunikation mittels FTDI-Treiber mit der WS500
sub init_USB {
        $FTDI->close if(defined($FTDI));
        $FTDI = tie(*FTD, 'Device::SerialPort', $dev) || die "Oeffnen des Geraetes $dev: fehlgeschlagen!\n";
        $FTDI->user_msg(1);
        $FTDI->reset_error();
        my $baud      = $FTDI->baudrate(19200);
        my $dbits     = $FTDI->databits(8);
        my $parity    = $FTDI->parity('even');
        my $sbits     = $FTDI->stopbits(1);
#       my $handshake = $FTDI->handshake('rts');
        my $handshake = $FTDI->handshake('none');
        my $rts=$FTDI->rts_active(0);
        $FTDI->purge_all;
        if ($debug == 1) {
                print "Konfiguriere USB-RS232-Port ($dev) ...\n\n\n";
                print "+-------------------------------------------------------+\n";
                print "+    Die Einstellungen zur Datenkommunikation lauten:   |\n";
                print "+-------------------------------------------------------+\n";
                print "|\t\tBaudrate  : ".$baud."\t\t\t|\n";
                print "|\t\tDatenbits : ".$dbits."\t\t\t\t|\n";
                print "|\t\tStopbits  : ".$sbits."\t\t\t\t|\n";
                print "|\t\tParity    : ".$parity."\t\t\t|\n";
                print "|\t\tHandshake : ".$handshake."\t\t\t|\n";
                print "|\t\tRTS       : ".$rts."\t\t\t\t|\n";
                print "+-------------------------------------------------------+\n\n\n";
        }
        $online = 1;
        write_Log ("----------------------------------------------------\n                          USB-RS232-Port wird geoeffnet...");
        select(undef, undef, undef, 0.25);                              # warte 0,25 Sekunden und mache dann weiter
}
# *** ENDE ***  Unterprogramm "init_USB" zum Konfigurieren der Datenkommunikation mittels FTDI-Treiber mit der WS500

# *** START *** Unterprogramm "is_Escape_Chr" 
sub is_Escape_Chr {
        my $theChr = shift;
        return (($theChr == 0xF8 || $theChr == 0xF8 || $theChr == 0xF8) );
}
# *** START *** Unterprogramm "is_Escape_Chr"

# *** START *** Unterprogramm "prozess_DATA" zum Uebertragen der Daten in die Datenbanken und Dateien
sub prozess_DATA {

        write_lastcount();                                              # Zaehlerstaende "sun & rain" sichern
        write_MySQL() if ($mysqlusage == 1);                            # MySQL-Datenbank "wetter" befuellen, falls gewuenscht
        write_Record_to_File() if ($writeToFile == 1);                  # Wetterdaten in CSV-Datei schreiben, falls gewuenscht
        $regen_alt = $regen;                                            # neuer "alte Wert" = aktueller Wert
        $sonne_alt = $sonne;                                            # neuer "alte Wert" = aktueller Wert
        print "ausglesn und weggschrim is'\n";                          # Fortschrittsbalken andeuten                                                               

}
# *** ENDE *** Unterprogramm "prozess_DATA" zum Uebertragen der Daten in die Datenbanken und Dateien

# *** START *** Unterprogramm "read_RECORD_Frame" zum Auslesen und Auswerten des Empfangspuffers
sub read_RECORD_Frame {
        if ((($RXBuffer[1] == 49) || ($RXBuffer[1] == 51)) && ($framelaenge >= 40))  
        {
                if ($RXBuffer[1] == 51) {                               # aktueller Datensatz
                        $offset   = 2;
                        $time_nr  = 0;
                        $type     = "c";
                }
                else {                                                  # naechster Datensatz
                        $offset   = 4;
                        $time_nr  = unescapeByte()*255 + unescapeByte();
                        $type     = "n";
                }

                $recordtime = time()-($time_nr*60);                     # Alter des Datensatzes rueckrechnen
                $oldmysqltime = ( gmtime($recordtime) );
                convert_Time ( $recordtime );

                undef @temperatur;
                undef @feuchte;
                for (my $i=1; $i < 10; $i++) {
                        $temperatur[$i]= (byte2Int(unescapeByte(),unescapeByte())) / 10;
                        $feuchte[$i]= unescapeByte();
                }

                $regen = (unescapeByte()*255 + unescapeByte());
                $regen_delta = $regen - $regen_alt;
                $regen_menge = $regen_delta * $wippe;
                if( $regen_delta eq "0") {
                        $regen_db = "0";
                        }
                else {
                       $regen_db = "1";
                }
                $wind_geschwindigkeit = (unescapeByte()*255 + unescapeByte()) / 10; 
                $wind_richtung = (unescapeByte() * 5);
                $wind_schwankung = (unescapeByte() * 5);
                $sonne = (unescapeByte()*255 + unescapeByte());
                $sonne_delta = $sonne - $sonne_alt;
                if( $sonne_delta eq "0") {
                        $sonne_ok = 0;
                        $sonne_db = "0";
                        }
                else {
                       $sonne_ok = 1;
                       $sonne_db = "1";
                }

                $temperatur[0] = ( byte2Int(unescapeByte(),unescapeByte())) / 10; 
                $feuchte[0] = unescapeByte();
                $druck = (unescapeByte()*255 + unescapeByte());
                $absdruck = $druck; 
                $druck = $druck * ( 2.718 ** ( ( ( $hoehe + $korrhoehe ) * 9.8066 ) / ( 287.05 * ( $temperatur[0] + 273.15 )  ) ) ) ; 
                $druck = sprintf ("%.0f", $druck);                      # Umrechnung des relativen ind den absoluten Luftdruck ohne Nachkommastellen runden

                if ($type eq "c") {
                        $wettervorhersage = unescapeByte();
                                                                        # 3 = schwuel, 
                        $is_raining = ($wettervorhersage > 120);
                }
        }
}
# *** ENDE ***  Unterprogramm "read_RECORD_Frame" zum Auslesen und Auswerten des Empfangspuffers

# *** START *** Unterprogramm "read_ws500" zum Auswerten des Empfangspuffers und in einzelne Bytes aufteilen
sub read_ws500 {
        my $i = 0;
        $input = $FTDI->input();
        $framelaenge = length($input);
        undef @RXBuffer;                                                # Die Ergebnisse werden in @RXBuffer gespeichert 
        foreach $charakter (split(//,$input)) {                         # Datenbytes in Array lesen 
                $RXBuffer[$i] = ord($charakter);                        # in Bytes umwandeln
                $i++;
        }
}
# *** ENDE ***  Unterprogramm "read_ws500" zum Auswerten des Empfangspuffers und in einzelne Bytes aufteilen

# *** START *** Unterprogramm "send_Mail" zum Schicken von Warn-/Fehlermeldung an den WS-User
sub send_Mail {
        my $theMessage = shift;
        if ($mailinfo == 1) {
                open(MAIL,"|$Sendmail_Prog -t") || print STDERR "Mailprogramm konnte nicht gestartet werden\n";
                print MAIL "From: $mailfrom\n";
                print MAIL "To: $mailto\n";
                print MAIL "Subject: WS500-Errormeldung\n\n";
                print MAIL ".$theMessage.\n";
                close(MAIL);
        }
        return 0;
}
# *** ENDE ***  Unterprogramm "send_Mail" zum Schicken von Warn-/Fehlermeldung an den WS-User

# *** START *** Unterprogramm "sqlquery" zum Vorbereiten und Loggen der SQL-Queries
sub sqlquery {
        $query=shift();
        $sth=$dbh->prepare($query);
        $sth->execute();
        $sqlstate = $dbh->state;
        unless ($sqlstate) {$sqlstate='00000';};
        $sqllogger .= "executed '$query' result '$sqlstate' \n";
        sysopen(FHNEW,"sqllog1.txt",O_CREAT|O_WRONLY|O_APPEND) || die "can't open logger file: $!";
        syswrite(FHNEW,$sqllogger,length($sqllogger));
        close(FHNEW);
        $sqllogger = '';
}
# *** START *** Unterprogramm "sqlquery" zum Vorbereiten und Loggen der SQL-Queries

# *** START *** Unterprogramm "unescapeByte" zum Behandeln des empfangenen Bytes
sub unescapeByte {
        my $tmp = 0;
        if (is_Escape_Chr($RXBuffer[$offset])) {
                $offset++;
                $tmp = $RXBuffer[$offset] - 1;
        }
        else {

                $tmp = $RXBuffer[$offset];
        }
        $offset++;
        return( $tmp );
}
# *** STOP ***  Unterprogramm "unescapeByte" zum Behandeln des empfangenen Bytes

# *** START *** Unterprogramm "write_Array" zum Ausgeben der empfangenen Bytes (hexadezimal und dezimal)
sub write_Array {
        if ($debug == 1){
                print "Der empfangene Datensatz lautet:\n";
                foreach $charakter (@RXBuffer) {
                        $hexcharakter = sprintf("%x", $charakter );
                        print $hexcharakter.", ";                
                }
                print "\nbzw.:\n";
                foreach $charakter (@RXBuffer) {
                        print $charakter.", ";
                }
                print "\n\n\n";
        }
        return 0;
}
# *** ENDE ***  Unterprogramm "write_Array" zum Ausgeben der empfangenen Bytes (hexadezimal und dezimal)

# *** START *** Unterprogramm "write_Config" zum Uebertragen der Konfiguration in Richtung WS500
sub write_Config { 
        my $zeit = shift;
        my $meter = shift;
        my $mmwippe = shift;

        if (($zeit >= 5) && ($zeit < 100) && ($meter >= 0) && ($meter < 2000) && ($mmwippe >= 200) && ($mmwippe < 400)) {
                $meterbytehigh = int($meter / 255);
                $meterbytelow = $meter % 255;
                $wippebytehigh = int($mmwippe / 255);
                $wippebytelow = $mmwippe % 255;
                write_Log ("Werte: meter:".$meter."(h:".$meterbytehigh." l:".$meterbytelow.") mmwippe:".$mmwippe."(h:".$wippebytehigh." l:".$wippebytelow.") zeit:".$zeit);
                $commandstring = "\xFE\x30\xFC\xFE\x30".chr($zeit);
                escapeByte($meterbytehigh);
                escapeByte($meterbytelow);
                escapeByte($wippebytehigh);
                escapeByte($wippebytelow);
                $commandstring .= "\xFC";
                #achtung:
                #$commandstring = "\xFE\x30\xFC\xFE\x30\x5\x0\x89\x1\x27\xFC";
                if ($reporting == 1) {
                        $tmpstring = "";
                        foreach $charakter (split (//,$commandstring)) {
                                $tmpstring .= ord($charakter).", ";
                        }
                        write_Log ("schreibe Commandstring: ".$tmpstring);
                }
                write_Log ("Schnittstellenstatus:  ".$online);
                my $laststatus = $online;
                init_USB() if(!$laststatus);
        #####   WS500_write($commandstring);
                close_USB() if(!$laststatus);

        }
}
# *** ENDE ***  Unterprogramm "write_Config" zum Uebertragen der Konfiguration in Richtung WS500

# *** START *** Unterprogramm "write_dev_2_MySQL" zum Uebertragen der Wetterdaten in die MySQL-Datenbank
sub write_dev_2_MySQL {
        $sql="INSERT INTO $dbdatabase.rain VALUES ('','$newmysqltime','1','1','$regen','$regen_menge','1')";
        sqlquery($sql);

        write_Log ("aktuelle Konfigurationsdaten in die MySQL-Datenbank eingetragen");
}
# *** ENDE ***  Unterprogramm "write_dev_2_MySQL" zum Uebertragen der Wetterdaten in die MySQL-Datenbank

# *** START *** Unterprogramm "write_lastcount" zum Speichern der letzten Zaehlerstaende fuer Regen und Licht
sub write_lastcount {
        if(!open(BACKUPFILE, ">".$lastcount)) {                         # Datei zum "Schreiben" oeffnen
                $writeToFile = 0;
                print "Schreiben der Backupdatei ".$recordFile." zum Sichern der beiden Zaehlerstaende fuer rain und light iat fehlgeschlagen! Neue Datei wurde angelegt!\n";
        }

        print BACKUPFILE $regen.";";                                    # letzten Zaehlerstand "Regen" sichern
        print BACKUPFILE $sonne.";";                                    # letzten Zaehlerstand "Sonne" sichern
        close(BACKUPFILE) || warn "close failed";

}
# *** ENDE *** Unterprogramm "write_lastcount" zum Schreiben der Wetterdaten in eine CSV-Datei fuer eine optionale weitere Bearbeitung

# *** START *** Unterprogramm "write_Log" zum Schreiben der Statusinformationen in die Logdatei ($logfile)
sub write_Log {
        my $theMessage = shift;
        my $newtime;
        if ( $reporting == 1 ){
                if(!open(LOGFILE, ">>".$logfile)) {                     # Datei zum "Anfuegen" oeffnen
                        print "Konnte die Logdatei ".$logfile." nicht finden. Eine neue wurde angelegt!\n";
                        }
                print LOGFILE localtime(time()).": ".$theMessage."\n";  # Meldung mit Zeitstempel in die Logdatei schreiben
                close(LOGFILE) || warn "close failed";
                }
        return 0;
}
# *** ENDE ***  Unterprogramm "write_Log" zum Schreiben der Statusinformationen in die Logdatei ($logfile)

# *** START *** Unterprogramm "write_MySQL" zum Uebertragen der Wetterdaten in die MySQL-Datenbank
sub write_MySQL {

        # Luftdruck in der Datenbank ablegen
        $sql="INSERT INTO $dbdatabase.pressure VALUES ('','$newmysqltime','1','20','$druck','1')";
        sqlquery($sql);

        # Windwerte in der Datenbank ablegen
        $sql="INSERT INTO $dbdatabase.wind VALUES ('','$newmysqltime','1','30','$wind_geschwindigkeit','$wind_richtung','$wind_schwankung','1')";
        sqlquery($sql);

        # Regenwerte in der Datenbank ablegen
        if( $regen_db == 1 ) {
                $sql="INSERT INTO $dbdatabase.rain VALUES ('','$newmysqltime','1','40','$regen','$regen_menge','1')";
                sqlquery($sql);
        }

        # Sonnenscheinwerte in der Datenbank ablegen
        if( $sonne_db == 1 ) {
                $sql="INSERT INTO $dbdatabase.light VALUES ('','$newmysqltime','1','50','$sonne_ok','$sonne_delta','','','1')";
                sqlquery($sql);
        }

        # Temperatur + Feuchtewerte der Sensoren 1 bis 9 in der Datenbank ablegen
        for ($i=1; $i < 10; $i++) {
                if( $sensor_db[$i] == 1 ) {
                        $sql="INSERT INTO $dbdatabase.th_sensors VALUES ('','$newmysqltime','1','$i','$temperatur[$i]','$feuchte[$i]','1')";
                        sqlquery($sql);
                }
        }

        # Temperatur + Feuchtewerte des Innensensors in der Datenbank ablegen
        if( $sensor_db[0] == 1 ) {
                $sql="INSERT INTO $dbdatabase.th_sensors VALUES ('','$newmysqltime','1','10','$temperatur[0]','$feuchte[0]','1')";
                sqlquery($sql);
                }

        write_Log ("historische Wetterdaten in die MySQL-Datenbank eingetragen");
}
# *** ENDE *** Unterprogramm "write_MySQL" zum Uebertragen der Wetterdaten in die MySQL-Datenbank

# *** START *** Unterprogramm "write_Record_to_File" zum Schreiben der Wetterdaten in eine CSV-Datei fuer eine optionale weitere Bearbeitung
sub write_Record_to_File {
        if(!open(RECORDFILE, ">>".$recordFile)) {
                $writeToFile = 0;
                print "Schreiben der neuen Datensaetze in die CSV-Datei ".$recordFile." fehlgeschlagen! Neue Datei wurde angelegt!\n";
        }
                                                                        # "Satz-Beschreibung" der CSV-Datei 
        print RECORDFILE $newmysqltime.";";                             # Datensatzzeitstempel im MySQL-Format abspeichern
        print RECORDFILE $regen_alt.";";                                # Regenzaehler "alter Stand"
        print RECORDFILE $regen.";";                                    # Regenzaehler "neuer Stand"
        print RECORDFILE $regen_delta.";";                              # Regenzaehler "Delta"
        print RECORDFILE $regen_menge.";";                              # Regenmenge in ml pro Quadratmeter
        print RECORDFILE $wind_geschwindigkeit.";";                     # Windgeschwindigkeit im km/h
        print RECORDFILE $wind_richtung.";";                            # Windrichtung in Grad
        print RECORDFILE $wind_schwankung.";";                          # Windschwankung +/- in Grad
        print RECORDFILE $druck.";";                                    # relativen Luftdruck (gemessen)
        print RECORDFILE $absdruck.";";                                 # absoluter Luftdruck (umgerechnet)
        print RECORDFILE $sonne_alt.";";                                # Sonnenscheinzaehler "alter Stand"
        print RECORDFILE $sonne.";";                                    # Sonnenscheinzaehler "neuer Stand"
        print RECORDFILE $sonne_delta.";";                              # Sonnenscheindauer in Minuten
        print RECORDFILE $sonne_ok.";";                                 # Sonne scheint == 1 / Sonnescheint nicht == 0
        print RECORDFILE $wettervorhersage.";";                         # Wettervorhersage (noch zu klären!!!!)
        for ($i=1; $i < 10; $i++) {
                if( $sensor_db[$i] == 1 ) {
                print RECORDFILE $temperatur[$i].";";                   # Temperaturwerte der Fuehler 1 bis 9
                print RECORDFILE $feuchte[$i].";";                      # Luftfeuchtewerte der Fuehler 1 bis 9
                }
        }
        print RECORDFILE $temperatur[0].";";                            # Temperaturwert des Innenfuehlers (10)
        print RECORDFILE $feuchte[0].";";                               # Luftfeuchtewert des Innenfuehlers (10)
        print RECORDFILE "\n";                                          # CSV-Zeile abschließen
        close(RECORDFILE) || warn "close failed";
}
# *** ENDE *** Unterprogramm "write_Record_to_File" zum Schreiben der Wetterdaten in eine CSV-Datei fuer eine optionale weitere Bearbeitung

# *** START *** Unterprogramm "write_ws500" zum Uebertragen von Steuerungsinformationen (3 Bytes) zur WS500
sub write_ws500
{
        my $command = shift;
        if ($command ne "") {
                $FTDI->purge_all;                                       # Sende- und Empfangspuffer leeren
                syswrite FTD,  $command, length($command), 0;           # 3 Bytes in Richtunf WS500 schieben
                select(undef, undef, undef, 0.5);                       # 0.5 sec warten
                $FTDI->purge_tx;                                        # Sendepuffer leeren
        }
}
# *** ENDE ***  Unterprogramm "write_ws500" zum Uebertragen von Steuerungsinformationen (3 Bytes) zur WS500

# *** START *** Unterprogramm "write_Status_To_File" zum Schreiben der Stationsdaten in die Datei ($statusFile)
sub write_Status_To_File {
        my $theMessage = shift;
        if(!open(STATUSFILE, ">".$statusFile)) {
                print "Schreiben der Wetterstationsdaten in die Datei ".$statusFile." fehlgeschlagen! Neue Datei wurde angelegt!\n";
        }
        else {
                print STATUSFILE "Firmware-Version: ".$firmware."\n";
                print STATUSFILE "Messintervall: ".$intervall." Minuten.\n";
                print STATUSFILE "Hoehe: ".$hoehe." m ue.NN.\n";
                print STATUSFILE "Wippe: ".$wippe." ml/Impuls\n";
                for ($i=1; $i < 10; $i++) {
                        if ($sensoren_status[$i] < 0) {
                                print STATUSFILE "Sensor ".$i.": nicht verfuegbar.\n";
                        }
                        else {
                                print STATUSFILE "Sensor ".$i.": verfuegbar (Empfangsausfaelle: ".$sensoren_status[$i].")\n";
                        }
                }
                close (STATUSFILE);
        }
 }
# *** ENDE ***  Unterprogramm "write_Status_To_File" zum Schreiben der Stationsdaten in die Datei ($statusFile)