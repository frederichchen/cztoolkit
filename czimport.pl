BEGIN { push @INC, './' }
use strict;
use File::Find;
use FileHandle;
use File::Path qw(make_path);
use DBI;
use Getopt::Long;
# CZImporthelper.pm中存放的是czimport会用到的一些函数
use CZImporthelper;

# 设定下面十二个变量的缺省值，它们的值都可以通过命令行参数来修改
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
my $logfile='importlog.txt';
  
my @dmpfiles;                           #此数组存放所有待导入dmp文件名
my @statements;                         #此数组存放从SQL文件中读入的语句


########################################################
#    AddDumpFiles函数，主要供File::Find使用，有--dir         #
#    选项的时候，则递归搜索指定的目录，把找到的dmp文件加             #
#    入@dmpfiles数组                                     #
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
#    ParseCommand函数，用以解析命令行参数               #
#    把--file指定的模式展开放入@dmpfiles数组中          #
#    把--sql指定的文件放入$sqlfilepath变量中            #
#    判断是否有--du标志，如有则导入完成后删除用户和表       #
######################################################
sub ParseCommand
{
	#执行Getopt模块的GetOptions来获取命令行参数
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
		'help!' => \$help,
		'log'   => \$logfile);

	#如果有不识别的参数等问题，则直接退出
	if(!$result) 
	{
		exit(1);
	}
	
	#如果有--help，则显示帮助信息
	if($help)
	{
		&DisplayHelp();
		exit(0);
	}

	#如果有dir选项，则递归搜索其中的dmp文件
	if($dirs)
	{
	    $dirs=~s/\\/\//g;
	    foreach my $dir (split(/,/, $dirs))
		{
			find(\&AddDumpFiles, $dir);
		}
	}

    #如果有--file选项，则把用逗号分割的glob依次进行展开，取得文件，如果文件不存在则报错退出
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

	#如果路径下没有任何文件，则报错退出。
	if(@dmpfiles==0)
	{
		print "Cannot find dmp files to import.\n";
		print "For command line usage help, please execute with --help option.\n";
		exit(1);
	}
	
	# 判断用户指定的sql脚本是否存在，如果没有--sql选项则不执行脚本
	if($sqlfilepath && !(-e $sqlfilepath))
	{
		print "Cannot find the sql script file $sqlfilepath.\n";
		exit(1);
	}

	$logfile=~s/\\/\//g;

	&ImportFile();
}


