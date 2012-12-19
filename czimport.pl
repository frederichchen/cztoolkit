BEGIN { push @INC, './' }
use strict;
use File::Find;
use File::Path qw(make_path);
use DBI;
use Getopt::Long;
# CZImporthelper.pm�д�ŵ���czimport���õ���һЩ����
use CZImporthelper;

# �趨����ʮһ��������ȱʡֵ�����ǵ�ֵ������ͨ�������в������޸�
my $dmpglob='';
my $dirs='';
my $outdir='';
my $tables='';
my $sqlfilepath='';
my $deluser=0;
my $syspass='yourpass';
my $tbs='sccz';
my $hostname='localhost';
my $sid='orcl';
my $help=0;
  
my @dmpfiles;                           #�����������д�����dmp�ļ���
my @statements;                         #�������Ŵ�SQL�ļ��ж�������


########################################################
#    AddDumpFiles��������Ҫ��File::Findʹ�ã���--dir         #
#    ѡ���ʱ����ݹ�����ָ����Ŀ¼�����ҵ���dmp�ļ���             #
#    ��@dmpfiles����                                     #
########################################################
sub AddDumpFiles
{
	if (-f $File::Find::name) {
        if ($File::Find::name =~ /\.dmp$/) {
            push @dmpfiles, $File::Find::name;
        }
	}
}


#####################################################
#    ParseCommand���������Խ��������в���               #
#    ��--fileָ����ģʽչ������@dmpfiles������          #
#    ��--sqlָ�����ļ�����$sqlfilepath������            #
#    �ж��Ƿ���--du��־������������ɺ�ɾ���û��ͱ�       #
######################################################
sub ParseCommand
{
	#ִ��Getoptģ���GetOptions����ȡ�����в���
	my $result=GetOptions(
		'file=s' => \$dmpglob,
		'dir=s'  => \$dirs,
		'outdir=s' => \$outdir,
		'tables=s' => \$tables,
		'sql=s'  => \$sqlfilepath,
		'du!' => \$deluser,
		'syspass=s' => \$syspass,
		'tbs=s' => \$tbs,
		'host=s' => \$hostname,
		'sid=s' => \$sid,
		'help!' => \$help);

	#����в�ʶ��Ĳ��������⣬��ֱ���˳�
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

	#�����dirѡ���ݹ��������е�dmp�ļ�
	if($dirs)
	{
	    $dirs=~s/\\/\//g;
	    foreach my $dir (split(/,/, $dirs))
		{
			find(\&AddDumpFiles, $dir);
		}
	}

    #�����--fileѡ�����ö��ŷָ��glob���ν���չ����ȡ���ļ�������ļ��������򱨴��˳�
	if($dmpglob)
	{
		$dmpglob=~s/\\/\//g;
		foreach my $eachglob (split(/,/, $dmpglob))
		{
			foreach my $bakfile (glob($eachglob))
		    {
				if(-e $bakfile)
				{
				    push @dmpfiles, $bakfile
				}
				else
			    {
					print "Cannot find the file $eachglob.\n";
					exit(1);
			    }
		    }
	    }
    }

	#���·����û���κ��ļ����򱨴��˳���
	if(@dmpfiles==0)
	{
		print "Cannot find dmp files to import.\n";
		print "For command line usage help, please execute with --help option.\n";
		exit(1);
	}
	
	# �ж��û�ָ����sql�ű��Ƿ���ڣ����û��--sqlѡ����ִ�нű�
	if($sqlfilepath && !(-e $sqlfilepath))
	{
		print "Cannot find the sql script file $sqlfilepath.\n";
		exit(1);
	}
	&ImportFile();
}


