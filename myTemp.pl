#!/usr/bin/perl -w
###########################################################################################
# Temperature Monitor script
# written by: Brian Ramuno
# http://collectivenothing.blogspot.com/2014/01/home-temperature-monitor-notification.html
# for use with Raspberry Pi
########################################################################################### 

#use lib "/usr/local/nagios/libexec";   # use this if you installed nagios from source
use lib "/usr/lib/nagios/plugins";      # use this if you installed nagios from repos
use utils qw(%ERRORS);
use Getopt::Long;
use Math::Round;

my $debug = "no";
my $min = undef;
my $max = undef;
my $type = undef;
my $folder = undef;   #define file name 
my $standard = "";
my $zone = undef;
my $process = "cacti";

# ####################################################################################################################################################################################
sub print_usage {
 print "/usr/bin/perl myTemp.pl -x <minimum> -y <maximum> -f <Folder Name> -t <C/F> -d <yes> \nExample: ./myTemp.pl -x 40 -y 100 -f folderName -t F -z zoneName -d yes\n";
}
# ####################################################################################################################################################################################
sub help {
print_usage();
print <<EOT;
	-h, --help
		print this help message
	-x, --minimum=value
		Minimum temperature before sending alert(required)	
	-y, --maximum=value
		Maximum temperature before sending alert(required)			
	-f, --folder=name
		Folder name where temperature data is stored (required)	
	-t, --type=C/F
		Celcius of Farenheit (required)	
	-z, --zone=name
		Name of zone (or kennel)	
	-d, --debug=yes
		print data for command line debugging (optional)
	-p, --process=nagios/cacti
EOT
}
# ####################################################################################################################################################################################

sub check_options {
 Getopt::Long::Configure ("bundling");
 GetOptions (
	 'h'     => \$help,    'help'         		 =>      \$help,
	 'x:s'     => \$minimum,    'minimum'          =>      \$minimum,
	 'y:s'     => \$maximum,    'maximum'          =>      \$maximum,
	 'f:s'     => \$folder,    'folder'        =>      \$folder,
	 't:s'     => \$type,    'type'        =>      \$type,
	 'z:s'     => \$zone,    'zone'        =>      \$zone,
         'p:s'     => \$process,    'process'        =>    \$process,
	 'd:s'   => \$debug,    'debug'        		 =>      \$debug		 
	    );
		
if (defined ($help)) {
	help();
	exit $ERRORS{"UNKNOWN"}};
if (!defined ($minimum)) {
	print"No minimum temperature defined, use -x\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"}};

if (!defined($maximum)) {
	print "No maximum temperature defined, use -y\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"}};	
if (!defined($folder)) {
	print "No filename defined, use -f\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"}};	
if (!defined($type)) {
	print "No temperature standard defined, use -t\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"}}
if (!defined($zone)) {
	print "No zone defined, use -z\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"}}
		
if($type eq "f" ){$type = "F";};if($type eq "c"){ $type = "C";};

if ( $type eq "F" || $type eq "C"  ) {  
		print ""; # do nothing
	}else{
	print "Unknown temperature standard defined.  Use C or F.\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"}};	
}

# ###############################################################################################################################################################################
check_options();
# ###############################################################################################################################################################################
my $date = ` date +"%Y%m%d"`;
if($type eq 'C'){$standard = "Celcius";};
if($type eq 'F'){$standard = "Farenheit";};

if( -d "/temp/$folder" ){
	print "";
}else {
      print "connection to $zone sensor is offline. cannot find /temp/$folder\n";
      exit $ERRORS{"UNKNOWN"};
}

my $filename = "/temp/$folder/w1_slave";
if($debug eq "yes"){ print "filename = $filename\nmin = $minimum, max = $maximum, type = $type, standard = $standard\n"}

my $checkFile = undef;

my $data = undef;
my $loop = 0;
my @checkFileArray = ();
my $size = undef;

## retry if bad reading is detected
do{
	open(CURRENT, "< $filename") or die "Could not open file '$filename' $!";
	{
	        local $/;  # read all contents of opened file
	        $checkFile = <CURRENT>;  # place contents in this variable
	}
	close CURRENT;
	@checkFileArray = split(" ",$checkFile);
		if($debug eq "yes"){ 
			for($a=0;$a<@checkFileArray;$a++){
				print "checkFileArray[$a] = $checkFileArray[$a]\n"; 
			}
		}
	
	$size = @checkFileArray;
	$data = $checkFileArray[$size-1];  # most of what we need is the last array value
	if($debug eq "yes"){ print "data1 = $data\n"}
	
	# filter string
	$data =~ s/t=//g;
	if($debug eq "yes"){ print "data2 = $data\n"}
	
	if( $data < -20 || $data > 80000 || $data == 0 ){ $loop = $loop +1; }else{ $loop = 15; }
} until($loop==15);

# quit if sensor is offline
if( $data < -20 || $data > 80000 || $data == 0 ){
        print "connection to $zone sensor is offline.\n";
        exit $ERRORS{"UNKNOWN"};
}
if( $checkFileArray[11] eq "NO" ){
        print "connection to $zone sensor is offline.\n";
        exit $ERRORS{"UNKNOWN"};
}

# add decimal point
######################################
$data = $data/1000;
my $Cdata = round($data);
	if($debug eq "yes"){ print "data3 = $data\n\n"}

my $Fdata = (9 * $data/5) + 32;
	if($debug eq "yes"){ print "Fdata = $Fdata\nCdata = $Cdata\n\n"}
$Fdata = round($Fdata);
	if($debug eq "yes"){ print "Fdata = $Fdata\nCdata = $Cdata\n\n"}

#########################################
my $use = undef;
if($standard eq "Farenheit"){ $use = $Fdata }
if($standard eq "Celcius"){ $use = $Cdata }
my $MinWarningLevel = $minimum-5;
my $MaxWarningLevel = $maximum+5;
	if($debug eq "yes"){ print "use = $use\nwarning level = $MinWarningLevel\nMaxWarningLevel = $MaxWarningLevel\n "}


if($process eq "nagios"){

if( $use > $minimum  && $use < $maximum ){
		print "Temperature: $use degrees $standard. Threshold:  $minimum-$maximum degrees $standard.   Everything is ok.\n";
		exit $ERRORS{"OK"};	
	}elsif( $use > $MinWarningLevel && $use <= $minimum ){
		print "WARNING-Temperature: $use degrees $standard. Temperature is outside desired range!  Please check $zone kennel.\n";
		exit $ERRORS{"WARNING"};	
	}elsif( $use > $maximum && $use <= $MaxWarningLevel ){
		print "WARNING-Temperature: $use degrees $standard. Temperature is outside desired range!  Please check $zone kennel.\n";
		exit $ERRORS{"WARNING"};
	}elsif( $use > $MaxWarningLevel || $use < $MinWarningLevel ){
		print "CRITICAL-Temperature: $use degrees $standard. Temperature is way outside desired range!  Please check $zone kennel.\n";	
		exit $ERRORS{"CRITICAL"};	
	}else{
		print "something went wrong!\n";
		exit $ERRORS{"UNKNOWN"};	
	}
}else{

	print "$use ";
}





