#!/usr/bin/php
<?php
$date = `date`;
$hostname = `hostname`;
$hostname = str_replace("\r","",$hostname);
$hostname = str_replace("\n","",$hostname);
$local_ip       = `hostname -i`;
//print "--$hostname--\n";
 $subject = $hostname;
 
### replace your email address here
$f_to = "name@email.com";
$from = "nagios@$hostname";
//print "hostname = $hostname\n";
//
$service = `/etc/init.d/nagios3 status`;
$service = str_replace("\r","",$service);
$service = str_replace("\n","",$service);
//print "service = $service\n";
//
$headers = "From: $from\r\n";
$headers = $headers."Content-type: text/html\r\n";
//
if($service == "nagios is not running" || $service == "No lock file found in /usr/local/nagios/var/nagios.lock" || $service == "checking /usr/sbin/nagios3...failed (not running)."){

         $body = "<html><body>";
         $body = "sent from: $hostname<br><br>";
         $body .= "$hostname <b>$service</b><br>";
         $body .= "</body></html>";

        $headers = "From: $from\r\n";
        $headers = $headers."Content-type: text/html\r\n";
        $stop = `/etc/init.d/nagios3 stop`;
        $start = `/etc/init.d/nagios3 start`;
        $service2 = `/etc/init.d/nagios3 status`;
        if($service2 == "checking /usr/sbin/nagios3...failed (not running)."){
             mail($f_to, $subject, $body, $headers) or die("cannot send mail");
        }else {
        $body = "nagios was stopped, but i started it<br>$service2<br>$hostname";
	  mail($f_to, $subject, $body, $headers) or die("cannot send mail");
        print "$body-$date";
        }
}else die("nagios is still running-$date Nagios Status:\n$service\n");

?>
