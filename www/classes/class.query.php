<?php
	$conn=mysql_connect($db_server, $db_username, $db_password) or die("Could not connect to database\n".mysql_error());
	mysql_select_db($db_name, $conn) or die("Could not select table\n".mysql_error());
	
	class Query {
		var $_sql = null;
		var $_result = 0;
		var $_errno = 0;
		var $_error = null;
		var $_start = null;
		var $_end = null;
		
		function Query($sql="") {
			if (empty($sql)) return false;
			
			$this->start=microtime();
			mysql_query("SET NAMES utf8");
			
			// Query in der Klasse speichern
			$this->_sql = trim($sql);
			
			$this->_result = mysql_query($this->_sql);

			if(!$this->_result) {
				$this->_errno = mysql_errno();
				$this->_error = mysql_error();
			}     

			// 10.05, translate table wurde auf mehrere tabellen zerteilt
			// wenn tabelle fuer die sprache nicht vorhanden ist, soll die fehlermerldung nicht ausgegeben werden
			// Error: 1146 SQLSTATE: 42S02 (ER_NO_SUCH_TABLE)
			//if ( $this->_errno == 1146 ) 
				//throw new Exception( "$this->_errno" );
			//else
				if ($this->error()) echo $this->getError();
		}
		
		function tableNotFound() {
			return $this->_tableNotFound;
		}
		
		function error() {
		 	// Result-ID in einer tmp-Variablen speichern 
		 	$tmp = $this->_result;
		 	// Variable in boolean umwandeln
		 	$tmp = (bool)$tmp;
		 	// Variable invertieren
		 	$tmp = !$tmp;
		 	// und zurückgeben
		 	return $tmp;
		}
		
		function close() {
			mysql_close();
		}
		 
		function getError() {
			if($this->error()) {
		 		$str  = "Anfrage:\n".$this->_sql."<br>"; 
		 		$str .= "Antwort:\n".$this->_error."<br>";
		 		$str .= "Fehlercode: ".$this->_errno."<br>";
		 	} else {
		 		$str = "Kein Fehler aufgetreten.";
		 	}
		 	return $str;
		}
		 
		function getSQL() {
		  return $this->_sql;
		}
		 
		function fetch() {
		 	if($this->error()) {
		 		echo "Es trat ein Fehler auf. Bitte überprüfe deine MySQL-Query.<br/>";
		 		echo $this->getError();
		 		$return = null;
		 	} else {
		 		$return = mysql_fetch_assoc($this->_result);
		 	}
			
			$this->end=microtime();
		 	return $return;
		}
		
		function field_type($no) {
			return mysql_field_type($this->_result, intval($no));
		}
		 
		function numRows() {
		 	if($this->error()) {
		 		$return = -1;
		 	} else {
		 		$return = mysql_num_rows($this->_result);
		 	}
		 	return $return;
		}
		 
		 
		function free() {
		 	mysql_free_result($this->_result);
		}
		 
		function get_mysql_id() {
		 	// Zuletzt eingetragener Datensatz (ID)
		 	$return = mysql_insert_id();
		 	return $return;
		}
		 
		function affected_rows() {
		 	$return = mysql_affected_rows();
		 	return $return;
		}
		 
		function query_time() {
			$diff=($this->end)-($this->start);
			return round($diff, 3);
		}
		 
		function move($value) {
		 	$return = mysql_data_seek($this->_result, $value);
		}
	}