#############################################################
#    ImportFile�����������ǽ�������dmp�ļ�����������ݿ⡣       #
#    �����ʱ������dmp�ļ���basename������ͬ���û���           #
#    �������û�����ͬ���ú���������cu.sql�ļ���������SQLPlus     #
#    ��ִ�д����û�����Ȩ���ܣ�������imp�������ݡ�              #
#############################################################
sub ImportFile
{
	#�����ж��û�����ָ��sql�ű��ļ�������������ݲ��ֽ�Ϊ���SQL���
	if($sqlfilepath)
	{
		@statements=&ParseSQL($sqlfilepath);
    }

	#�������ÿ��dmp�ļ������е������
	foreach my $dmpfile (@dmpfiles)
	{
		my ($user_name, $dmp_dir)=&GetUserName($dmpfile);
		# ���潨��һ��cu.sql���ļ����ѽ����û�����Ȩ��SQL���д��ȥ����sqlplusִ��
		open CU, ">cu.sql" or die "Cannot open the sql file to write!";
		print CU "create user $user_name identified by $user_name default tablespace $tbs account unlock;\n";
		print CU "grant CONNECT to $user_name WITH ADMIN OPTION;\n";
		print CU "grant RESOURCE to $user_name WITH ADMIN OPTION;\n";
		print CU "grant DBA to $user_name WITH ADMIN OPTION;\n";
		print CU "exit;\n";
		close CU;
		system("sqlplus sys/$syspass\@$sid as sysdba \@cu.sql")==0 or die "Cannot execute user creation command.";
		
		#�ж�����--tablesѡ�������ָ����������ȫ����
		if($tables)
		{
			system("imp $user_name/$user_name\@$sid file=\'$dmpfile\' tables=($tables)");
		}
		else
		{
			system("imp $user_name/$user_name\@$sid file=\'$dmpfile\' full=y ignore=y");
		}

		#���ָ����--outdirѡ����csv�ļ����浽ָ��Ŀ¼
		if($outdir)
		{
			$outdir=~s/\\/\//g;
			$outdir=~s/\/$//;
			if(!-e $outdir)
			{
				make_path($outdir);
			}
			$dmp_dir=$outdir;
		}
		
		#�����ж��û�����ָ��sql�ű��ļ��������������ݿ�ִ��sql�ű�
		if($sqlfilepath)
		{
			my $dbh=DBI->connect("dbi:Oracle:host=$hostname;sid=$sid", $user_name, $user_name) or die "Cannot conenct db: $DBI::errstr\n";
			
			# ��������ִ�д��ļ��ж�ȡ��SQL��䣬��������ڡ�dmp�ļ���_����.csv���ļ���
			my $count=1;
			my $tname='';
			my $saveout=0;
			my $tmp;
			foreach my $statement (@statements)
			{
				$tmp=$statement;
				#�ж����ǰ��û��"--export"ע�ͣ��оͱ���ΪCSV�ļ�������ͽ�ִ�����
				if($tmp=~/-{2,}export/)
				{
					if($tmp=~s/-{2,}export (\S+) select/select/i)
					{
						$tname=$1;
						$tname=~s/\s+//g;
					}
					else
					{
						$tmp=~s/-{2,}export//;
					}
					$saveout=1;
				}
				my $sth = $dbh->prepare($tmp) or die "Cannot prepare $tmp: $dbh->errstr/n";
				$sth->execute() or die "Cannot execute the query: $sth->errstr";
				if($saveout)
				{
					#����ִ�е���ΪCSV�Ĳ����������ж�--export����û�б���������оͰ�$tname��Ϊ��׺��������$count����׺
					my $csvpath='';
					if($tname)
					{
						$csvpath="$dmp_dir/$user_name"."_$tname.csv";
					}
					else
					{
						$csvpath="$dmp_dir/$user_name"."_$count.csv";
						$count++;
					}
					open OUT, ">$csvpath" or die "Cannot open the csv file to write!";
					my $fields = join(',', @{ $sth->{NAME_lc} });
					print OUT "$fields\n";
					while (my @row = $sth->fetchrow_array()) {
						@row = map { defined $_? $_ : "NULL" } @row;  #�ѿ��ֶ�ת����NULL
						print OUT join(",", @row), "\n";
					}
					close OUT;
				}
			}
			$dbh->disconnect or warn "DB disconnect failed: $DBI::errstr\n";
		}
		
		# �ж�����--duѡ�����ɾ���û����û�������Ͳ�ɾ��
		if($deluser)
		{
			open DU, ">du.sql" or die "Cannot open the sql file to write!";
			print DU "drop user $user_name cascade;\n";
			print DU "exit;\n";
			close DU;
			system("sqlplus sys/$syspass\@$sid as sysdba \@du.sql")==0 or die "Cannot execute user deletion command.";
		}
	}
}

&ParseCommand();