#############################################################
#    ImportFile函数，功能是将给定的dmp文件逐个导入数据库。       #
#    导入的时候会根据dmp文件的basename，建立同名用户，           #
#    密码与用户名相同。该函数会生成cu.sql文件，并调用SQLPlus     #
#    来执行创建用户和授权功能，最后调用imp导入数据。              #
#############################################################
sub ImportFile
{
	my $filenum=0;                #用于统计处理的文件数
	my $timestamp=localtime;      #用于获取时间
    open LOG, ">$logfile" or die "Cannot open log file to write!";
	print LOG "开始运行czimport程序, 时间是$timestamp.\n";
	print LOG '='x30, "\n";

	#下面判断用户有无指定sql脚本文件，有则读入内容并分解为多个SQL语句
	if($sqlfilepath)
	{
		@statements=&ParseSQL($sqlfilepath);
    }

	#下面遍历每个dmp文件，进行导入操作
	foreach my $dmpfile (@dmpfiles)
	{
		my ($user_name, $dmp_dir)=&GetUserName($dmpfile);
		# 下面建立一个cu.sql的文件，把建立用户和授权的SQL语句写进去，用sqlplus执行
		open CU, ">cu.sql" or die "Cannot open the sql file to write!";
		print CU "create user $user_name identified by $user_name default tablespace $tbs account unlock;\n";
		print CU "grant CONNECT to $user_name WITH ADMIN OPTION;\n";
		print CU "grant RESOURCE to $user_name WITH ADMIN OPTION;\n";
		print CU "grant DBA to $user_name WITH ADMIN OPTION;\n";
		print CU "exit;\n";
		close CU;
		system("sqlplus sys/$syspass\@$sid as sysdba \@cu.sql")==0 or die "Cannot execute user creation command.";
		$timestamp=localtime;
		print LOG "开始导入$dmpfile，时间是$timestamp.\n";

		#判断有无--tables选项，有则导入指定表，否则导入全部表
		if($tables)
		{
			system("imp $user_name/$user_name\@$sid file=\'$dmpfile\' tables=($tables)");
		}
		else
		{
			system("imp $user_name/$user_name\@$sid file=\'$dmpfile\' full=y ignore=y");
		}

		$timestamp=localtime;
		print LOG "结束导入$dmpfile, 时间是$timestamp.\n";
		$filenum++;

		#如果指定了--outdir选项，则把csv文件保存到指定目录
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
		
		#下面判断用户有无指定sql脚本文件，有则连接数据库执行sql脚本
		if($sqlfilepath)
		{
			my $dbh=DBI->connect("dbi:Oracle:host=$hostname;sid=$sid", $user_name, $user_name) or die "Cannot conenct db: $DBI::errstr\n";
			
			# 下面逐条执行从文件中读取的SQL语句，将结果存在“dmp文件名_计数.csv“文件中
			my $count=1;
			my $tname='';          #export后面跟的表名
			my $iname='';          #insert后面跟的表名
			my $saveout=0;         #判断是否保存为CSV
			my $insertdata=0;      #判断是否插入数据库
			my $tmp;
			foreach my $statement (@statements)
			{
				$tmp=$statement;
				my $sth;
				
				#判断语句前有没有"--export"注释，有就保存为CSV文件，否则就仅执行语句
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
					$sth = $dbh->prepare($tmp) or die "Cannot prepare $tmp: $dbh->errstr/n";
					$sth->execute() or die "Cannot execute the query: $sth->errstr";
				}
				
				#判断语句前有没有"--insert"注释，有就插入指定表，否则就仅执行语句
				elsif($tmp=~s/-{2,}insert (\S+) select//i)
				{
					$iname=$1;
					$iname=~s/\s+//g;
					#判断是否是第一个导入文件，如果是就用create table as，并且加入source_user字段，否则用insert into
					if($filenum==1)
					{
						$tmp="create table $iname as select \'$user_name\' source_user, ".$tmp;
						$sth = $dbh->prepare($tmp) or die "Cannot prepare $tmp: $dbh->errstr/n";
						$sth->execute() or die "Cannot execute the query: $sth->errstr";
						my $alt="alter table $iname modify (source_user char(30))";
						my $sth2 = $dbh->prepare($alt) or die "Cannot prepare $alt: $dbh->errstr/n";
						$sth2->execute() or die "Cannot alter the table structure: $sth->errstr";
					}
					else
					{
						$tmp="insert into $iname select \'$user_name\' source_user, ".$tmp;
						$sth = $dbh->prepare($tmp) or die "Cannot prepare $tmp: $dbh->errstr/n";
						$sth->execute() or die "Cannot execute the query: $sth->errstr";
					}
					$saveout=0;
				}
				else
				{
					$saveout=0;
					$sth = $dbh->prepare($tmp) or die "Cannot prepare $tmp: $dbh->errstr/n";
					$sth->execute() or die "Cannot execute the query: $sth->errstr";
				}

				if($saveout)
				{
					#下面执行导出为CSV的操作，首先判断--export后有没有表名，如果有就把$tname作为后缀，否则用$count作后缀
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
						@row = map { defined $_? $_ : "NULL" } @row;  #把空字段转化成NULL
						print OUT join(",", @row), "\n";
					}
					close OUT;
				}
			}
			$dbh->disconnect or warn "DB disconnect failed: $DBI::errstr\n";
		}
		
		# 判断有无--du选项，有则删除用户和用户表，否则就不删除
		if($deluser)
		{
			open DU, ">du.sql" or die "Cannot open the sql file to write!";
			print DU "drop user $user_name cascade;\n";
			print DU "exit;\n";
			close DU;
			system("sqlplus sys/$syspass\@$sid as sysdba \@du.sql")==0 or die "Cannot execute user deletion command.";
		}
		
		$timestamp=localtime;
		print LOG "完成处理$dmpfile，时间是$timestamp.\n";
		print LOG '-'x30, "\n";
		LOG->flush();
	}
	$timestamp=localtime;
	print LOG "完成全部处理，共处理$filenum个文件.\n";
	print LOG '='x30, "\n";
	close LOG;
}

&ParseCommand();
