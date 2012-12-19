use strict;
use File::Basename;
use File::Find;
use File::Path qw(make_path);
use Getopt::Long;

my $dirs='';
my $outfile='';
my $logfile='';
my $tname='';
my $help='';

my @csvfiles;

########################################################
#    AddCSVFiles��������Ҫ��File::Findʹ�ã���--dir       #
#    ѡ���ʱ����ݹ�����ָ����Ŀ¼�����ҵ���csv�ļ���         #
#    ��@csvfiles����                                    #
########################################################
sub AddCSVFiles
{
	if (-f $File::Find::name) {
        if ($File::Find::name =~ /$tname\.csv$/) {
            push @csvfiles, $File::Find::name;
        }
	}
}

#############################################################
#    GetUserName�����������ļ���ȡ��basename��ΪҪ������        #
#    �û�������ȡ��������Ŀ¼                                  #
#    ���룺һ�������ļ�ȫ·�����ַ���                           #
#    ���أ��ļ���basename��dirname                            #
#############################################################
sub GetUserName
{
	my ($uname, $csvdir)=fileparse(shift @_, qr/\.(\w+)$/);
	return ($uname, $csvdir);
}

#######################################################
#    DisplayHelp�����������--helpѡ�����ʾ������Ϣ      #
#######################################################
sub DisplayHelp
{
	print "mergecsv�������������ɶ���������������PerlС����\n";
	print "����;�ǰ����ɸ��ṹ��ͬ��csv�ļ������ϲ�Ϊһ����\n";
	print "��Ȩû�У����治���������������޸�Դ���롣\n";
	print "�÷���perl mergecsv.pl [����]\n";
	print "�����У�\n";
	print "  --dir=        comma seperated directories in which csv files reside(recursively).\n";
	print "  --of=         the path of the final result csv file.\n";
	print "  --tn=         the table name suffix of the csv file.\n";
	print "  --log=        the path of the merge log file.\n";
}

#############################################################
#    ParseCommand���������������в�����������Ӧ�ĺ���              #
#############################################################
sub ParseCommand
{
	my $result=GetOptions(
		'dir=s' => \$dirs,
		'of=s' => \$outfile,
		'log=s' => \$logfile,
		'tn=s'  => \$tname,
		'help!' => \$help);
	
	# �����޷������Ĳ�����ֱ�ӱ����˳�
	if(!$result) 
	{
		exit(1);
	}
	
	#�����--help������ʾ������Ϣ
	if($help)
	{
		&DisplayHelp();
		exit(0);
	}
	
	# ���ָ�����Ŀ¼����ݹ�������е�csv�ļ�
	if($dirs)
	{
	    $dirs=~s/\\/\//g;
	    foreach my $dir (split(/,/, $dirs))
		{
			find(\&AddCSVFiles, $dir);
		}
	}
	
	# ���û���ҵ�CSV�ļ��򱨴��˳�
	if(@csvfiles==0)
	{
		print "Cannot find csv files to merge.\n";
		print "For command line usage help, please execute with --help option.\n";
		exit(1);
	}
	
	# ���δָ����־�ļ�����Ĭ����mergecsv.pl�����ļ����н���'mergecsv_log.txt'
	if(!$logfile)
	{
		$logfile='mergecsv_log.txt';
	}
	else
	{
		$logfile=~s/\\/\//g;
		my ($base, $dir)=&GetUserName($logfile);
		if(!-e $dir)
		{
			make_path($dir);
		}
	}
	
	# ���δָ���������ļ�����Ĭ����mergecsv.pl�����ļ����н���'mergeresult.csv'
	if(!$outfile)
	{
		$outfile='mergeresult.csv';
	}
	else
	{
		$outfile=~s/\\/\//g;
		my ($base, $dir)=&GetUserName($outfile);
		if(!-e $dir)
		{
			make_path($dir);
		}
	}
	&MergeCSV();
}

#######################################################
#    MergeCSV: �����򣬱���ָ����csv�ļ����ϲ���¼��������־  #
#    ��������ṹ��ͬ��CSV������                           #
#######################################################

sub MergeCSV
{
	open LOG, ">$logfile" or die "Cannot open log file to write!";
	open RESULT, ">$outfile" or die "Cannot open result file to write!";
	my $timestamp=localtime;
	my $headers;
	my $rightfilenum=0;
	my $wrongfilenum=0;
	print LOG "��ʼ�ϲ���ʱ����$timestamp.\n";
	print LOG '='x30, "\n";
	foreach my $csvfile (@csvfiles)
	{
		my $rowcount=1;
		my ($filesource,$filedir)=&GetUserName($csvfile);
		$filesource=~s/_$tname$//;
		if(!open DATA, "<$csvfile")
		{
			warn "Cannot open $csvfile, skip that file!";
			print LOG "�޷���$csvfile, ��������\n";
			print LOG '-'x30, "\n";
			$wrongfilenum++;
		}
		else
		{
			$timestamp=localtime;
			print LOG "��ʼ����$csvfile��ʱ����$timestamp.\n";
			if(!$headers)
			{
				$headers=<DATA>;
				chomp($headers);
				print RESULT "��Դ��,$headers\n";
				$rowcount++;
				while(<DATA>)
				{
					chomp;
					print RESULT "$filesource,$_\n";
					$rowcount++;
				}
				$timestamp=localtime;
				print LOG "��ɣ�������$rowcount�У�ʱ����$timestamp.\n";
				print LOG '-'x30, "\n";
				$rightfilenum++;
			}
			else
			{
				my $tmp=<DATA>;
				chomp($tmp);
				if($headers ne $tmp)
				{
					print LOG "$csvfile�ļ�ͷ�������ļ���ƥ�䣬��������\n";
					print LOG '-'x30, "\n";
					$wrongfilenum++;
				}
				else
				{
					while(<DATA>)
					{
						chomp;
						print RESULT "$filesource,$_\n";
						$rowcount++;
					}
					print LOG "��ɣ�������$rowcount�У�ʱ����$timestamp.\n";
					print LOG '-'x30, "\n";
					$rightfilenum++;
				}
			}
		close DATA;
		}
	}
	print LOG "��ɺϲ������ϲ�$rightfilenum���ļ�������$wrongfilenum���ļ���\n";
	print LOG '='x30;
	close LOG;
	close RESULT;
}

&ParseCommand();