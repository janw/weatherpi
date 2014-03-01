<?php
	error_reporting(E_ALL & ~(E_STRICT|E_NOTICE));
	ini_set('error_reporting', E_ALL);
	ini_set('display_errors','On');
	
	
	require_once ($_SERVER['DOCUMENT_ROOT'].'/config.php');
	require_once ($_SERVER['DOCUMENT_ROOT'].'/classes/class.query.php');
?>
<!DOCTYPE HTML>
<html>
      	<head>
      			<link href='http://fonts.googleapis.com/css?family=Montserrat+Alternates:400,700' rel='stylesheet' type='text/css'>
      			<style type="text/css">
      				body { font-family: 'Montserrat Alternates', sans-serif; }

					nav .flaticon {
					  width: 30px !important;
					  height: 30px !important;
					}

					nav .menucaller{
					  float: right;
					  padding-top: 4px;
					  padding-left: 5px;
					}

					nav ol, nav ul {
					  list-style: none;
					}

      				nav {
					  background: -webkit-gradient(linear, center top, center bottom, from(#fff), to(#ccc));
					  background-image: linear-gradient(#fff, #ccc);
					  border-radius: 6px;
					  box-shadow: 0px 0px 4px 2px rgba(0,0,0,0.4);
					  padding: 0 10px;
					  position: relative;
					  height:55px;
					}

					.menu li {
					  float: left;
					  position: relative;
					}

					.menu li a {
					  color: #444;
					  display: block;
					  font-size: 16px;
					  font-weight: 100;
					  line-height: 20px;
					  padding: 6px 12px;
					  margin: 8px 8px;
					  vertical-align: middle;
					  text-decoration: none;
					}

					.menu li a:hover {
					  background: -webkit-gradient(linear, center top, center bottom, from(#ededed), to(#fff));
					  background-image: linear-gradient(#ededed, #fff);
					  border-radius: 12px;
					  box-shadow: inset 0px 0px 1px 1px rgba(0,0,0,0.1);
					  color: #222;
					}

					/* Dropdown styles */

					.menu ul {
					  position: absolute;
					  left: -9999px;
					  list-style: none;
					  opacity: 0;
					  transition: opacity 1s ease;
					}

					.menu ul li {
					  float: none;
					}

					.menu ul a {
					  white-space: nowrap;
					}

					/* Displays the dropdown on hover and moves back into position */
					.menu li:hover ul {
					  background: rgba(255,255,255,0.7);
					  border-radius: 0 0 6px 6px;
					  box-shadow: inset 0px 2px 4px rgba(0,0,0,0.4);
					  left: 5px;
					  opacity: 1;
					}

					/* Persistant Hover State */
					.menu li:hover a {
					  background: -webkit-gradient(linear, center top, center bottom, from(#ccc), to(#ededed));
					  background-image: linear-gradient(#ccc, #ededed);
					  border-radius: 12px;
					  box-shadow: inset 0px 0px 1px 1px rgba(0,0,0,0.1);
					  color: #222;
					}

					.menu li:hover ul a {
					  background: none;
					  border-radius: 0;
					  box-shadow: none;
					}

					.menu li:hover ul li a:hover {
					  background: -webkit-gradient(linear, center top, center bottom, from(#eee), to(#fff));
					  background-image: linear-gradient(#ededed, #fff);
					  border-radius: 12px;
					  box-shadow: inset 0px 0px 3px 2px rgba(0,0,0,0.3);
					}

      			</style>
				<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
                <script type="text/javascript" src="js/jqPlot/jquery.jqplot.min.js"></script>
                <script type="text/javascript" src="js/jqPlot/plugins/jqplot.barRenderer.min.js"></script>
                <script type="text/javascript" src="js/jqPlot/plugins/jqplot.highlighter.min.js"></script>
                <script type="text/javascript" src="js/jqPlot/plugins/jqplot.cursor.min.js"></script>
                <script type="text/javascript" src="js/jqPlot/plugins/jqplot.pointLabels.min.js"></script>
                <link rel="stylesheet" type="text/css" href="js/jqPlot/jquery.jqplot.min.css" />
                <script type="text/javascript">
                    jQuery(document).ready(function () {
                        var s1 = [<? /*
                        [23, 0],[24, 2],[25, 5],[26, 12],[27, 18],[28, 22],[29, 16],[30, 18],[31, 1],[1, 4],[2, 21],
                        [3, 23],[4, 28],[5, 21],[6, 29],[7, 33],[8, 83],[9, 12],[10, 7],[11, 23],[12, 21],
                        [13, 23],[14, 8],[15, 23],[16, 25],[17, 20],[18, 3],[19, 17],[20, 64],[21, 23],[22, 17] */ 
	$res = new Query("SELECT H,datetime FROM th_sensors WHERE H <= 200 AND H > 0 ORDER BY datetime DESC LIMIT 0,5900");
	$i = 0;
	if ( $res->numRows() > 0 ) {
		while ( $rs = $res->fetch() ){
			if($i>0) echo ",";
			$i++;
		//	echo "['".$rs['datetime']."',".$rs['H']."]";
			echo "[".$i.",".$rs['H']."]";
		}
	}
	?>];
        			var s2 = [<? /*
                        [24, 10],[30, 40],[5, 10],[12, 10]   */
	$res = new Query("SELECT T,datetime FROM th_sensors WHERE T <= 50 ORDER BY datetime DESC LIMIT 0,5900");
	$i = 0;
	if ( $res->numRows() > 0 ) {
		while ( $rs = $res->fetch() ){
			if($i>0) echo ",";
			$i++;
		//	echo "['".$rs['datetime']."',".$rs['T']."]";
		echo "[".$i.",".$rs['T']."]";
		}
	}
?>];
                     
                        plot1 = jQuery.jqplot("chart1", [s1, s2], {
                            // Turns on animatino for all series in this plot.
                            animate: true,
                            // Will animate plot on calls to plot1.replot({resetAxes:true})
                            animateReplot: true,
                            cursor: {
                                show: true,
                                zoom: true,
                                looseZoom: true,
                                showTooltip: false
                            },
                            series:[
								{
									showLine:true, 
									markerOptions: { size: 1, style:"filledSquare"}
								},
								{
								    pointLabels: {
                                        show: false
                                    },
                                    renderer: jQuery.jqplot.BarRenderer,
                                    showHighlight: false,
                                    yaxis: 'y2axis',
                                    rendererOptions: {
                                        // Speed up the animation a little bit.
                                        // This is a number of milliseconds.  
                                        // Default for bar series is 3000.  
                                        animation: {
                                            speed: 2500
                                        },
                                        barWidth: 2,
                                        barPadding: -15,
                                        barMargin: 0,
                                        highlightMouseOver: false
                                    }
                                }, 
                                {
									pointLabels: {
                                        show: false
                                    },
                                    rendererOptions: {
                                        // speed up the animation a little bit.
                                        // This is a number of milliseconds.
                                        // Default for a line series is 2500.
                                        animation: {
                                            speed: 1000
                                        }
                                    }
                                }

                            ],
                            axesDefaults: {
                                pad: 0
                            },
                            axes: {
                                // These options will set up the x axis like a category axis.
                                xaxis: {
                                    tickInterval: 1,
                                    drawMajorGridlines: true,
                                    drawMinorGridlines: false,
                                    drawMajorTickMarks: true,
                                    rendererOptions: {
                                    tickInset: 0.5,
                                    minorTicks: 1
                                }
                                },
                                yaxis: {
                                    tickOptions: {
                                        formatString: "%'d"
                                    },
                                    rendererOptions: {
                                        forceTickAt0: true
                                    }
                                },
                                y2axis: {
                                    tickOptions: {
                                        formatString: "%'d"
                                    },
                                    rendererOptions: {
                                        // align the ticks on the y2 axis with the y axis.
                                        alignTicks: true,
                                        forceTickAt0: true
                                    }
                                }
                            },
                            highlighter: {
                                show: true, 
                                showLabel: true, 
                                tooltipAxes: 'y',
                                sizeAdjust: 7.5 , tooltipLocation : 'ne'
                            }
                        });
                       
                    });
                    </script>
	<title><?=$_SERVER["REMOTE_ADDR"]?></title>
        </head>
		<body>
		<h1>Weather Pi</h1>
		<h3 style="color:#e3d13e">WS 300 PC-II powered Raspberry Pi</h3>
		<nav>
			<ul class="menu">
		      <li><a href="#"><img class="flaticon" src="img/flaticons/View-128.png" alt="Uebersicht"> <div class="menucaller">&Uuml;bersicht</div></a></li>
		      <li><a href="#"><img class="flaticon" src="img/flaticons/Home-128-2.png" alt="Homepage"> <div class="menucaller">Credits</div></a></li>
		      <li><a href="#"><img class="flaticon" src="img/flaticons/Customize-01-128.png" alt="Einstellungen"> <div class="menucaller">Einstellungen</div></a></li>      
		    </ul>

		</nav>

        <div id="chart1" style="height:200px;width:610px; "></div>
		<?php
		?>
		</body>
</html>
