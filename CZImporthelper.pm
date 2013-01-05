package CZImporthelper;
use strict;
use File::Basename;
require Exporter;

our @ISA=qw(Exporter);

our @EXPORT=qw(ParseSQL DisplayHelp GetUserName);

#######################################################
#    DisplayHelp�����������--helpѡ�����ʾ������Ϣ      #
#######################################################
sub DisplayHelp
{
	print "szimport�������������ɶ���������������PerlС����\n";
	print "����;�ǰ����ɸ�Oracle dmp�ļ������������ݿⲢִ�в�ѯ��\n";
	print "��Ȩû�У����治���������������޸�Դ���롣\n";
	print "�÷���perl szimport.pl [����]\n";
	print "�����У�\n";
	print "  --syspass=    the password of the sys user in Oracle.\n";
	print "  --tbs=        the tablespace to use for imp.\n";
	print "  --host=       the hostname of the Oracle server.\n";
	print "  --sid=        the Oracle sid.\n";
	print "  --file=       comma seperated file patterns to specify the files to be imported.\n";
	print "  --dir=        comma seperated directories in which dmp files reside(recursively).\n";
	print "  --outdir=     the directory to hold the result csv files.\n";
	print "  --tables=     comma seperated table names to be import.\n";
	print "  --sql=        the sql script to be executed after importing the data.\n";
	print "  --log=        the path of the log file.\n";
	print "  --du          delete the user the tables belongs to him at last.\n";
}

########################################################
#    ParseSQL���������ڶ�ȡ������SQL�ű��������ֽ�Ϊһ����   # 
#    ��䣬��������󷵻ء�                               #
#    ���룺 SQL�ű�·��                                  #
#    ����� һ�����飬���ֺŽ��ű��ֿ�Ϊһ�������           #
########################################################

sub ParseSQL
{
	my $fpath=shift @_;
	my $tmp='';       #������ʱ������
	my @queries;      #���ڴ�Ž������
	# �򿪴�ִ�е�SQL������ڵ��ļ������������ݵ�һ��������
	open SQL, "<$fpath" or die "Cannot open the SQL statement file.";
	while(<SQL>)
	{
		#ȥ����β�Ļ��з�����β�İ׿ո�Ͷ���İ׿ո�
		chomp;
		s/^\s+//;
		s/\s+$//;
		s/\s+/ /g;

		#������ǿ��У������������ע��
		if($_)
		{
	        #�ж��Ƿ�Ϊ--export��--insertע�ͣ�������������У����Ϊ����ע�ͣ���ɾ������
			if(/^-{2,}(\S+)/)
			{
				if(($1=~/export/i) or ($1=~/insert/i))
				{
					$tmp=$tmp.$_;
				}
				else
				{
					$_='';
				}
			}
			else
			{
				$tmp=$tmp." $_";
				if(/;$/)
				{
					$tmp=~s/^\s+//;
					$tmp=~s/;//;
					push @queries, $tmp;
					$tmp='';
				}
			}
		}
	}
	close SQL;
	return @queries;
}

#############################################################
#    GetUserName�����������ļ���ȡ��basename��ΪҪ������        #
#    �û�������ȡ��������Ŀ¼                                  #
#    ���룺һ�������ļ�ȫ·�����ַ���                           #
#    ���أ��ļ���basename��dirname                            #
#############################################################
sub GetUserName
{
	my ($uname, $dmpdir)=fileparse(shift @_, qr/\.(\w+)$/);
	return ($uname, $dmpdir);
}

1;



